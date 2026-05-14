import 'dart:async';

import 'package:nyxx/nyxx.dart';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';

import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/command_executor.dart';
import 'package:bot_creator_shared/engine/event_dispatcher.dart';
import 'package:bot_creator_shared/engine/presence_manager.dart';
import 'package:bot_creator_shared/engine/workflow_executor.dart';

/// Represents an active bot session with its gateway connection and managers.
class BotSession {
  BotSession({
    required this.botId,
    required this.token,
    required this.store,
    required this.callbacks,
  }) {
    _workflowExecutor = WorkflowExecutor(
      store: store,
      callbacks: callbacks,
    );

    _commandExecutor = CommandExecutor(
      store: store,
      callbacks: callbacks,
      workflowExecutor: _workflowExecutor,
    );

    _eventDispatcher = EventDispatcher(
      store: store,
      callbacks: callbacks,
      commandExecutor: _commandExecutor,
      workflowExecutor: _workflowExecutor,
    );
  }

  final String botId;
  final String token;

  final BotDataStore store;
  final BotEngineCallbacks callbacks;

  late final WorkflowExecutor _workflowExecutor;
  late final CommandExecutor _commandExecutor;
  late final EventDispatcher _eventDispatcher;

  WorkflowExecutor get workflowExecutor => _workflowExecutor;

  NyxxGateway? _gateway;
  PresenceManager? _presenceManager;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Timer? _metricsTimer;
  Timer? _initialMetricsTimer;

  DateTime? _startedAt;

  String? _ownerId;
  int _commandCount = 0;

  bool _starting = false;
  bool _stopping = false;

  NyxxGateway? get gateway => _gateway;

  String? get ownerId => _ownerId;

  int get commandCount => _commandCount;

  bool get isActive {
    final gateway = _gateway;

    if (gateway == null) {
      return false;
    }

    try {
      return gateway.gateway.isConnected;
    } catch (_) {
      return true;
    }
  }

  /// Starts the bot gateway connection and initializes all managers.
  Future<void> start() async {
    if (_starting || isActive) {
      return;
    }

    _starting = true;

    try {
      final appData = await store.getApp(botId);

      final intentsMap = Map<String, bool>.from(
        appData['intents'] as Map? ?? {},
      );

      final intents = _buildGatewayIntents(intentsMap);

      callbacks.onLog?.call(
        'Starting bot gateway...',
        botId: botId,
      );

      final gateway = await Nyxx.connectGateway(
        token,
        intents,
        options: GatewayClientOptions(
          plugins: [
            logging,
            cliIntegration,
          ],
        ),
      ).timeout(
        const Duration(seconds: 30),
      );

      _gateway = gateway;
      _startedAt = DateTime.now();

      await _loadApplicationMetadata();
      await _refreshCommandCount();

      _presenceManager = PresenceManager(
        botId: botId,
        gateway: gateway,
        onLog: callbacks.onLog,
        onDebugLog: callbacks.onDebugLog,
      );

      await reload();

      final listeners = _eventDispatcher.registerListeners(
        gateway,
        botId: botId,
        startedAt: _startedAt,
      );

      _subscriptions.addAll(listeners);

      _startMetricsReporting();

      callbacks.onLifecycleChange?.call(
        'started',
        botId: botId,
      );

      callbacks.onLog?.call(
        'Bot gateway connected.',
        botId: botId,
      );
    } catch (error, stackTrace) {
      callbacks.onLog?.call(
        'Failed to start bot: $error',
        botId: botId,
      );

      callbacks.onDebugLog?.call(
        'Start error stack:\n$stackTrace',
        botId: botId,
      );

      await _safeCleanupAfterFailedStart();

      rethrow;
    } finally {
      _starting = false;
    }
  }

  /// Reloads the bot configuration without reconnecting.
  Future<void> reload() async {
    final appData = await store.getApp(botId);

    final config = BotConfig.fromJson(appData);

    _presenceManager?.stop();

    _presenceManager?.start(
      statuses: config.statuses,
      presenceStatus: config.presenceStatus,
    );

    await _refreshCommandCount();
  }

  /// Stops the bot session and cleans up resources.
  Future<void> stop() async {
    if (_stopping) {
      return;
    }

    _stopping = true;

    try {
      _metricsTimer?.cancel();
      _metricsTimer = null;

      _initialMetricsTimer?.cancel();
      _initialMetricsTimer = null;

      _presenceManager?.stop();
      _presenceManager = null;

      for (final subscription in _subscriptions) {
        try {
          await subscription.cancel();
        } catch (error, stackTrace) {
          callbacks.onDebugLog?.call(
            'Failed to cancel subscription: $error\n$stackTrace',
            botId: botId,
          );
        }
      }

      _subscriptions.clear();

      final gateway = _gateway;

      if (gateway != null) {
        try {
          await gateway.close();
        } catch (error, stackTrace) {
          callbacks.onDebugLog?.call(
            'Failed to close gateway: $error\n$stackTrace',
            botId: botId,
          );
        }
      }

      _gateway = null;
      _startedAt = null;

      callbacks.onLifecycleChange?.call(
        'stopped',
        botId: botId,
      );
    } finally {
      _stopping = false;
    }
  }

