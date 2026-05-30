part of '../bdfd_ast_transpiler.dart';

class _PendingResponse {
  final StringBuffer _content = StringBuffer();
  final List<Map<String, dynamic>> _embeds = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> _components = <Map<String, dynamic>>[];
  bool _ephemeral = false;
  bool _tts = false;
  bool _removeLinks = false;
  bool _allowMentions = true;
  List<String>? _allowedUsers;
  List<String>? _allowedRoles;
  String? _currentSelectMenuId;
 
  /// When non-null, the pending response should be sent as a Discord reply
  /// (reply chain). The value is the target message ID to reply to.
  /// `'((message.id))'` means reply to the invoking message (author).
  String? _replyMessageId;
 
  /// The channel ID where the target message lives.
  /// Defaults to `'((channel.id))'` when replying to the author.
  String? _replyChannelId;
 
  bool get hasPendingContent =>
      _content.toString().isNotEmpty ||
      _embeds.any((e) => e.isNotEmpty) ||
      _components.isNotEmpty;
 
  void appendContent(String value) {
    _content.write(value);
  }
 
  Map<String, dynamic> ensureEmbed([int index = 0]) {
    while (_embeds.length <= index) {
      _embeds.add(<String, dynamic>{});
    }
    return _embeds[index];
  }
 
  String? get lastComponentType =>
      _components.isEmpty ? null : _components.last['type']?.toString();
 
  Map<String, dynamic>? get lastComponent =>
      _components.isEmpty ? null : _components.last;
 
  void addComponent(Map<String, dynamic> component) {
    _components.add(component);
  }
 
  void addButton({
    required bool newRow,
    required String interactionIdOrUrl,
    required String label,
    required String style,
    bool disabled = false,
    String emoji = '',
    String messageId = '',
  }) {
    _components.add(<String, dynamic>{
      'type': 'button',
      'newRow': newRow,
      'customId': style != 'link' ? interactionIdOrUrl : '',
      'url': style == 'link' ? interactionIdOrUrl : '',
      'label': label,
      'style': style,
      'disabled': disabled,
      if (emoji.isNotEmpty) 'emoji': emoji,
      if (messageId.isNotEmpty) 'messageId': messageId,
    });
  }
 
  void addSelectMenuOption({
    required String menuId,
    required String label,
    required String value,
    String description = '',
    bool isDefault = false,
    String emoji = '',
  }) {
    _components.add(<String, dynamic>{
      'type': 'selectMenuOption',
      'menuId': menuId,
      'label': label,
      'value': value,
      if (description.isNotEmpty) 'description': description,
      'default': isDefault,
      if (emoji.isNotEmpty) 'emoji': emoji,
    });
  }
 
  void clearComponents() {
    _components.clear();
  }
 
  /// Marks this pending response as a Discord reply to the given message.
  /// Pass `null` for both to reply to the invoking message (author).
  void markAsReply({String? channelId, String? messageId}) {
    _replyChannelId = channelId ?? '((channel.id))';
    _replyMessageId = messageId ?? '((message.id))';
  }
 
  void clearButtons() {
    _components.removeWhere((component) => component['type'] == 'button');
  }
 
  void removeComponent(String customId) {
    _components.removeWhere(
      (component) =>
          component['customId'] == customId || component['menuId'] == customId,
    );
  }
 
  /// Edits the button at the given 1-based [row] and [col] position.
  /// Only non-null arguments overwrite the existing value.
  void editButton({
    required int row,
    required int col,
    String? label,
    String? style,
    String? customIdOrUrl,
    bool? disabled,
    String? emoji,
  }) {
    int currentRow = 0;
    int currentCol = 0;
    for (final component in _components) {
      if (component['type'] != 'button') continue;
      if (currentCol == 0 || component['newRow'] == true) {
        currentRow++;
        currentCol = 1;
      } else {
        currentCol++;
      }
      if (currentRow == row && currentCol == col) {
        if (label != null) component['label'] = label;
        if (style != null) component['style'] = style;
        if (customIdOrUrl != null) {
          final resolvedStyle = style ?? component['style']?.toString() ?? '';
          if (resolvedStyle == 'link') {
            component['url'] = customIdOrUrl;
            component['customId'] = '';
          } else {
            component['customId'] = customIdOrUrl;
            component['url'] = '';
          }
        }
        if (disabled != null) component['disabled'] = disabled;
        if (emoji != null) component['emoji'] = emoji;
        break;
      }
    }
  }
 
