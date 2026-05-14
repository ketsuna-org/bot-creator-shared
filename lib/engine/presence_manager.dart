import 'dart:async';
import 'dart:math';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_config.dart';

/// Manages Discord presence and status rotation for a bot session.
class PresenceManager {
  PresenceManager({
    required this.botId,
    required this.gateway,
    this.onLog,
    this.onDebugLog,
  });

  final String botId;
  final NyxxGateway gateway;
  final void Function(String message, {required String botId})? onLog;
  final void Function(String message, {String? botId})? onDebugLog;

  Timer? _rotationTimer;
  final Random _random = Random();

  /// Starts the presence rotation based on the provided configuration.
  void start({
    required List<BotStatusConfig> statuses,
    required String presenceStatus,
  }) {
    stop();

    if (statuses.isEmpty) {
      _applyPresenceOnly(presenceStatus);
      return;
    }

    unawaited(_applyInitialStatusThenRotate(statuses, presenceStatus));
  }

  /// Stops any active presence rotation.
  void stop() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  void _applyPresenceOnly(String presenceStatus) {
    try {
      gateway.updatePresence(
        PresenceBuilder(
          status: _mapPresenceStatus(presenceStatus),
          isAfk: false,
          activities: [],
        ),
      );
    } catch (error) {
      onDebugLog?.call(
        'Presence update failed (no activities): $error',
        botId: botId,
      );
    }
  }

  Future<void> _applyInitialStatusThenRotate(
    List<BotStatusConfig> statuses,
    String presenceStatus,
  ) async {
    if (statuses.isEmpty) return;

    final firstStatus = statuses.first;
    await _applyStatus(firstStatus, presenceStatus);

    // Re-send once after READY to avoid occasional dropped first presence frame.
    Timer(const Duration(seconds: 3), () {
      unawaited(_applyStatus(firstStatus, presenceStatus));
    });

    if (statuses.length > 1) {
      _scheduleNextRotation(statuses, firstStatus, presenceStatus);
    }
  }

  void _scheduleNextRotation(
    List<BotStatusConfig> statuses,
    BotStatusConfig currentStatus,
    String presenceStatus,
  ) {
    final min = currentStatus.minIntervalSeconds;
    final max = currentStatus.maxIntervalSeconds;
    final delaySeconds =
        max <= min ? min : min + _random.nextInt(max - min + 1);

    _rotationTimer?.cancel();
    _rotationTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(_applyRandomStatus(statuses, presenceStatus));
    });
  }

  Future<void> _applyRandomStatus(
    List<BotStatusConfig> statuses,
    String presenceStatus,
  ) async {
    if (statuses.isEmpty) return;

    final picked = statuses[_random.nextInt(statuses.length)];
    await _applyStatus(picked, presenceStatus);

    _scheduleNextRotation(statuses, picked, presenceStatus);
  }

  Future<void> _applyStatus(
    BotStatusConfig status,
    String presenceStatus,
  ) async {
    final text = _sanitizeActivityText(status.name);
    if (text.isEmpty) return;

    final streamUrl = _parseStreamingUrl(status.url ?? '');

    try {
      gateway.updatePresence(
        PresenceBuilder(
          status: _mapPresenceStatus(presenceStatus),
          isAfk: false,
          activities: <ActivityBuilder>[
            ActivityBuilder(
              name: text,
              type: _mapActivityType(status.type, streamUrl: streamUrl),
              url: streamUrl,
              state: status.state.isNotEmpty ? status.state : null,
            ),
          ],
        ),
      );
      onLog?.call(
        'Presence applied: ${status.type} $text',
        botId: botId,
      );
    } catch (error) {
      onDebugLog?.call(
        'Presence update failed: $error',
        botId: botId,
      );
    }
  }

  CurrentUserStatus _mapPresenceStatus(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'idle':
        return CurrentUserStatus.idle;
      case 'dnd':
        return CurrentUserStatus.dnd;
      case 'invisible':
        return CurrentUserStatus.invisible;
      default:
        return CurrentUserStatus.online;
    }
  }

  ActivityType _mapActivityType(String rawType, {required Uri? streamUrl}) {
    switch (rawType.toLowerCase()) {
      case 'streaming':
        return streamUrl != null ? ActivityType.streaming : ActivityType.game;
      case 'listening':
        return ActivityType.listening;
      case 'watching':
        return ActivityType.watching;
      case 'competing':
        return ActivityType.competing;
      case 'playing':
      default:
        return ActivityType.game;
    }
  }

  Uri? _parseStreamingUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return null;
    if ((parsed.scheme != 'http' && parsed.scheme != 'https') ||
        parsed.host.isEmpty) {
      return null;
    }
    return parsed;
  }

  String _sanitizeActivityText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.length > 128 ? trimmed.substring(0, 128) : trimmed;
  }
}
