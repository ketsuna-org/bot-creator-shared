/// Abstract interface over bot data storage.
/// Both [AppManager] (Flutter app) and [RunnerDataStore] (CLI runner) implement this.
abstract class BotDataStore {
  /// Returns scoped variable definitions for [botId].
  ///
  /// Each entry typically contains:
  /// - `scope`: guild|channel|user|guildMember|message
  /// - `key`: variable key (with or without bc_ prefix)
  /// Returns a list of all commands for [botId].
  Future<List<Map<String, dynamic>>> getCommands(String botId);

  /// Returns scoped variable definitions for [botId].
  ///
  /// Each entry typically contains:
  /// - `scope`: guild|channel|user|guildMember|message
  /// - `key`: variable key (with or without bc_ prefix)
  /// - `defaultValue`: fallback value when missing/empty
  Future<List<Map<String, dynamic>>> getScopedVariableDefinitions(String botId);

  /// Adds or updates a scoped variable definition for [botId].
  Future<void> setScopedVariableDefinition(
    String botId,
    String key,
    String scope,
    dynamic defaultValue, {
    String valueType = 'string',
  });

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

  /// Returns scoped variables for [scope] and [contextId].
  Future<Map<String, dynamic>> getScopedVariables(
    String botId,
    String scope,
    String contextId,
  );

  /// Returns a single scoped variable.
  Future<dynamic> getScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Persists or updates a scoped variable.
  Future<void> setScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic value, {
    String? ttl,
  });

  /// Renames a scoped variable key.
  Future<void> renameScopedVariable(
    String botId,
    String scope,
    String contextId,
    String oldKey,
    String newKey,
  );

  /// Removes a scoped variable.
  Future<void> removeScopedVariable(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Lists scoped variable entries for a [scope]+[key] index with pagination.
  Future<Map<String, dynamic>> queryScopedVariableIndex(
    String botId,
    String scope,
    String key, {
    int offset = 0,
    int limit = 25,
    bool descending = true,
  });

  // Array operations

  /// Push an element to the end of a scoped array.
  Future<void> pushScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    dynamic element,
  );

  /// Pop the last element from a scoped array.
  Future<dynamic> popScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Remove an element at [index] from a scoped array.
  Future<dynamic> removeScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  );

  /// Get an element at [index] from a scoped array.
  Future<dynamic> getScopedArrayElement(
    String botId,
    String scope,
    String contextId,
    String key,
    int index,
  );

  /// Get the length of a scoped array.
  Future<int> getScopedArrayLength(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// List elements of a scoped array with pagination, sorting, and filtering.
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

  /// Finds a workflow by name (case-insensitive), or null if not found.
  Future<Map<String, dynamic>?> getWorkflowByName(String botId, String name);

  /// Returns the remaining TTL of a scoped variable in milliseconds,
  /// or null if the variable does not exist or has no TTL.
  Future<int?> getScopedVariableTtl(
    String botId,
    String scope,
    String contextId,
    String key,
  );

  /// Returns the full application data for [botId].
  Future<Map<String, dynamic>> getApp(String botId);

  /// Returns all workflows defined for [botId].
  Future<List<Map<String, dynamic>>> getWorkflows(String botId);

  /// Returns a list of all commands for [botId].
  Future<List<Map<String, dynamic>>> listAppCommands(
    String botId, {
    bool forceRefresh = false,
  });

  /// Persists or updates a command for [botId].
  Future<void> saveAppCommand(
    String botId,
    String commandId,
    Map<String, dynamic> data,
  );

  /// Updates the guild count metric for [botId].
  Future<void> updateGuildCount(String botId, int count);

  /// Records a command execution event for metrics.
  Future<void> recordCommandExecution(String botId, String commandName);

  /// Normalizes raw command data structure for execution.
  Map<String, dynamic> normalizeCommandData(Map<String, dynamic> raw);
}