  /// Edits a button identified by its custom ID or URL.
  void editButtonByIdOrUrl({
    required String buttonIdOrUrl,
    String? label,
    String? style,
    bool? disabled,
    String? emoji,
  }) {
    for (final component in _components) {
      if (component['type'] != 'button') continue;
      if (component['customId'] != buttonIdOrUrl &&
          component['url'] != buttonIdOrUrl) {
        continue;
      }
      if (label != null) component['label'] = label;
      if (style != null) component['style'] = style;
      if (disabled != null) component['disabled'] = disabled;
      if (emoji != null) {
        if (emoji.isNotEmpty) {
          component['emoji'] = emoji;
        } else {
          component.remove('emoji');
        }
      }
      break;
    }
  }
 
  /// Edits the select menu with the given [customId].
  /// Only non-null arguments overwrite the existing value.
  void editSelectMenu({
    required String customId,
    String? placeholder,
    int? minValues,
    int? maxValues,
    bool? disabled,
  }) {
    for (final component in _components) {
      if (component['type'] != 'selectMenu') continue;
      if (component['customId'] != customId) continue;
      if (placeholder != null) component['placeholder'] = placeholder;
      if (minValues != null) component['minValues'] = minValues;
      if (maxValues != null) component['maxValues'] = maxValues;
      if (disabled != null) component['disabled'] = disabled;
      break;
    }
  }
 
  /// Edits the select menu option at 1-based [index] inside menu [menuId].
  /// Empty string values are treated as "clear the field".
  void editSelectMenuOption({
    required String menuId,
    required int index,
    String? label,
    String? value,
    String? description,
    bool? isDefault,
    String? emoji,
  }) {
    int currentIndex = 0;
    for (final component in _components) {
      if (component['type'] != 'selectMenuOption') continue;
      if (component['menuId'] != menuId) continue;
      currentIndex++;
      if (currentIndex == index) {
        if (label != null) component['label'] = label;
        if (value != null) component['value'] = value;
        if (description != null) {
          if (description.isNotEmpty) {
            component['description'] = description;
          } else {
            component.remove('description');
          }
        }
        if (isDefault != null) component['default'] = isDefault;
        if (emoji != null) {
          if (emoji.isNotEmpty) {
            component['emoji'] = emoji;
          } else {
            component.remove('emoji');
          }
        }
        break;
      }
    }
  }
 
  List<Map<String, dynamic>> ensureEmbedFields([int index = 0]) {
    final embed = ensureEmbed(index);
    final current = embed['fields'];
    if (current is List<Map<String, dynamic>>) {
      return current;
    }
    if (current is List) {
      final casted = current
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList(growable: true);
      embed['fields'] = casted;
      return casted;
    }
    final fields = <Map<String, dynamic>>[];
    embed['fields'] = fields;
    return fields;
  }
 
