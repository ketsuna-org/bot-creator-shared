enum BotCreatorActionType {
  deleteMessages,
  createChannel,
  updateChannel,
  removeChannel,
  sendMessage,
  editMessage,
  addReaction,
  removeReaction,
  clearAllReactions,
  banUser,
  unbanUser,
  kickUser,
  muteUser,
  unmuteUser,
  addRole,
  removeRole,
  pinMessage,
  updateAutoMod,
  updateGuild,
  listMembers,
  getMember,
  /// Deprecated: use [respondWithComponentV2] instead.
  sendComponentV2,
  editComponentV2,
  sendWebhook,
  editWebhook,
  deleteWebhook,
  listWebhooks,
  getWebhook,
  httpRequest,
  setGlobalVariable,
  getGlobalVariable,
  removeGlobalVariable,
  setScopedVariable,
  setTemporaryVariable,
  getScopedVariable,
  removeScopedVariable,
  renameScopedVariable,
  listScopedVariableIndex,
  appendArrayElement,
  removeArrayElement,
  queryArray,
  runWorkflow,
  runBdfdScript,
  // Logic & Flow actions
  stopUnless,
  ifBlock,
  forLoop,
  jsonForEachLoop,
  // Interaction / Component actions
  respondWithMessage,
  respondWithComponentV2,
  respondWithModal,
  editInteractionMessage,
  respondWithAutocomplete,
  listenForButtonClick,
  listenForSelectMenu,
  listenForModalSubmit,
  // Math & Calculation
  calculate,
  // Message management
  getMessage,
  unpinMessage,
  // Poll
  createPoll,
  endPoll,
  // Invitations
  createInvite,
  deleteInvite,
  getInvite,
  // Voice management
  moveToVoiceChannel,
  disconnectFromVoice,
  serverMuteMember,
  serverDeafenMember,
  // Emoji management
  createEmoji,
  updateEmoji,
  deleteEmoji,
  // AutoMod management
  createAutoModRule,
  deleteAutoModRule,
  listAutoModRules,
  // Guild Onboarding
  getGuildOnboarding,
  updateGuildOnboarding,
  // Self user
  updateSelfUser,
  // Thread & Channel permissions
  createThread,
  addThreadMember,
  removeThreadMember,
  editChannelPermissions,
  deleteChannelPermission,
  // Debugging
  debugProfile,
  log,
  // Runtime JSON
  runtimeJsonBlock,
  // Guild Commands
  registerGuildCommands,
  unregisterGuildCommands,
  cooldown,
  wait,
  deleteTrigger,
  sendDm,
  setNickname,
  slowmode,
  stop,
  randomChoice,
}

enum ActionOnErrorMode { stop, continueMode }

class Action {
  final BotCreatorActionType type;
  final String? key; // Optional key for identifying specific actions
  final bool enabled;
  final List<String> dependOn = []; // List of actions this action depends on
  final Map<String, String> error = {}; // Error messages for the action
  final Map<String, dynamic> payload; // Additional data for the action

  Action({
    required this.type,
    this.key,
    required this.payload,
    this.enabled = true,
  });

  @override
  String toString() {
    return 'Action(type: $type, key: $key, payload: $payload)';
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'key': key,
      'enabled': enabled,
      'depend_on': dependOn,
      'error': error,
      'payload': payload,
    };
  }

  factory Action.fromJson(Map<String, dynamic> json) {
    return Action(
        type: BotCreatorActionType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse:
              () => throw ArgumentError('Invalid action type: ${json['type']}'),
        ),
        key: json['key'] as String?,
        enabled: json['enabled'] as bool? ?? true,
        payload: Map<String, dynamic>.from(json['payload'] ?? const {}),
      )
      ..dependOn.addAll(List<String>.from(json['depend_on'] ?? []))
      ..error.addAll(Map<String, String>.from(json['error'] ?? {}));
  }

  Action copyWith({
    BotCreatorActionType? type,
    String? key,
    bool? enabled,
    List<String>? dependOn,
    Map<String, String>? error,
    Map<String, dynamic>? payload,
  }) {
    return Action(
        type: type ?? this.type,
        key: key ?? this.key,
        enabled: enabled ?? this.enabled,
        payload: payload ?? this.payload,
      )
      ..dependOn.addAll(dependOn ?? this.dependOn)
      ..error.addAll(error ?? this.error);
  }

  bool get hasError => error.isNotEmpty;
  bool get hasKey => key != null && key!.isNotEmpty;
  bool get hasDependOn => dependOn.isNotEmpty;

  ActionOnErrorMode get onErrorMode {
    return error['mode'] == 'continue'
        ? ActionOnErrorMode.continueMode
        : ActionOnErrorMode.stop;
  }
}
