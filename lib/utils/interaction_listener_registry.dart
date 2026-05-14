/// Registry for active interaction listeners (button clicks and modal submits).
/// Listeners are stored in-memory and pruned when expired.
library;

class ListenerEntry {
  final String botId;
  final String workflowName;
  final String workflowEntryPoint;
  final Map<String, String> workflowArguments;
  final DateTime expiresAt;
  final bool oneShot;
  final String type; // 'button' | 'select' | 'modal'
  final String? guildId;
  final String? channelId;
  final String? messageId;
  final String? userId; // if userId is set, only respond to that user

  const ListenerEntry({
    required this.botId,
    required this.workflowName,
    this.workflowEntryPoint = 'main',
    this.workflowArguments = const <String, String>{},
    required this.expiresAt,
    required this.type,
    this.oneShot = true,
    this.guildId,
    this.channelId,
    this.messageId,
    this.userId,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class ListenerMatchRequest {
  const ListenerMatchRequest({
    required this.botId,
    required this.type,
    this.guildId,
    this.channelId,
    this.messageId,
    this.userId,
  });

  final String botId;
  final String type;
  final String? guildId;
  final String? channelId;
  final String? messageId;
  final String? userId;
}

class InteractionListenerRegistry {
  InteractionListenerRegistry._();
  static final instance = InteractionListenerRegistry._();

  final Map<String, List<ListenerEntry>> _listeners = {};

  /// Register a listener for a specific [customId].
  void register(String customId, ListenerEntry entry) {
    final listeners = _listeners.putIfAbsent(customId, () => <ListenerEntry>[]);
    listeners.add(entry);
  }

  /// Retrieve the most recent non-expired listener matching [request], or null.
  ListenerEntry? getMatching(String customId, ListenerMatchRequest request) {
    final listeners = _listeners[customId];
    if (listeners == null || listeners.isEmpty) {
      return null;
    }

    listeners.removeWhere((entry) => entry.isExpired);
    if (listeners.isEmpty) {
      _listeners.remove(customId);
      return null;
    }

    for (var index = listeners.length - 1; index >= 0; index--) {
      final entry = listeners[index];
      if (!_matches(entry, request)) {
        continue;
      }
      return entry;
    }

    return null;
  }

  /// Remove a single listener instance for [customId].
  void removeEntry(String customId, ListenerEntry entry) {
    final listeners = _listeners[customId];
    if (listeners == null) {
      return;
    }

    listeners.remove(entry);
    if (listeners.isEmpty) {
      _listeners.remove(customId);
    }
  }

  /// Prune all expired listeners. Call periodically if needed.
  void pruneExpired() {
    final emptyKeys = <String>[];
    for (final entry in _listeners.entries) {
      entry.value.removeWhere((listener) => listener.isExpired);
      if (entry.value.isEmpty) {
        emptyKeys.add(entry.key);
      }
    }
    for (final key in emptyKeys) {
      _listeners.remove(key);
    }
  }

  /// All currently registered (and non-expired) customIds.
  List<String> get activeCustomIds {
    pruneExpired();
    return _listeners.keys.toList();
  }

  bool _matches(ListenerEntry entry, ListenerMatchRequest request) {
    if (entry.botId != request.botId || entry.type != request.type) {
      return false;
    }
    if (entry.guildId != null && entry.guildId != request.guildId) {
      return false;
    }
    if (entry.channelId != null && entry.channelId != request.channelId) {
      return false;
    }
    if (entry.messageId != null && entry.messageId != request.messageId) {
      return false;
    }
    if (entry.userId != null && entry.userId != request.userId) {
      return false;
    }
    return true;
  }
}
