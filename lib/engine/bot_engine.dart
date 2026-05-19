import 'dart:async';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/bot_session.dart';

/// The central entry point for the Bot Creator bot execution engine.
/// Manages multiple bot sessions across Desktop, Mobile, or Runner environments.
class BotEngine {
  BotEngine({
    required this.store,
    required this.callbacks,
  });

  final BotDataStore store;
  final BotEngineCallbacks callbacks;

  final Map<String, BotSession> _sessions = {};

  /// Returns true if at least one bot session is currently active.
  bool get isRunning => _sessions.values.any((s) => s.isActive);

  /// Returns a snapshot of all currently active bot IDs.
  Set<String> get runningBotIds => _sessions.keys.toSet();

  /// Starts a bot session for the given [token].
  /// If the bot is already running, it does nothing.
  Future<void> start(String token) async {
    // We assume the bot ID can be derived later from the gateway.
  }

  /// Starts a bot session for a specific [botId] with the provided [token].
  Future<void> startWithId(String botId, String token) async {
    if (_sessions.containsKey(botId) && _sessions[botId]!.isActive) {
      callbacks.onLog?.call('Bot $botId is already running.', botId: botId);
      return;
    }

    final session = BotSession(
      botId: botId,
      token: token,
      store: store,
      callbacks: callbacks,
    );

    _sessions[botId] = session;
    await session.start();
  }

  /// Stops a specific bot session.
  Future<void> stop(String botId) async {
    final session = _sessions.remove(botId);
    if (session != null) {
      await session.stop();
    }
  }

  /// Reloads the configuration for a specific bot session.
  Future<void> reload(String botId) async {
    final session = _sessions[botId];
    if (session != null) {
      await session.reload();
    }
  }

  /// Returns the active session for a given bot ID, if any.
  BotSession? getSession(String botId) => _sessions[botId];

  /// Stops all active bot sessions.
  Future<void> stopAll() async {
    final ids = _sessions.keys.toList();
    for (final id in ids) {
      await stop(id);
    }
  }

  /// Injects session-specific variables for the given [botId] into [variables].
  void injectVariables(String botId, Map<String, String> variables) {
    _sessions[botId]?.injectVariables(variables);
  }

  // --- Debug Replay Support ---
  final Map<String, bool> _debugReplayEnabled = {};
  final Map<String, List<Map<String, dynamic>>> _debugReplays = {};

  bool isDebugReplayCapturing(String botId) => _debugReplayEnabled[botId] ?? false;

  void setDebugReplayCapturing(String botId, bool enabled) {
    _debugReplayEnabled[botId] = enabled;
  }

  void saveDebugReplay(
    String botId,
    String label,
    List<Map<String, dynamic>> frames,
    int totalMs,
  ) {
    final list = _debugReplays.putIfAbsent(botId, () => []);
    list.add({
      'botId': botId,
      'commandLabel': label,
      'triggeredAt': DateTime.now().toUtc().toIso8601String(),
      'actionCount': frames.length,
      'totalMs': totalMs,
      'frames': frames,
    });
    if (list.length > 30) {
      list.removeRange(0, list.length - 30);
    }
  }

  List<Map<String, dynamic>> listDebugReplays(String botId, {int limit = 30}) {
    final replays = _debugReplays[botId] ?? [];
    if (replays.length > limit) {
      return replays.sublist(replays.length - limit);
    }
    return replays;
  }

  void clearDebugReplays(String botId) {
    _debugReplays.remove(botId);
  }
}
