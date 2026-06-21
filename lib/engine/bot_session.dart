// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/presence_manager.dart';
import 'package:bot_creator_shared/engine/event_dispatcher.dart';
import 'package:bot_creator_shared/engine/command_executor.dart';
import 'package:bot_creator_shared/engine/workflow_executor.dart';
import 'package:bot_creator_shared/services/lavalink_service.dart';
import 'package:bot_creator_shared/utils/interaction_listener_registry.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/utils/global.dart';

/// Represents an active bot session with its gateway connection and managers.
class BotSession {
  BotSession({
    required this.botId,
    required String token,
    required this.store,
    required this.callbacks,
    LavalinkConfig? lavalinkConfig,
  })  : _token = token,
        _lavalinkConfig = lavalinkConfig {
    _workflowExecutor = WorkflowExecutor(store: store, callbacks: callbacks);
    _commandExecutor = CommandExecutor(
      store: store,
      callbacks: callbacks,
      workflowExecutor: _workflowExecutor,
      sessionVariableInjector: injectVariables,
    );
    _eventDispatcher = EventDispatcher(
      store: store,
      callbacks: callbacks,
      commandExecutor: _commandExecutor,
      workflowExecutor: _workflowExecutor,
      sessionVariableInjector: injectVariables,
    );
  }

  final String botId;
  final BotDataStore store;
  final BotEngineCallbacks callbacks;

  String _token;
  LavalinkConfig? _lavalinkConfig;
  Map<String, bool> _intentsMap = const {};

  String get token => _token;
  LavalinkConfig? get lavalinkConfig => _lavalinkConfig;

  late final WorkflowExecutor _workflowExecutor;
  late final CommandExecutor _commandExecutor;
  late final EventDispatcher _eventDispatcher;

  WorkflowExecutor get workflowExecutor => _workflowExecutor;
  NyxxGateway? get gateway => _gateway;
  LavalinkService? get lavalinkService => _lavalinkService;
  String get ownerId => _ownerId;
  int get commandCount => _commandCount;

  NyxxGateway? _gateway;
  LavalinkService? _lavalinkService;
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
    final rawIntents = Map<String, bool>.from(appData['intents'] as Map? ?? {});
    _intentsMap = rawIntents;
    final intentsMap = Map<String, bool>.from(rawIntents);

    // Lavalink requires voice state intents — force-enable them
    if (lavalinkConfig != null) {
      intentsMap['Voice States'] = true;
    }

    final intents = _buildGatewayIntents(intentsMap);

    callbacks.onLog?.call('Starting bot gateway...', botId: botId);

    // Build plugins list — Lavalink is connected AFTER gateway to avoid blocking
    final localConfig = lavalinkConfig;
    final plugins = <NyxxPlugin>[logging, cliIntegration];