  /// Injects session-specific variables.
  void injectVariables(Map<String, String> variables) {
    variables['bot.ownerId'] = _ownerId ?? 'unknown';

    variables['bot.commands'] = _commandCount.toString();
    variables['bot.commandsCount'] = _commandCount.toString();
    variables['bot.slashCommandsCount'] = _commandCount.toString();

    final startedAt = _startedAt;

    if (startedAt != null) {
      variables['bot.uptime'] = DateTime.now()
          .difference(startedAt)
          .inSeconds
          .toString();
    }
  }

  Future<void> _loadApplicationMetadata() async {
    final gateway = _gateway;

    if (gateway == null) {
      return;
    }

    try {
      final application =
          await gateway.client.applications.fetchCurrentApplication();

      _ownerId = application.owner?.id.toString();
    } catch (error, stackTrace) {
      callbacks.onDebugLog?.call(
        'Failed to fetch application metadata: '
        '$error\n$stackTrace',
        botId: botId,
      );
    }
  }

  Future<void> _refreshCommandCount() async {
    try {
      final commands = await store.listAppCommands(botId);

      _commandCount = commands.length;
    } catch (error, stackTrace) {
      callbacks.onDebugLog?.call(
        'Failed to refresh command count: '
        '$error\n$stackTrace',
        botId: botId,
      );
    }
  }

  Future<void> _safeCleanupAfterFailedStart() async {
    try {
      await stop();
    } catch (error, stackTrace) {
      callbacks.onDebugLog?.call(
        'Cleanup after failed start failed: '
        '$error\n$stackTrace',
        botId: botId,
      );
    }
  }

  void _startMetricsReporting() {
    _metricsTimer?.cancel();
    _initialMetricsTimer?.cancel();

    _metricsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reportMetrics(),
    );

    _initialMetricsTimer = Timer(
      const Duration(seconds: 5),
      _reportMetrics,
    );
  }

  void _reportMetrics() {
    final gateway = _gateway;

    if (gateway == null) {
      return;
    }

    try {
      final guildCount = gateway.guilds.cache.length;

      int shardsCount = 1;
      int latencyMs = 0;

      try {
        final dynamic gatewayManager = gateway.gateway;

        final shards = gatewayManager.shards as List?;

        if (shards != null && shards.isNotEmpty) {
          shardsCount = shards.length;

          final latency =
              (shards.first as dynamic).latency as Duration?;

          latencyMs = latency?.inMilliseconds ?? 0;
        }
      } catch (error, stackTrace) {
        callbacks.onDebugLog?.call(
          'Failed to collect shard metrics: '
          '$error\n$stackTrace',
          botId: botId,
        );
      }

      final metrics = BotRuntimeMetrics(
        guildCount: guildCount,
        shardsCount: shardsCount,
        latencyMs: latencyMs,
        uptimeSeconds: _startedAt != null
            ? DateTime.now()
                .difference(_startedAt!)
                .inSeconds
            : 0,
        memoryUsageBytes: 0,
        cpuUsagePercent: 0.0,
      );

      callbacks.onMetrics?.call(
        metrics,
        botId: botId,
      );
    } catch (error, stackTrace) {
      callbacks.onDebugLog?.call(
        'Failed to report metrics: '
        '$error\n$stackTrace',
        botId: botId,
      );
    }
  }

  Flags<GatewayIntents> _buildGatewayIntents(
    Map<String, bool> intentsMap,
  ) {
    Flags<GatewayIntents> intents = GatewayIntents.none;

    if (intentsMap['Guilds'] == true) {
      intents |= GatewayIntents.guilds;
    }

    if (intentsMap['Guild Messages'] == true) {
      intents |= GatewayIntents.guildMessages;
    }

    if (intentsMap['Message Content'] == true) {
      intents |= GatewayIntents.messageContent;
    }

    if (intentsMap['Guild Members'] == true) {
      intents |= GatewayIntents.guildMembers;
    }

    if (intentsMap['Guild Presence'] == true) {
      intents |= GatewayIntents.guildPresences;
    }

    if (intentsMap['Direct Messages'] == true) {
      intents |= GatewayIntents.directMessages;
    }

    if (intentsMap['Guild Message Reactions'] == true) {
      intents |= GatewayIntents.guildMessageReactions;
    }

    if (intentsMap['Direct Message Reactions'] == true) {
      intents |= GatewayIntents.directMessageReactions;
    }

    if (intentsMap['Guild Message Typing'] == true) {
      intents |= GatewayIntents.guildMessageTyping;
    }

    if (intentsMap['Direct Message Typing'] == true) {
      intents |= GatewayIntents.directMessageTyping;
    }

    if (intentsMap['Guild Scheduled Events'] == true) {
      intents |= GatewayIntents.guildScheduledEvents;
    }

    if (intentsMap['Auto Moderation Configuration'] == true) {
      intents |= GatewayIntents.autoModerationConfiguration;
    }

    if (intentsMap['Auto Moderation Execution'] == true) {
      intents |= GatewayIntents.autoModerationExecution;
    }

    if (intents == GatewayIntents.none) {
      return GatewayIntents.guilds |
          GatewayIntents.guildMessages |
          GatewayIntents.messageContent;
    }

    return intents;
  }
}
