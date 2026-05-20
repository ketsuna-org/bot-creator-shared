import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/presence_manager.dart';
import 'package:bot_creator_shared/engine/event_dispatcher.dart';
import 'package:bot_creator_shared/engine/command_executor.dart';
import 'package:bot_creator_shared/engine/workflow_executor.dart';
import 'package:bot_creator_shared/utils/interaction_listener_registry.dart';

/// Represents an active bot session with its gateway connection and managers.
class BotSession {
  BotSession({
    required this.botId,
    required this.token,
    required this.store,
    required this.callbacks,
  }) {
    _workflowExecutor = WorkflowExecutor(store: store, callbacks: callbacks);
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
  NyxxGateway? get gateway => _gateway;
  String get ownerId => _ownerId;
  int get commandCount => _commandCount;

  NyxxGateway? _gateway;
  PresenceManager? _presenceManager;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  DateTime? _startedAt;
  Timer? _metricsTimer;
  Timer? _initialMetricsTimer;

  String _ownerId = '';
  int _commandCount = 0;

  bool get isActive => _gateway != null;

  /// Starts the bot gateway connection and initializes all managers.
  Future<void> start() async {
    if (isActive) return;

    final appData = await store.getApp(botId);
    final intentsMap = Map<String, bool>.from(appData['intents'] as Map? ?? {});
    final intents = _buildGatewayIntents(intentsMap);

    callbacks.onLog?.call('Starting bot gateway...', botId: botId);

    try {
      _gateway = await Nyxx.connectGateway(
        token,
        intents,
        options: GatewayClientOptions(
          plugins: [logging, cliIntegration],
        ),
      );

      _startedAt = DateTime.now();
      
      // Cache metadata
      try {
        final app = await ((_gateway! as dynamic).client as dynamic).applications.fetchCurrentApplication();
        _ownerId = app.owner?.id.toString() ?? '';
      } catch (_) {}

      try {
        final commands = await store.listAppCommands(botId);
        _commandCount = commands.length;
      } catch (_) {}

      _presenceManager = PresenceManager(
        botId: botId,
        gateway: _gateway!,
        onLog: callbacks.onLog,
        onDebugLog: callbacks.onDebugLog,
      );

      await reload();

      callbacks.onDebugLog?.call('Registering event listeners...', botId: botId);
      _subscriptions.addAll(
        _eventDispatcher.registerListeners(
          _gateway!,
          botId: botId,
          startedAt: _startedAt,
        ),
      );
      callbacks.onDebugLog?.call('${_subscriptions.length} listeners registered.', botId: botId);

      _startMetricsReporting();

      callbacks.onLifecycleChange?.call('started', botId: botId);
      callbacks.onLog?.call('Bot gateway connected.', botId: botId);
    } catch (error, stackTrace) {
      callbacks.onLog?.call('Failed to start bot: $error', botId: botId);
      callbacks.onDebugLog?.call('Start error stack: $stackTrace', botId: botId);
      rethrow;
    }
  }

  /// Reloads the bot configuration (presence, commands, etc.) without reconnecting.
  Future<void> reload() async {
    final appData = await store.getApp(botId);
    final config = BotConfig.fromJson(appData);

    _presenceManager?.start(
      statuses: config.statuses,
      presenceStatus: config.presenceStatus,
    );

    // Refresh command count
    try {
      final commands = await store.listAppCommands(botId);
      _commandCount = commands.length;
    } catch (_) {}
  }

  /// Stops the bot session and cleans up resources.
  Future<void> stop() async {
    _metricsTimer?.cancel();
    _metricsTimer = null;
    _initialMetricsTimer?.cancel();
    _initialMetricsTimer = null;

    _presenceManager?.stop();
    _presenceManager = null;

    // Clear any registered interaction listeners for this bot
    InteractionListenerRegistry.instance.removeAllForBot(botId);

    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();

    if (_gateway != null) {
      await _gateway!.close();
      _gateway = null;
    }

    callbacks.onLifecycleChange?.call('stopped', botId: botId);
  }

  /// Injects session-specific variables.
  void injectVariables(Map<String, String> variables) {
    variables['bot.ownerId'] = _ownerId;
    variables['bot.commands'] = _commandCount.toString();
    variables['bot.commandsCount'] = _commandCount.toString();
    variables['bot.slashCommandsCount'] = _commandCount.toString();
    if (_startedAt != null) {
      variables['bot.uptime'] = DateTime.now().difference(_startedAt!).inMilliseconds.toString();
    }
  }

  void _startMetricsReporting() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _reportMetrics();
    });
    // Initial report
    _initialMetricsTimer?.cancel();
    _initialMetricsTimer = Timer(const Duration(seconds: 5), () => _reportMetrics());
  }

  void _reportMetrics() {
    final gateway = _gateway;
    if (gateway == null) return;

    BotRuntimeMetrics metrics = const BotRuntimeMetrics(
      guildCount: 0,
      shardsCount: 0,
      latencyMs: 0,
      uptimeSeconds: 0,
      memoryUsageBytes: 0,
      cpuUsagePercent: 0.0,
    );
    try {
      final gatewayManager = gateway.gateway;
      // In Nyxx 6.x, Gateway is the interface for the gateway manager.
      // We can access shards if we cast to the implementation or if the interface exposes it.
      // To be safe and avoid dynamic, we try to use the common shards property if it exists on the interface.
      final shards = (gatewayManager as dynamic).shards as List?;
      metrics = BotRuntimeMetrics(
        guildCount: gateway.guilds.cache.length,
        shardsCount: shards?.length ?? 1,
        latencyMs: (shards != null && shards.isNotEmpty)
            ? ((shards.first as dynamic).latency as Duration?)?.inMilliseconds ?? 0
            : 0,
        uptimeSeconds: _startedAt != null ? DateTime.now().difference(_startedAt!).inSeconds : 0,
        memoryUsageBytes: 0,
        cpuUsagePercent: 0.0,
      );
    } catch (_) {
      metrics = BotRuntimeMetrics(
        guildCount: gateway.guilds.cache.length,
        shardsCount: 1,
        latencyMs: 0,
        uptimeSeconds: _startedAt != null ? DateTime.now().difference(_startedAt!).inSeconds : 0,
        memoryUsageBytes: 0,
        cpuUsagePercent: 0.0,
      );
    }

    callbacks.onMetrics?.call(metrics, botId: botId);
  }

  Flags<GatewayIntents> _buildGatewayIntents(Map<String, bool> intentsMap) {
    Flags<GatewayIntents> intents = GatewayIntents.none;
    if (intentsMap['Guild Presence'] == true) intents |= GatewayIntents.guildPresences;
    if (intentsMap['Guild Members'] == true) intents |= GatewayIntents.guildMembers;
    if (intentsMap['Message Content'] == true) intents |= GatewayIntents.messageContent;
    if (intentsMap['Direct Messages'] == true) intents |= GatewayIntents.directMessages;
    if (intentsMap['Guilds'] == true) intents |= GatewayIntents.guilds;
    if (intentsMap['Guild Messages'] == true) intents |= GatewayIntents.guildMessages;
    if (intentsMap['Guild Message Reactions'] == true) intents |= GatewayIntents.guildMessageReactions;
    if (intentsMap['Direct Message Reactions'] == true) intents |= GatewayIntents.directMessageReactions;
    if (intentsMap['Guild Message Typing'] == true) intents |= GatewayIntents.guildMessageTyping;
    if (intentsMap['Direct Message Typing'] == true) intents |= GatewayIntents.directMessageTyping;
    if (intentsMap['Guild Scheduled Events'] == true) intents |= GatewayIntents.guildScheduledEvents;
    if (intentsMap['Auto Moderation Configuration'] == true) intents |= GatewayIntents.autoModerationConfiguration;
    if (intentsMap['Auto Moderation Execution'] == true) intents |= GatewayIntents.autoModerationExecution;

    return intents == GatewayIntents.none ? GatewayIntents.allUnprivileged : intents;
  }
}