  Action? buildAction({String? channelId}) {
    var content = _content.toString();
    final hasEmbed = _embeds.any((e) => e.isNotEmpty);
    final hasComponents = _components.isNotEmpty;
    if (content.trim().isEmpty && !hasEmbed && !hasComponents) {
      return null;
    }
 
    // $removeLinks: strip all URLs from the bot response content.
    if (_removeLinks) {
      content = content.replaceAll(RegExp(r'https?://[^\s]+'), '');
    }
 
    final embeds = _embeds
        .where((e) => e.isNotEmpty)
        .map(_cloneMap)
        .toList(growable: false);
    final components =
        hasComponents
            ? List<Map<String, dynamic>>.from(
              _components
                  .where((c) {
                    if (c['type']?.toString() == 'actionRow') {
                      final children = c['components'] as List?;
                      return children != null && children.isNotEmpty;
                    }
                    return true;
                  })
                  .map(_cloneMap),
            )
            : <Map<String, dynamic>>[];
    final ephemeral = _ephemeral;
    final tts = _tts;
    final allowMentions = _allowMentions;
    final allowedUsers = _allowedUsers;
    final allowedRoles = _allowedRoles;
    final replyMessageId = _replyMessageId;
    final replyChannelId = _replyChannelId;
    _content.clear();
    _embeds.clear();
    _components.clear();
    _ephemeral = false;
    _tts = false;
    _removeLinks = false;
    _allowMentions = true;
    _allowedUsers = null;
    _allowedRoles = null;
    _replyMessageId = null;
    _replyChannelId = null;

    final allowedMentionsPayload = <String, dynamic>{};
    if (allowMentions) {
      final parse = <String>[];
      if (allowedUsers == null) {
        parse.add('users');
      } else if (allowedUsers.isNotEmpty) {
        allowedMentionsPayload['users'] = allowedUsers;
      }
      if (allowedRoles == null) {
        parse.add('roles');
      } else if (allowedRoles.isNotEmpty) {
        allowedMentionsPayload['roles'] = allowedRoles;
      }
      allowedMentionsPayload['parse'] = parse;
    } else {
      allowedMentionsPayload['parse'] = <String>[];
    }

    const richV2Types = {
      'container',
      'section',
      'thumbnail',
      'separator',
      'textDisplay',
      'mediaGallery',
    };
    final hasRichV2 = components.any(
      (c) => richV2Types.contains(c['type']?.toString()),
    );

    if (hasRichV2) {
      return Action(
        type: BotCreatorActionType.respondWithComponentV2,
        payload: <String, dynamic>{
          if (content.trim().isNotEmpty) 'content': content,
          'components': <String, dynamic>{'items': components},
          'ephemeral': ephemeral,
          if (channelId != null && channelId.isNotEmpty) 'channelId': channelId,
        },
      );
    }

    // When $reply (or $reply[channel;message]) was used as a response
    // mutation, emit a sendMessage with targetType 'reply' instead of a plain
    // respondWithMessage.
    if (replyMessageId != null) {
      return Action(
        type: BotCreatorActionType.sendMessage,
        payload: <String, dynamic>{
          'targetType': 'reply',
          'channelId': replyChannelId ?? '((channel.id))',
          'messageId': replyMessageId,
          'content': content,
          'embeds': embeds,
          'components':
              components.isEmpty
                  ? const <String, dynamic>{}
                  : <String, dynamic>{'items': components},
          'ephemeral': ephemeral,
          if (tts) 'tts': true,
          'allowedMentions': allowedMentionsPayload,
        },
      );
    }

    return Action(
      type: BotCreatorActionType.respondWithMessage,
      payload: <String, dynamic>{
        'content': content,
        'embeds': embeds,
        'components':
            components.isEmpty
                ? const <String, dynamic>{}
                : <String, dynamic>{'items': components},
        'ephemeral': ephemeral,
        if (tts) 'tts': true,
        'allowedMentions': allowedMentionsPayload,
        if (channelId != null && channelId.isNotEmpty) 'channelId': channelId,
      },
    );
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> value) {
    return value.map((key, entryValue) {
      if (entryValue is Map) {
        return MapEntry(key, _cloneMap(Map<String, dynamic>.from(entryValue)));
      }
      if (entryValue is List) {
        return MapEntry(
          key,
          entryValue
              .map((item) {
                if (item is Map) {
                  return _cloneMap(Map<String, dynamic>.from(item));
                }
                return item;
              })
              .toList(growable: false),
        );
      }
      return MapEntry(key, entryValue);
    });
  }
}

class _GuardIdsAndMessage {
  const _GuardIdsAndMessage({required this.ids, required this.message});

  final List<String> ids;
  final String message;
}

class _GuardValuesAndMessage {
  const _GuardValuesAndMessage({required this.values, required this.message});

  final List<String> values;
  final String message;
}

class _MessageContainsArgs {
  const _MessageContainsArgs({
    required this.message,
    required this.words,
    required this.errorMessage,
  });

  final String message;
  final List<String> words;
  final String errorMessage;
}

class _PermissionGuardArgs {
  const _PermissionGuardArgs({
    required this.permissions,
    required this.message,
  });

  final List<String> permissions;
  final String message;
}

class _CheckUserPermsParsed {
  const _CheckUserPermsParsed({required this.condition, required this.message});

  final _ParsedCondition condition;
  final String message;
}

class _ParsedCondition {
  const _ParsedCondition({
    required this.left,
    required this.operator,
    required this.right,
  }) : group = null,
       conditions = const <_ParsedCondition>[],
       negate = false;

  const _ParsedCondition.logical({
    required this.group,
    required this.conditions,
    this.negate = false,
  }) : left = '',
       operator = '',
       right = '';

  final String left;
  final String operator;
  final String right;
  final String? group;
  final List<_ParsedCondition> conditions;
  final bool negate;

