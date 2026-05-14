/// Abstract interface for variable storage (scoped + global).
/// Implementations: JsonVariableStore, SqliteVariableStore, SqliteCliVariableStore
abstract class VariableDatabase {
  // ===== GLOBAL VARIABLES =====
  /// Returns all global variables for [botId] with typed values (string|number).
  Future<Map<String, dynamic>> getGlobalVariables(String botId);

  /// Returns a single global variable value, or null if not set.
  Future<dynamic> getGlobalVariable(String botId, String key);

  /// Persists or updates a global variable.
  Future<void> setGlobalVariable(
    String botId,
    String key,
    dynamic value, {
    String? ttl,
  });

  /// Renames a global variable key.
  Future<void> renameGlobalVariable(String botId, String oldKey, String newKey);

  /// Removes a global variable.
  Future<void> removeGlobalVariable(String botId, String key);

  // ===== SCOPED VARIABLES =====
  /// Returns all scoped variables for [botId]+[scope]+[contextId].
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  );

  /// Returns a single scoped variable, or null if not set.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Persists or updates a scoped variable.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value, {
    String? ttl,
  });

  /// Renames a scoped variable key.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  );

  /// Removes a scoped variable.
  /// For guildMember scope, [contextId] is "{guildId}:{userId}" format.
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Lists all context IDs for a given [scope] (e.g. all guild IDs that have guild-scoped vars).
  /// Optionally filter by a [searchKey] prefix (e.g. "bc_" to find only bc_* variables).
  Future<List<String>> listContextIds(
    String botId,
    String scope, {
    String? searchKey,
  });

  /// Lists all entries for a scoped [key] across every context in [scope].
  ///
  /// Returns a JSON-friendly payload:
  /// {
  ///   'items': [
  ///     {'contextId': '...', 'key': '...', 'value': `dynamic`},
  ///   ],
  ///   'count': `int`,
  ///   'total': `int`,
  /// }
  ///
  /// [offset] is clamped to >= 0 and [limit] is clamped to 1..25.
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  });

  /// Delete all variables for a bot.
  Future<void> deleteAllForBot(String botId);

  // ===== ARRAY OPERATIONS on SCOPED VARIABLES =====
  /// Push an element to the end of a scoped array variable.
  /// If the variable doesn't exist or isn't an array, creates a new array with [element].
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  );

  /// Pop (remove and return) the last element from a scoped array variable.
  /// Returns null if the variable doesn't exist, isn't an array, or is empty.
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Remove an element at [index] from a scoped array variable.
  /// Returns the removed element, or null if index is out of bounds or not an array.
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  );

  /// Get an element at [index] from a scoped array variable.
  /// Returns null if the variable doesn't exist, isn't an array, or index is out of bounds.
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  );

  /// Get the length of a scoped array variable.
  /// Returns 0 if the variable doesn't exist or isn't an array.
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Lists elements of a scoped array variable with pagination, sorting, and optional filtering.
  ///
  /// Returns a JSON-friendly payload:
  /// {
  ///   'items': [`element1`, `element2`, ...],
  ///   'count': `int`,
  ///   'total': `int`,
  /// }
  ///
  /// [offset] is clamped to >= 0 and [limit] is clamped to 1..25.
  /// [descending] controls sort order (true = desc, false = asc).
  /// [filter] is an optional comparison string (e.g., '> 100', '< 50', '== 42', 'contains abc').
  Future<Map<String, dynamic>> queryScopedArray(
    String botId,
    String scope,
    String contextId,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
    String? filter,
  });

  /// Returns the remaining TTL of a scoped variable in milliseconds,
  /// or null if the variable does not exist or has no TTL.
  Future<int?> getScopedVariableTtl(
    String botId,
    String scope,
    String contextId,
    String key,
  );
}
