part of '../bdfd_ast_transpiler.dart';

extension _BdfdAstTranspilationScopeActionBuilders
    on _BdfdAstTranspilationScope {
  Action? _buildChannelSendMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);

    if (channelId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    if (content.trim().isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires message content as second argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'channel',
        'channelId': channelId,
        'content': content,
      },
    );
  }

  Action? _buildChangeUsernameAction(BdfdFunctionCallAst node) {
    final username = _stringifyArgument(node, 0).trim();
    if (username.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a username.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    return Action(
      type: BotCreatorActionType.updateSelfUser,
      payload: <String, dynamic>{'username': username},
    );
  }

  Action? _buildChangeUsernameWithIdAction(BdfdFunctionCallAst node) {
    final targetId = _stringifyArgument(node, 0).trim();
    final username = _stringifyArgument(node, 1).trim();

    if (targetId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a user ID as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    if (username.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a username as second argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final updateAction = Action(
      type: BotCreatorActionType.updateSelfUser,
      payload: <String, dynamic>{'username': username},
    );

    final condition = _ParsedCondition(
      left: targetId,
      operator: 'equals',
      right: '((user.id))',
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: <Action>[updateAction],
      elseActions: const <Action>[],
    );
  }

  // ── Moderation action builders ──────────────────────────────────────

  Action _buildBanAction(BdfdFunctionCallAst node) {
    return Action(
      type: BotCreatorActionType.banUser,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]|author.id))',
        'reason': '',
        'deleteMessageDays': 0,
      },
    );
  }

  Action _buildBanIdAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $banID takes no args — the user ID is extracted from the
    // last word of the author's message at runtime.
    return Action(
      type: BotCreatorActionType.banUser,
      payload: <String, dynamic>{
        'userId': '((message.args.last))',
        'reason': '',
        'deleteMessageDays': 0,
      },
    );
  }

  Action _buildUnbanAction(BdfdFunctionCallAst node) {
    return Action(
      type: BotCreatorActionType.unbanUser,
      payload: <String, dynamic>{'userId': '((message.mentions[0]|author.id))'},
    );
  }

  Action _buildUnbanIdAction(BdfdFunctionCallAst node) {
    final userId = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.unbanUser,
      payload: <String, dynamic>{
        'userId': userId.isEmpty ? '((message.mentions[0]))' : userId,
      },
    );
  }

  Action _buildKickAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $kick always kicks the command author, not a mentioned user.
    return Action(
      type: BotCreatorActionType.kickUser,
      payload: <String, dynamic>{'userId': '((author.id))', 'reason': ''},
    );
  }

  Action _buildKickMentionAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $kickMention[Reason] kicks the mentioned user with a reason.
    final reason = _stringifyArgument(node, 0);
    return Action(
      type: BotCreatorActionType.kickUser,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]))',
        'reason': reason,
      },
    );
  }

  Action _buildTimeoutAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $timeout[Duration;(User ID)]
    // arg 0 = duration (required), arg 1 = user ID (optional).
    final duration = _stringifyArgument(node, 0).trim();
    final userId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.muteUser,
      payload: <String, dynamic>{
        'userId': userId.isEmpty ? '((message.mentions[0]))' : userId,
        'duration': duration,
        'reason': '',
      },
    );
  }

  Action _buildUntimeoutAction(BdfdFunctionCallAst node) {
    final userId = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.unmuteUser,
      payload: <String, dynamic>{
        'userId': userId.isEmpty ? '((message.mentions[0]))' : userId,
      },
    );
  }

  Action _buildMuteAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $mute[Muted Role Name] — DEPRECATED.
    // Assigns the named role to the mentioned user.
    final roleName = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]))',
        'roleName': roleName,
      },
    );
  }

  Action _buildUnmuteAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $unmute[Muted Role Name] — DEPRECATED.
    // Removes the named role from the mentioned user.
    final roleName = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.removeRole,
      payload: <String, dynamic>{
        'userId': '((message.mentions[0]))',
        'roleName': roleName,
      },
    );
  }

  Action _buildClearAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $clear takes no args — count from the author's message
    // content at runtime.
    return Action(
      type: BotCreatorActionType.deleteMessages,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'count': '((message.args[0]))',
      },
    );
  }

  // ── Role action builders ──────────────────────────────────────────

  Action _buildGiveRoleAction(BdfdFunctionCallAst node) {
    final firstArg = _stringifyArgument(node, 0).trim();
    final secondArg = _stringifyArgument(node, 1).trim();
    final hasSecondArg = secondArg.isNotEmpty;
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'userId': hasSecondArg ? firstArg : '((message.mentions[0]|author.id))',
        'roleId': hasSecondArg ? secondArg : firstArg,
      },
    );
  }

  Action _buildTakeRoleAction(BdfdFunctionCallAst node) {
    final firstArg = _stringifyArgument(node, 0).trim();
    final secondArg = _stringifyArgument(node, 1).trim();
    final hasSecondArg = secondArg.isNotEmpty;
    return Action(
      type: BotCreatorActionType.removeRole,
      payload: <String, dynamic>{
        'userId': hasSecondArg ? firstArg : '((message.mentions[0]|author.id))',
        'roleId': hasSecondArg ? secondArg : firstArg,
      },
    );
  }

  /// $giveRoles[Role ID;Role ID;...] / $takeRoles[Role ID;Role ID;...]
  List<Action> _buildMultiRoleAction(
    BdfdFunctionCallAst node, {
    required bool give,
  }) {
    final actions = <Action>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final roleId = _stringifyArgument(node, i).trim();
      if (roleId.isEmpty) continue;
      actions.add(
        Action(
          type:
              give
                  ? BotCreatorActionType.addRole
                  : BotCreatorActionType.removeRole,
          payload: <String, dynamic>{
            'userId': '((message.mentions[0]|author.id))',
            'roleId': roleId,
          },
        ),
      );
    }
    return actions;
  }

  List<Action> _buildRoleGrantAction(BdfdFunctionCallAst node) {
    // BDFD wiki: $roleGrant[User ID;+/-Role ID;...]
    final userId = _stringifyArgument(node, 0).trim();
    if (userId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a user ID as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return const <Action>[];
    }
    final actions = <Action>[];
    for (var i = 1; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i).trim();
      if (raw.isEmpty) continue;
      final isRemove = raw.startsWith('-');
      final isAdd = raw.startsWith('+');
      final roleId = (isRemove || isAdd) ? raw.substring(1).trim() : raw;
      if (roleId.isEmpty) continue;
      actions.add(
        Action(
          type:
              isRemove
                  ? BotCreatorActionType.removeRole
                  : BotCreatorActionType.addRole,
          payload: <String, dynamic>{'userId': userId, 'roleId': roleId},
        ),
      );
    }
    return actions;
  }

  Action? _buildCreateRoleAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    if (name.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final color = _stringifyArgument(node, 1);
    final hoist = _parseBooleanLike(_stringifyArgument(node, 2));
    final mentionable = _parseBooleanLike(_stringifyArgument(node, 3));
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'createNew': true,
        'name': name,
        if (color.isNotEmpty) 'color': color,
        'hoist': hoist,
        'mentionable': mentionable,
      },
    );
  }

  Action? _buildDeleteRoleAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    if (roleId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.removeRole,
      payload: <String, dynamic>{'roleId': roleId, 'deleteRole': true},
    );
  }

  Action? _buildColorRoleAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    final color = _stringifyArgument(node, 1).trim();
    if (roleId.isEmpty || color.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID and color.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{'roleId': roleId, 'updateColor': color},
    );
  }

  Action? _buildModifyRoleAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    if (roleId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final name = _stringifyArgument(node, 1);
    final color = _stringifyArgument(node, 2);
    final hoist = _stringifyArgument(node, 3);
    final mentionable = _stringifyArgument(node, 4);
    final position = _stringifyArgument(node, 5);
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'roleId': roleId,
        'modify': true,
        if (name.isNotEmpty) 'name': name,
        if (color.isNotEmpty) 'color': color,
        if (hoist.isNotEmpty) 'hoist': _parseBooleanLike(hoist),
        if (mentionable.isNotEmpty)
          'mentionable': _parseBooleanLike(mentionable),
        if (position.isNotEmpty) 'position': int.tryParse(position),
      },
    );
  }

  Action? _buildModifyRolePermsAction(BdfdFunctionCallAst node) {
    final roleId = _stringifyArgument(node, 0).trim();
    if (roleId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final permissions = <String>[];
    for (var i = 1; i < node.arguments.length; i++) {
      final perm = _stringifyArgument(node, i).trim();
      if (perm.isNotEmpty) {
        permissions.add(_normalizePermissionToken(perm));
      }
    }
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{
        'roleId': roleId,
        'modifyPermissions': permissions,
      },
    );
  }

  Action? _buildSetUserRolesAction(BdfdFunctionCallAst node) {
    final userId = _stringifyArgument(node, 0).trim();
    if (userId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final roleIds = <String>[];
    for (var i = 1; i < node.arguments.length; i++) {
      final roleId = _stringifyArgument(node, i).trim();
      if (roleId.isNotEmpty) {
        roleIds.add(roleId);
      }
    }
    return Action(
      type: BotCreatorActionType.addRole,
      payload: <String, dynamic>{'userId': userId, 'setRoles': roleIds},
    );
  }

  // ── Message action builders ──────────────────────────────────────

  Action? _buildDeleteMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.deleteMessages,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  Action? _buildDeleteInAction(BdfdFunctionCallAst node) {
    final delay = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.deleteMessages,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'delay': delay,
      },
    );
  }

  Action _buildDmAction(BdfdFunctionCallAst node) {
    final userIdArg = _stringifyArgument(node, 0).trim();
    final contentArg = _stringifyArgument(node, 1);
    final isContentOnlyMode = userIdArg.isEmpty || node.arguments.isEmpty;
    return Action(
      type: BotCreatorActionType.sendDm,
      payload: <String, dynamic>{
        'userId': isContentOnlyMode ? '((author.id))' : userIdArg,
        'content': isContentOnlyMode ? '' : contentArg,
      },
    );
  }

  Action? _buildEditMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final content = _stringifyArgument(node, 2);
    return Action(
      type: BotCreatorActionType.editMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId,
        'content': content,
      },
    );
  }

  Action? _buildEditInAction(BdfdFunctionCallAst node) {
    final delay = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);
    return Action(
      type: BotCreatorActionType.editMessage,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'content': content,
        'delay': delay,
      },
    );
  }

  Action? _buildEditEmbedInAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final title = _stringifyArgument(node, 2);
    final description = _stringifyArgument(node, 3);
    final color = _stringifyArgument(node, 4);
    return Action(
      type: BotCreatorActionType.editMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId,
        'embeds': <Map<String, dynamic>>[
          <String, dynamic>{
            if (title.isNotEmpty) 'title': title,
            if (description.isNotEmpty) 'description': description,
            if (color.isNotEmpty) 'color': color,
          },
        ],
      },
    );
  }

  Action _buildPinMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.pinMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  Action _buildUnpinMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.unpinMessage,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  Action _buildPublishMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'crosspost',
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }



  Action _buildReplyInAction(BdfdFunctionCallAst node) {
    final delay = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);
    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'reply',
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'content': content,
        'delay': delay,
      },
    );
  }

  Action _buildSendEmbedMessageAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final title = _stringifyArgument(node, 1);
    final description = _stringifyArgument(node, 2);
    final color = _stringifyArgument(node, 3);
    return Action(
      type: BotCreatorActionType.sendMessage,
      payload: <String, dynamic>{
        'targetType': 'channel',
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'content': '',
        'embeds': <Map<String, dynamic>>[
          <String, dynamic>{
            if (title.isNotEmpty) 'title': title,
            if (description.isNotEmpty) 'description': description,
            if (color.isNotEmpty) 'color': color,
          },
        ],
      },
    );
  }

  Action? _buildUseChannelAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    if (channelId.isNotEmpty) {
      _useChannelId = channelId;
    }
    return null;
  }

  // ── Channel action builders ──────────────────────────────────────

  Action? _buildCreateChannelAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    if (name.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final type = _stringifyArgument(node, 1).trim().toLowerCase();
    final categoryId = _stringifyArgument(node, 2).trim();
    return Action(
      type: BotCreatorActionType.createChannel,
      payload: <String, dynamic>{
        'name': name,
        'type': type.isEmpty ? 'text' : type,
        if (categoryId.isNotEmpty) 'parentId': categoryId,
      },
    );
  }

  Action? _buildDeleteChannelsAction(BdfdFunctionCallAst node) {
    // $deleteChannels[Channel ID] - deletes by ID
    // $deleteChannelsByName[Channel name;...] - deletes by name(s)
    final isByName = node.normalizedName == 'deletechannelsbyname';
    final channelIds = <String>[];
    for (var i = 0; i < node.arguments.length; i++) {
      final arg = _stringifyArgument(node, i).trim();
      if (arg.isNotEmpty) {
        channelIds.add(arg);
      }
    }
    if (channelIds.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${node.name} requires at least one channel ${isByName ? 'name' : 'ID'}.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.removeChannel,
      payload: <String, dynamic>{
        if (isByName)
          'channelNames': channelIds
        else
          'channelId': channelIds.first,
      },
    );
  }

  Action? _buildModifyChannelAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    if (channelId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final name = _stringifyArgument(node, 1);
    final topic = _stringifyArgument(node, 2);
    final position = _stringifyArgument(node, 3);
    final nsfw = _stringifyArgument(node, 4);
    return Action(
      type: BotCreatorActionType.updateChannel,
      payload: <String, dynamic>{
        'channelId': channelId,
        if (name.isNotEmpty) 'name': name,
        if (topic.isNotEmpty) 'topic': topic,
        if (position.isNotEmpty) 'position': int.tryParse(position),
        if (nsfw.isNotEmpty) 'nsfw': _parseBooleanLike(nsfw),
      },
    );
  }

  Action? _buildEditChannelPermsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final roleOrUserId = _stringifyArgument(node, 1).trim();
    if (channelId.isEmpty || roleOrUserId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID and role/user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final permissions = <String>[];
    for (var i = 2; i < node.arguments.length; i++) {
      final perm = _stringifyArgument(node, i).trim();
      if (perm.isNotEmpty) {
        permissions.add(_normalizePermissionToken(perm));
      }
    }
    return Action(
      type: BotCreatorActionType.editChannelPermissions,
      payload: <String, dynamic>{
        'channelId': channelId,
        'targetId': roleOrUserId,
        'permissions': permissions,
      },
    );
  }

  /// BDFD wiki: $modifyChannelPerms[Channel ID;Permissions;User/Role ID]
  /// Arg order differs from $editChannelPerms: permissions come before the
  /// target ID.
  Action? _buildModifyChannelPermsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final permissionsRaw = _stringifyArgument(node, 1).trim();
    final targetId = _stringifyArgument(node, 2).trim();
    if (channelId.isEmpty || targetId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a channel ID and a user/role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    final permissions = <String>[];
    if (permissionsRaw.isNotEmpty) {
      for (final token in permissionsRaw.split(';')) {
        final perm = token.trim();
        if (perm.isNotEmpty) {
          permissions.add(_normalizePermissionToken(perm));
        }
      }
    }
    // Also collect any extra arguments beyond arg 2 as additional permissions.
    for (var i = 3; i < node.arguments.length; i++) {
      final perm = _stringifyArgument(node, i).trim();
      if (perm.isNotEmpty) {
        permissions.add(_normalizePermissionToken(perm));
      }
    }
    return Action(
      type: BotCreatorActionType.editChannelPermissions,
      payload: <String, dynamic>{
        'channelId': channelId,
        'targetId': targetId,
        'permissions': permissions,
      },
    );
  }

  Action _buildSlowmodeAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final seconds = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.slowmode,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'duration': '${seconds.isEmpty ? '0' : seconds}s',
      },
    );
  }

  Action _buildWaitAction(BdfdFunctionCallAst node) {
    final duration = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.wait,
      payload: <String, dynamic>{
        'duration': duration.isEmpty ? '1s' : duration,
      },
    );
  }

  Action _buildSetNicknameAction(BdfdFunctionCallAst node) {
    final nickname = _stringifyArgument(node, 0).trim();
    final userId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.setNickname,
      payload: <String, dynamic>{
        'userId': userId.isEmpty ? '((author.id))' : userId,
        'nickname': nickname,
      },
    );
  }

  Action _buildDeleteTriggerAction(BdfdFunctionCallAst node) {
    return Action(
      type: BotCreatorActionType.deleteTrigger,
      payload: const <String, dynamic>{},
    );
  }

  // ── Reaction action builders ──────────────────────────────────────

  Action _buildAddReactionsAction(BdfdFunctionCallAst node) {
    final emojis = <String>[];
    for (var index = 0; index < node.arguments.length; index++) {
      final emoji = _stringifyArgument(node, index).trim();
      if (emoji.isNotEmpty) {
        emojis.add(emoji);
      }
    }
    return Action(
      type: BotCreatorActionType.addReaction,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((message.id))',
        'emojis': emojis,
      },
    );
  }

  Action _buildAddCmdReactionsAction(BdfdFunctionCallAst node) {
    final emojis = <String>[];
    for (var index = 0; index < node.arguments.length; index++) {
      final emoji = _stringifyArgument(node, index).trim();
      if (emoji.isNotEmpty) {
        emojis.add(emoji);
      }
    }
    return Action(
      type: BotCreatorActionType.addReaction,
      payload: <String, dynamic>{
        'channelId': '((channel.id))',
        'messageId': '((trigger.message.id|message.id))',
        'emojis': emojis,
      },
    );
  }

  Action _buildAddMessageReactionsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    final emojis = <String>[];
    for (var index = 2; index < node.arguments.length; index++) {
      final emoji = _stringifyArgument(node, index).trim();
      if (emoji.isNotEmpty) {
        emojis.add(emoji);
      }
    }
    return Action(
      type: BotCreatorActionType.addReaction,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
        'emojis': emojis,
      },
    );
  }

  Action _buildClearReactionsAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final messageId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.clearAllReactions,
      payload: <String, dynamic>{
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'messageId': messageId.isEmpty ? '((message.id))' : messageId,
      },
    );
  }

  // ── Emoji action builders ──────────────────────────────────────

  Action? _buildAddEmojiAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    final imageUrl = _stringifyArgument(node, 1).trim();
    if (name.isEmpty || imageUrl.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a name and image URL.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.createEmoji,
      payload: <String, dynamic>{'name': name, 'imageUrl': imageUrl},
    );
  }

  Action? _buildRemoveEmojiAction(BdfdFunctionCallAst node) {
    final emojiId = _stringifyArgument(node, 0).trim();
    if (emojiId.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires an emoji ID or name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.deleteEmoji,
      payload: <String, dynamic>{'emojiId': emojiId},
    );
  }

  // ── Webhook action builders ──────────────────────────────────────

  Action _buildWebhookSendAction(BdfdFunctionCallAst node) {
    final webhookUrl = _stringifyArgument(node, 0).trim();
    final content = _stringifyArgument(node, 1);
    final username = _stringifyArgument(node, 2);
    final avatarUrl = _stringifyArgument(node, 3);
    return Action(
      type: BotCreatorActionType.sendWebhook,
      payload: <String, dynamic>{
        'webhookUrl': webhookUrl,
        'content': content,
        if (username.isNotEmpty) 'username': username,
        if (avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      },
    );
  }

  Action _buildWebhookCreateAction(BdfdFunctionCallAst node) {
    final channelId = _stringifyArgument(node, 0).trim();
    final name = _stringifyArgument(node, 1).trim();
    final avatarUrl = _stringifyArgument(node, 2);
    return Action(
      type: BotCreatorActionType.sendWebhook,
      payload: <String, dynamic>{
        'createWebhook': true,
        'channelId': channelId.isEmpty ? '((channel.id))' : channelId,
        'name': name,
        if (avatarUrl.isNotEmpty) 'avatarUrl': avatarUrl,
      },
    );
  }

  Action _buildWebhookDeleteAction(BdfdFunctionCallAst node) {
    final webhookUrl = _stringifyArgument(node, 0).trim();
    return Action(
      type: BotCreatorActionType.deleteWebhook,
      payload: <String, dynamic>{'webhookUrl': webhookUrl},
    );
  }

  // ── Modal action builder ──────────────────────────────────────

  Action _buildNewModalAction(BdfdFunctionCallAst node) {
    final customId = _stringifyArgument(node, 0).trim();
    final title = _stringifyArgument(node, 1).trim();
    final inputs = List<Map<String, dynamic>>.from(_pendingModalInputs);
    _pendingModalInputs.clear();
    return Action(
      type: BotCreatorActionType.respondWithModal,
      payload: <String, dynamic>{
        'customId': customId,
        'title': title,
        'components': inputs,
      },
    );
  }

  // ── Cooldown action builders ──────────────────────────────────

  Action _buildCooldownAction(
    BdfdFunctionCallAst node, {
    required String scope,
  }) {
    final duration = _stringifyArgument(node, 0).trim();
    final errorMessage = _stringifyArgument(node, 1);
    final cooldownKey = '${scope}_${node.normalizedName}';

    return Action(
      type: BotCreatorActionType.cooldown,
      payload: <String, dynamic>{
        'scope': scope == 'global' ? 'user' : scope,
        'duration': duration,
        'key': cooldownKey,
        'errorMessage': errorMessage,
      },
    );
  }

  Action? _buildChangeCooldownTimeAction(BdfdFunctionCallAst node) {
    final cooldownType = _stringifyArgument(node, 0).trim();
    final duration = _stringifyArgument(node, 1).trim();
    if (cooldownType.isEmpty || duration.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a cooldown type and new duration.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return Action(
      type: BotCreatorActionType.setScopedVariable,
      payload: <String, dynamic>{
        'scope': 'user',
        'key': 'cooldown_$cooldownType',
        'valueType': 'string',
        'value': duration,
        'ttl': duration,
      },
    );
  }

  // ── Variable reset builders ──────────────────────────────────

  Action _buildResetScopedVariableAction({
    required String scope,
    required BdfdFunctionCallAst node,
  }) {
    final key = _normalizeScopedVariableKey(_stringifyArgument(node, 0));
    return Action(
      type: BotCreatorActionType.removeScopedVariable,
      payload: <String, dynamic>{'scope': scope, 'key': key},
    );
  }

  // ── Blacklist guard builders ──────────────────────────────────

  Action? _transpileBlacklistIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((author.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistRoles(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.values
          .map(
            (name) => _ParsedCondition(
              left: '((member.roleNames))',
              operator: 'contains',
              right: name,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistRoleIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((member.roles))',
              operator: 'contains',
              right: id,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistServers(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((guild.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  Action? _transpileBlacklistUsers(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      return null;
    }
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.values
          .map(
            (username) => _ParsedCondition(
              left: '((author.username))',
              operator: 'matches',
              right:
                  '(?i)^${RegExp.escape(username)}'
                  r'$',
            ),
          )
          .toList(growable: false),
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: _buildGuardFailureActions(message: guard.message),
      elseActions: const <Action>[],
    );
  }

  // ── Ticket builder ──────────────────────────────────────────

  Action _buildNewTicketAction(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();
    final categoryId = _stringifyArgument(node, 1).trim();
    return Action(
      type: BotCreatorActionType.createChannel,
      payload: <String, dynamic>{
        'name': name.isEmpty ? 'ticket-((user.username))' : name,
        'type': 'text',
        if (categoryId.isNotEmpty) 'parentId': categoryId,
        'isTicket': true,
      },
    );
  }

  // ── Args check builder ──────────────────────────────────────

  Action? _buildArgsCheckAction(BdfdFunctionCallAst node) {
    final operatorRaw = _stringifyArgument(node, 0).trim();
    final count = _stringifyArgument(node, 1).trim();
    final errorMessage = _stringifyArgument(node, 2);

    if (count.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires an operator and count.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    String operator;
    if (operatorRaw == '>' || operatorRaw == '>=') {
      operator = operatorRaw == '>=' ? 'greaterOrEqual' : 'greaterThan';
    } else if (operatorRaw == '<' || operatorRaw == '<=') {
      operator = operatorRaw == '<=' ? 'lessOrEqual' : 'lessThan';
    } else {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${node.name}: unknown operator "$operatorRaw". '
              'Expected >, >=, <, or <=.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      operator = 'greaterOrEqual';
    }

    final condition = _ParsedCondition(
      left: '((message.argCount))',
      operator: operator,
      right: count,
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: errorMessage),
    );
  }

  // ── Inline computation helpers ──────────────────────────────────

  // ── Workflow call builder ─────────────────────────────────────

  Action? _buildCallWorkflowAction(BdfdFunctionCallAst node) {
    final workflowName = _stringifyArgument(node, 0).trim();
    if (workflowName.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires a workflow name as first argument.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final arguments = <String, dynamic>{};
    for (var i = 1; i < node.arguments.length; i++) {
      final raw = _stringifyArgument(node, i);
      final equalsIndex = raw.indexOf('=');
      if (equalsIndex > 0) {
        final key = raw.substring(0, equalsIndex).trim();
        final value = raw.substring(equalsIndex + 1);
        if (key.isNotEmpty) {
          arguments[key] = value;
          continue;
        }
      }
      arguments['$i'] = raw;
    }

    final key = '_bdfd_callworkflow_${_callWorkflowCounter++}';
    _lastCallWorkflowKey = key;

    return Action(
      type: BotCreatorActionType.runWorkflow,
      key: key,
      payload: <String, dynamic>{
        'workflowName': workflowName,
        if (arguments.isNotEmpty) 'arguments': arguments,
      },
    );
  }

  // ── Debug profiling builder ──────────────────────────────────

  Action _buildDebugAction(BdfdFunctionCallAst node) {
    return Action(
      type: BotCreatorActionType.debugProfile,
      payload: <String, dynamic>{},
    );
  }

  // ── Dynamic eval builder ─────────────────────────────────────

  Action _buildEvalAction(BdfdFunctionCallAst node) {
    final scriptContent = _stringifyArgument(node, 0);
    return Action(
      type: BotCreatorActionType.runBdfdScript,
      payload: <String, dynamic>{'scriptContent': scriptContent},
    );
  }

  String? _latestWorkflowResponsePlaceholder(BdfdFunctionCallAst node) {
    final requestKey = _lastCallWorkflowKey;
    if (requestKey == null || requestKey.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${node.name} requires a preceding \$callWorkflow in the same BDFD script.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    if (node.arguments.isEmpty) {
      return '((workflow.response))';
    }

    final property = _stringifyArgument(node, 0).trim();
    if (property.isEmpty) {
      return '((workflow.response))';
    }
    return '((workflow.response.$property))';
  }

  // ── Inline computation helpers ──────────────────────────────────

  Action? _buildRegisterGuildCommandsAction(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return Action(
        type: BotCreatorActionType.registerGuildCommands,
        payload: <String, dynamic>{},
      );
    }

    final commandNamesRaw = _stringifyArgument(node, 0);
    final commandNames =
        commandNamesRaw
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return Action(
      type: BotCreatorActionType.registerGuildCommands,
      payload: <String, dynamic>{
        if (commandNames.isNotEmpty) 'commandNames': commandNames,
      },
    );
  }

  Action? _buildUnregisterGuildCommandsAction(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return Action(
        type: BotCreatorActionType.unregisterGuildCommands,
        payload: <String, dynamic>{},
      );
    }

    final commandNamesRaw = _stringifyArgument(node, 0);
    final commandNames =
        commandNamesRaw
            .split(';')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

    return Action(
      type: BotCreatorActionType.unregisterGuildCommands,
      payload: <String, dynamic>{
        if (commandNames.isNotEmpty) 'commandNames': commandNames,
      },
    );
  }
}