  Map<String, dynamic> toPayload({required String prefix}) {
    final conditionGroup = group;
    if (conditionGroup == null) {
      return <String, dynamic>{
        '${prefix}variable': left,
        '${prefix}operator': operator,
        '${prefix}value': right,
      };
    }

    return <String, dynamic>{
      '${prefix}group': conditionGroup,
      '${prefix}negate': negate,
      '${prefix}conditions': conditions
          .map((condition) => condition.toPayload(prefix: ''))
          .toList(growable: false),
      '${prefix}variable': '',
      '${prefix}operator': 'equals',
      '${prefix}value': '',
    };
  }
}

class _IfBranch {
  _IfBranch({required this.conditionNode, required this.nodes});

  final BdfdFunctionCallAst conditionNode;
  final List<BdfdAstNode> nodes;
}

class _ConsumedIfBlock {
  const _ConsumedIfBlock({required this.action, required this.nextIndex});

  final Action action;
  final int nextIndex;
}

class _ConsumedLoopBlock {
  const _ConsumedLoopBlock({
    this.precomputedActions,
    required this.nextIndex,
    required this.bodyNodes,
    required this.iterations,
    this.cStyleInit,
    this.cStyleCondition,
    this.cStyleUpdate,
    this.isRuntimeLoop = false,
    this.runtimeIterations,
    this.runtimeInit,
    this.runtimeCondition,
    this.runtimeUpdate,
    this.runtimeVarNames,
  });

  /// Pre-computed actions (used by try/catch blocks that reuse this class).
  final List<Action>? precomputedActions;
  final int nextIndex;
  final List<BdfdAstNode> bodyNodes;
  final int iterations;

  /// C-style for loop fields (non-null when [isCStyleLoop] is true).
  final Map<String, int>? cStyleInit;
  final String? cStyleCondition;
  final String? cStyleUpdate;

  bool get isCStyleLoop => cStyleInit != null;

  /// Runtime loop fields (when loop bounds depend on runtime placeholders).
  final bool isRuntimeLoop;
  final String? runtimeIterations;
  final String? runtimeInit;
  final String? runtimeCondition;
  final String? runtimeUpdate;
  final Set<String>? runtimeVarNames;
  bool get isRuntimeCStyleLoop => runtimeInit != null;
}

class _ConsumedJsonForEachBlock {
  const _ConsumedJsonForEachBlock({
    required this.action,
    required this.nextIndex,
  });
  final Action action;
  final int nextIndex;
}

bool _parseBooleanLike(String raw) {
  final normalized = raw.trim().toLowerCase();
  return normalized == 'yes' ||
      normalized == 'true' ||
      normalized == '1' ||
      normalized == 'on';
}

const int _maxSupportedLoopIterations = 100;