    try {
      _gateway = await Nyxx.connectGateway(
        token,
        intents,
        options: GatewayClientOptions(plugins: plugins),
      );

      // ── Lavalink: connect AFTER gateway to prevent gateway blocking ──
      if (localConfig != null) {
        callbacks.onLog
            ?.call('Lavalink: pre-checking ${localConfig.host}:${localConfig.port}...', botId: botId);

        // Quick REST health check before attempting WebSocket
        final preCheckError = await LavalinkService.testConnection(
          host: localConfig.host,
          port: localConfig.port,
          password: localConfig.password,
          useSsl: localConfig.useSsl,
        );

        if (preCheckError != null) {
          callbacks.onLog?.call(
            'Lavalink pre-check failed: $preCheckError — music disabled',
            botId: botId,
          );
        } else {
          callbacks.onLog?.call('Lavalink pre-check OK, starting plugin...', botId: botId);
          final lavalinkPlugin = LavalinkService.createPlugin(localConfig);
          if (lavalinkPlugin != null) {
            _lavalinkService = LavalinkService(
              plugin: lavalinkPlugin,
              config: localConfig,
              onLog: (msg) => callbacks.onLog?.call(msg, botId: botId),
            );

            // Fire and forget: Lavalink connects in background, timeout 10s
            unawaited(_lavalinkService!.waitForReady().then((_) {
              callbacks.onLog?.call('Lavalink ready — music features enabled', botId: botId);
              _workflowExecutor.lavalinkService = _lavalinkService;
              _lavalinkService!.monitorHealth();
            }).catchError((e) {
              callbacks.onLog?.call('Lavalink connection failed: $e — music disabled', botId: botId);
              _lavalinkService = null;
            }));
          }
        }
      }

      // Debug voice events
      _gateway!.onVoiceStateUpdate.listen((event) {
        callbacks.onLog?.call(
          'DEBUG VOICE STATE: userId=${event.state.userId}, botId=${_gateway!.user.id}, guildId=${event.state.guildId}, channelId=${event.state.channelId}, sessionId=${event.state.sessionId}',
          botId: botId,
        );
      });
      _gateway!.onVoiceServerUpdate.listen((event) {
        final tokenSnippet = event.token.length > 5 ? event.token.substring(0, 5) : event.token;
        callbacks.onLog?.call(
          'DEBUG VOICE SERVER: guildId=${event.guildId}, endpoint=${event.endpoint}, token=$tokenSnippet...',
          botId: botId,
        );
      });

      _startedAt = DateTime.now();
      botStartTimes[botId] = _startedAt!;

      // Cache metadata
      try {
        final app =
            await (_gateway! as NyxxRest).applications
                .fetchCurrentApplication();
        _ownerId = (app.team?.ownerId.toString() ?? app.owner?.id.toString())!;
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
        resolveTemplate: (input) {
          final vars = <String, String>{};
          injectAlwaysAvailableVariables(
            vars,
            botId: botId,
            guildCount: _gateway!.guilds.cache.length,
            uptimeMs: DateTime.now().difference(_startedAt ?? DateTime.now()).inMilliseconds,
          );
          return resolveTemplatePlaceholders(input, vars);
        },
      );

      await reload();

      callbacks.onDebugLog?.call(
        'Registering event listeners...',
        botId: botId,
      );
      _subscriptions.addAll(
        _eventDispatcher.registerListeners(
          _gateway!,
          botId: botId,
          startedAt: _startedAt,
        ),
      );
      callbacks.onDebugLog?.call(
        '${_subscriptions.length} listeners registered.',
        botId: botId,
      );

      _startMetricsReporting();

      callbacks.onLifecycleChange?.call('started', botId: botId);
      callbacks.onLog?.call('Bot gateway connected.', botId: botId);
    } catch (error, stackTrace) {
      callbacks.onLog?.call('Failed to start bot: $error', botId: botId);
      callbacks.onDebugLog?.call(
        'Start error stack: $stackTrace',
        botId: botId,
      );
      rethrow;
    }
  }

  /// Reloads the bot configuration (presence, commands, etc.) without reconnecting,
  /// unless token, intents, or lavalink presence changed.
  Future<void> reload() async {
    final appData = await store.getApp(botId);
    final config = BotConfig.fromJson(appData);

    final newToken = config.token;
    final newIntents = config.intents;
    final newLavalinkConfig = config.lavalinkConfig;

    final previousHasLavalink = _lavalinkConfig != null;
    final newHasLavalink = newLavalinkConfig != null;

    final bool intentsChanged = !_sameIntents(_intentsMap, newIntents) ||
        (previousHasLavalink != newHasLavalink);

    if (_token != newToken || intentsChanged) {
      callbacks.onLog?.call(
        'Lavalink/Intents/Token changed, reconnecting gateway...',
        botId: botId,
      );
      _token = newToken;
      _lavalinkConfig = newLavalinkConfig;
      _intentsMap = newIntents;

      await stop();
      await start();
      return;
    }

    // If no gateway reconnect is needed, check if the Lavalink config details changed
    if (newHasLavalink && previousHasLavalink) {
      if (_isLavalinkConfigDifferent(_lavalinkConfig, newLavalinkConfig)) {
        callbacks.onLog?.call(
          'Lavalink config details changed, updating service...',
          botId: botId,
        );
        _lavalinkConfig = newLavalinkConfig;
        await _reloadLavalinkService(newLavalinkConfig);
      }
    } else if (!newHasLavalink && previousHasLavalink) {
      _lavalinkConfig = null;
      await _disposeLavalink();
    }

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
    botStartTimes.remove(botId);
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

    await _disposeLavalink();

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
      variables['bot.uptime'] =
          DateTime.now().difference(_startedAt!).inMilliseconds.toString();
    }
  }

  void _startMetricsReporting() {
    _metricsTimer?.cancel();
    _metricsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _reportMetrics();
    });
    // Initial report
    _initialMetricsTimer?.cancel();
    _initialMetricsTimer = Timer(
      const Duration(seconds: 5),
      () => _reportMetrics(),
    );
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
        latencyMs:
            (shards != null && shards.isNotEmpty)
                ? ((shards.first as dynamic).latency as Duration?)
                        ?.inMilliseconds ??
                    0
                : 0,
        uptimeSeconds:
            _startedAt != null
                ? DateTime.now().difference(_startedAt!).inSeconds
                : 0,
        memoryUsageBytes: 0,
        cpuUsagePercent: 0.0,
      );
    } catch (_) {
      metrics = BotRuntimeMetrics(
        guildCount: gateway.guilds.cache.length,
        shardsCount: 1,
        latencyMs: 0,
        uptimeSeconds:
            _startedAt != null
                ? DateTime.now().difference(_startedAt!).inSeconds
                : 0,
        memoryUsageBytes: 0,
        cpuUsagePercent: 0.0,
      );
    }

    callbacks.onMetrics?.call(metrics, botId: botId);
  }

  Flags<GatewayIntents> _buildGatewayIntents(Map<String, bool> intentsMap) {
    Flags<GatewayIntents> intents = GatewayIntents.none;
    if (intentsMap['Guild Presence'] == true) {
      intents |= GatewayIntents.guildPresences;
    }
    if (intentsMap['Guild Members'] == true) {
      intents |= GatewayIntents.guildMembers;
    }
    if (intentsMap['Voice States'] == true) {
      intents |= GatewayIntents.guildVoiceStates;
    }
    if (intentsMap['Message Content'] == true) {
      intents |= GatewayIntents.messageContent;
    }
    if (intentsMap['Direct Messages'] == true) {
      intents |= GatewayIntents.directMessages;
    }
    if (intentsMap['Guilds'] == true) {
      intents |= GatewayIntents.guilds;
    }
    if (intentsMap['Guild Messages'] == true) {
      intents |= GatewayIntents.guildMessages;
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

    return intents == GatewayIntents.none
        ? GatewayIntents.allUnprivileged
        : intents;
  }

  bool _sameIntents(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if ((b[entry.key] ?? false) != entry.value) return false;
    }
    return true;
  }

  bool _isLavalinkConfigDifferent(LavalinkConfig? a, LavalinkConfig? b) {
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    return a.host != b.host ||
        a.port != b.port ||
        a.password != b.password ||
        a.useSsl != b.useSsl;
  }

  Future<void> _reloadLavalinkService(LavalinkConfig config) async {
    await _disposeLavalink();

    callbacks.onLog?.call('Lavalink: pre-checking ${config.host}:${config.port}...', botId: botId);
    final preCheckError = await LavalinkService.testConnection(
      host: config.host,
      port: config.port,
      password: config.password,
      useSsl: config.useSsl,
    );

    if (preCheckError != null) {
      callbacks.onLog?.call(
        'Lavalink pre-check failed: $preCheckError — music disabled',
        botId: botId,
      );
    } else {
      callbacks.onLog?.call('Lavalink pre-check OK, starting plugin...', botId: botId);
      final lavalinkPlugin = LavalinkService.createPlugin(config);
      if (lavalinkPlugin != null) {
        _lavalinkService = LavalinkService(
          plugin: lavalinkPlugin,
          config: config,
          onLog: (msg) => callbacks.onLog?.call(msg, botId: botId),
        );

        try {
          await _lavalinkService!.waitForReady();
          callbacks.onLog?.call('Lavalink ready — music features enabled', botId: botId);
          _workflowExecutor.lavalinkService = _lavalinkService;
          _lavalinkService!.monitorHealth();
        } catch (e) {
          callbacks.onLog?.call('Lavalink connection failed: $e — music disabled', botId: botId);
          _lavalinkService = null;
        }
      }
    }
  }

  Future<void> _disposeLavalink() async {
    if (_lavalinkService != null) {
      callbacks.onLog?.call('Lavalink: disposing existing service...', botId: botId);
      try {
        await _lavalinkService!.dispose();
      } catch (e) {
        callbacks.onLog?.call('Lavalink: error disposing service: $e', botId: botId);
      }
      _lavalinkService = null;
      _workflowExecutor.lavalinkService = null;
    }
  }
}
