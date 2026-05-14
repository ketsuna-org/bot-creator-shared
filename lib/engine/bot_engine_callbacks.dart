/// Callbacks emitted by the [BotEngine] during bot lifecycle and execution.
class BotEngineCallbacks {
  const BotEngineCallbacks({
    this.onLog,
    this.onDebugLog,
    this.onLifecycleChange,
    this.onMetrics,
  });

  /// Emitted for general bot logs.
  final void Function(String message, {required String botId})? onLog;

  /// Emitted for verbose debug logs.
  final void Function(String message, {String? botId})? onDebugLog;

  /// Emitted when a bot lifecycle state changes (e.g., 'started', 'stopped').
  final void Function(String event, {required String botId})? onLifecycleChange;

  /// Emitted when bot runtime metrics are updated.
  final void Function(BotRuntimeMetrics metrics, {required String botId})?
  onMetrics;
}

/// Snapshot of bot runtime metrics.
class BotRuntimeMetrics {
  const BotRuntimeMetrics({
    required this.guildCount,
    required this.shardsCount,
    required this.latencyMs,
    required this.uptimeSeconds,
    required this.memoryUsageBytes,
    required this.cpuUsagePercent,
  });

  final int guildCount;
  final int shardsCount;
  final int latencyMs;
  final int uptimeSeconds;
  final int memoryUsageBytes;
  final double cpuUsagePercent;

  Map<String, dynamic> toJson() => {
    'guildCount': guildCount,
    'shardsCount': shardsCount,
    'latencyMs': latencyMs,
    'uptimeSeconds': uptimeSeconds,
    'memoryUsageBytes': memoryUsageBytes,
    'cpuUsagePercent': cpuUsagePercent,
  };
}