const Map<String, String> _inlineRuntimeVariables = <String, String>{
  // ── User / author info ── (resolved via generateKeyValues / _messageContentExtra / buildInteractionCreateEventContext)
  'user': '<@((user.id))>',
  'userid': '((user.id))',
  'username': '((user.username))',
  'usertag': '((user.tag))',
  'useravatar': '((user.avatar))',
  'userbanner': '((user.banner))',
  'authorid': '((author.id))',
  'authorofmessage': '((target.message.author.id|author.id))',
  'authorusername': '((author.username))',
  'authortag': '((author.tag))',
  'authoravatar': '((author.avatar))',
  'authorbanner': '((author.banner))',
  'discriminator': '((author.tag))',
  'displayname': '((member.nick|author.displayName|author.username))',
  'isadmin': '((member.isAdmin))',
  'isbot': '((author.isBot))',
  'nickname': '((member.nick|member.displayName|author.displayName|author.username))',
  'memberid': '((member.id))',
  'membernick': '((member.nick|member.displayName|author.displayName|author.username))',
  'userperms': '((member.permissions))',
  'userserveravatar': '((member.avatar))',
  'finduser': '((user.id))',
  'creationdate': '((user.createdAt))',
  'userjoineddiscord': '((user.createdAt))',
  'isbooster': '((member.isBooster))',
  'userbannercolor': '((user.bannerColor))',
  'userjoined': '((member.joinedAt))',
  // ── User info — not yet resolved (need runtime support) ──
  'getuserstatus': '((user.status))',
  'getcustomstatus': '((user.customStatus))',
  'isuserdmenabled': '((user.dmEnabled))',
  'userbadges': '((user.badges))',
  'userexists': '((user.exists))',
  'userinfo': '((user.info))',
  'hypesquad': '((user.hypesquad))',
  // ── Guild / server info ── (resolved via generateKeyValues + extractGuildRuntimeDetails)
  'guildid': '((guild.id))',
  'guildname': '((guild.name))',
  'guildicon': '((guildIcon))',
  'guildcount': '((guild.count))',
  'membercount': '((guild.memberCount))',
  'allmemberscount': '((guild.memberCount))',
  'memberscount': '((guild.memberCount))',
  'getmemberscount': '((guild.memberCount))',
  'serverid': '((guild.id))',
  'servername': '((guild.name))',
  'servericon': '((guildIcon))',
  'serverdescription': '((guild.description))',
  'serverowner': '((guild.ownerId))',
  'serververificationlvl': '((guild.verificationLevel))',
  'serververificationlevel': '((guild.verificationLevel))',
  'serverboostcount': '((guild.premiumSubscriptionCount))',
  'serverfeatures': '((guild.features))',
  'servervanityurl': '((guild.vanityUrlCode))',
  'boostcount': '((guild.premiumSubscriptionCount))',
  'boostlevel': '((guild.premiumTier))',
  'guildbanner': '((guild.banner))',
  'serverbanner': '((guild.banner))',
  'serversplash': '((guild.splash))',
  'afktimeout': '((guild.afkTimeout))',
  'stickercount': '((guild.stickerCount))',
  'rolenames': '((guild.roleNames))',
  'rolecount': '((guild.roleCount))',
  // ── Guild info — not yet resolved (need runtime support) ──
  'guildexists': '((guild.exists))',
  'serverexists': '((guild.exists))',
  'onlinemembers': '((guild.onlineMembers))',
  'serveremojis': '((guild.emojis))',
  'serverinfo': '((guild.info))',
  'serverregion': '((guild.region))',
  // ── Channel info ── (resolved via generateKeyValues + extractChannelRuntimeDetails)
  'channelid': '((channel.id))',
  'channelname': '((channel.name))',
  'channeltype': '((channel.type))',
  'channeltopic': '((channel.topic))',
  'channelposition': '((channel.position))',
  'parentid': '((channel.parentId))',
  'categoryid': '((channel.parentId))',
  'channelcategoryid': '((channel.parentId))',
  'ruleschannelid': '((guild.rulesChannelId))',
  'systemchannelid': '((guild.systemChannelId))',
  'afkchannelid': '((guild.afkChannelId))',
  'getslowmode': '((channel.slowmode))',
  'voiceuserlimit': '((channel.userLimit))',
  'isnsfw': '((channel.nsfw))',
  'channelnsfw': '((channel.nsfw))',
  'findchannel': '((channel.id))',
  // ── Channel info — not yet resolved (need runtime support) ──
  'channelcount': '((guild.channelCount))',
  'channelexists': '((channel.exists))',
  'channelnames': '((guild.channelNames))',
  'channelidfromname': '((channel.idByName))',
  'categorycount': '((guild.categoryCount))',
  'categorychannels': '((channel.parent.channels))',
  'dmchannelid': '((user.dmChannelId))',
  'lastmessageid': '((channel.lastMessageId))',
  'lastpintimestamp': '((channel.lastPinTimestamp))',
  'usersinchannel': '((channel.userCount))',
  'serverchannelexists': '((channel.exists))',
  // ── Bot info ── (resolved via extractBotRuntimeDetails + runner gateway)
  'servercount': '((bot.guildCount))',
  'servernames': '((bot.guildNames))',
  'botid': '((bot.id))',
  'botname': '((bot.username))',
  'botcount': '((bot.guildCount))',
  'ping': '((bot.ping))',
  'uptime': '((bot.uptime))',
  'shardid': '((bot.shardId))',
  'getbotinvite': '((bot.invite))',
  'scriptlanguage': 'BDFD',
  // ── Bot info — resolved via _injectGatewayBotVariables ──
  'botownerid': '((bot.ownerId))',
  'botcommands': '((bot.commands))',
  'executiontime': '((execution.time))',
  'nodeversion': '((bot.nodeVersion))',
  'slashcommandscount': '((bot.slashCommandsCount))',
  'commandscount': '((bot.commandsCount))',
  // ── Command / interaction context ── (resolved via generateKeyValues / runner)
  'commandname': '((commandName))',
  'commandtype': '((commandType))',
  'commandtrigger': '((commandName))',
  'customid': '((interaction.customId))',
  'slashid': '((interaction.id))',
  // ── Command — not yet resolved ──
  'commandfolder': '((command.folder))',
  'input': '((interaction.input))',
  // ── Message info ── (resolved via _messageContentExtra)
  'messageid': '((message.id))',
  'messagetype': '((message.type))',
  'mentioned': '((message.mentions[0]))',
  'messageurl': '((message.url))',
  'messagetimestamp': '((message.timestamp))',
  'repliedmessageid': '((message.referencedMessage.id))',
  'ismessageedited': '((message.isEdited))',
  'messageeditedtimestamp': '((message.editedTimestamp))',
  'getattachments': '((message.attachments))',
  'url': '((message.url))',
  'mentionedroles': '((message.roleMentions))',
  // ── Message info — not yet resolved (need runtime support) ──
  'ismentioned': '((message.isMentioned))',
  'nomentionmessage': '((message.cleanContent))',
  'getembeddata': '((message.embeds))',
  // ── Role info ── (resolved via extractMemberRuntimeDetails + extractGuildRuntimeDetails)
  'userroles': '((member.roles))',
  // ── Role info — not yet resolved (need runtime support) ──
  'highestrole': '((member.highestRole))',
  'lowestrole': '((member.lowestRole))',
  'highestrolewithperms': '((member.highestRoleWithPerms))',
  'lowestrolewithperms': '((member.lowestRoleWithPerms))',
  // ── Thread info — not yet resolved ──
  'threadmessagecount': '((thread.messageCount))',
  'threadusercount': '((thread.memberCount))',
  // ── Moderation query — not yet resolved ──
  'isbanned': '((target.isBanned))',
  'istimedout': '((target.isTimedOut))',
  'getbanreason': '((target.banReason))',
  // ── Error handling ── (only available in try/catch context)
  'error': '((error.message))',
  // ── Misc ──
  'argcount': '((args.count))',
  'isslash': '((interaction.isSlash))',
  'variablescount': '((variables.count))',
  // ── Select menu interaction results ──
  'getmentionableselectusercount':
      '((interaction.mentionableSelect.userCount))',
  'getuserselectusercount': '((interaction.userSelect.userCount))',
  'getroleselectrolecount': '((interaction.roleSelect.roleCount))',
  'getchannelselectchannelcount': '((interaction.channelSelect.channelCount))',
  'getstringselectcount': '((interaction.stringSelect.count))',
  // ── Logging ──
  'logquota': '((log.quota))',
  // ── No-op compatibility (return empty string) ──
  'alternativeparsing': '',
  'disableinnerspaceremoval': '',
  'disablespecialescaping': '',
  'enabledecimals': '',
  'optoff': '',
  'ignorelinks': '',
  'botlistdescription': '',
  'botlisthide': '',
  'botnode': '',
  'deletecommand': '',
};

const Set<String> _knownBdfdPermissionTokens = <String>{
  'addreactions',
  'administrator',
  'attachfiles',
  'banmembers',
  'changenickname',
  'connect',
  'createinstantinvite',
  'createprivatethreads',
  'createpublicthreads',
  'deafenmembers',
  'embedlinks',
  'kickmembers',
  'managechannels',
  'manageevents',
  'manageguild',
  'manageguildexpressions',
  'managemessages',
  'managenicknames',
  'manageroles',
  'managethreads',
  'managewebhooks',
  'mentioneveryone',
  'moderatemembers',
  'movemembers',
  'mutemembers',
  'priorityspeaker',
  'readmessagehistory',
  'requesttospeak',
  'sendmessages',
  'sendmessagesinthreads',
  'sendttsmessages',
  'sendvoicemessages',
  'speak',
  'stream',
  'useapplicationcommands',
  'useexternalemojis',
  'useexternalstickers',
  'usesoundboard',
  'usevoiceactivity',
  'viewauditlog',
  'viewchannel',
  'viewguildinsights',
};

const Map<String, String> _permissionTokenAliases = <String, String>{
  'admin': 'administrator',
  'ban': 'banmembers',
  'kick': 'kickmembers',
  'changenicknames': 'changenickname',
  'externalemojis': 'useexternalemojis',
  'externalstickers': 'useexternalstickers',
  'manageemojis': 'manageguildexpressions',
  'manageserver': 'manageguild',
  'readmessages': 'viewchannel',
  'slashcommands': 'useapplicationcommands',
  'tts': 'sendttsmessages',
  'usevad': 'usevoiceactivity',
  'voicedeafen': 'deafenmembers',
  'voicemute': 'mutemembers',
};
