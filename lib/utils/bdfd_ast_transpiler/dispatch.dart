part of '../bdfd_ast_transpiler.dart';

extension _BdfdAstTranspilationScopeDispatch on _BdfdAstTranspilationScope {
  bool _applyResponseMutation(
    BdfdFunctionCallAst node,
    _PendingResponse response,
  ) {
    switch (node.normalizedName) {
      case 'nomention':
        response._allowMentions = false;
        return true;
      case 'title':
        final index = _parseEmbedIndex(node, 1);
        response.ensureEmbed(index)['title'] = _stringifyArgument(node, 0);
        return true;
      case 'description':
        final index = _parseEmbedIndex(node, 1);
        response.ensureEmbed(index)['description'] = _stringifyArgument(node, 0);
        return true;
      case 'color':
        final index = _parseEmbedIndex(node, 1);
        response.ensureEmbed(index)['color'] = _stringifyArgument(node, 0);
        return true;
      case 'footer':
        final index = _parseEmbedIndex(node, 2);
        final embed = response.ensureEmbed(index);
        final footer =
            (embed['footer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        footer['text'] = _stringifyArgument(node, 0);
        final iconUrl = _stringifyArgument(node, 1);
        if (iconUrl.isNotEmpty) {
          footer['icon_url'] = iconUrl;
        }
        embed['footer'] = footer;
        return true;
      case 'thumbnail':
        final index = _parseEmbedIndex(node, 1);
        response.ensureEmbed(index)['thumbnail'] = <String, dynamic>{
          'url': _stringifyArgument(node, 0),
        };
        return true;
      case 'image':
        final index = _parseEmbedIndex(node, 1);
        response.ensureEmbed(index)['image'] = <String, dynamic>{
          'url': _stringifyArgument(node, 0),
        };
        return true;
      case 'author':
        final index = _parseEmbedIndex(node, 3);
        final embed = response.ensureEmbed(index);
        final author =
            (embed['author'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        author['name'] = _stringifyArgument(node, 0);
        final authorIconUrl = _stringifyArgument(node, 1);
        final url = _stringifyArgument(node, 2);
        if (authorIconUrl.isNotEmpty) {
          author['icon_url'] = authorIconUrl;
        }
        if (url.isNotEmpty) {
          author['url'] = url;
        }
        embed['author'] = author;
        return true;
      case 'addfield':
        final inlineArg = _stringifyArgument(node, 2);
        final indexArg = _stringifyArgument(node, 3).trim();
        final field = <String, dynamic>{
          'name': _stringifyArgument(node, 0),
          'value': _stringifyArgument(node, 1),
          'inline': inlineArg.isEmpty ? 'no' : inlineArg,
        };
        final fields = response.ensureEmbedFields(0);
        final index = int.tryParse(indexArg);
        if (index != null && index >= 0 && index <= fields.length) {
          fields.insert(index, field);
        } else {
          fields.add(field);
        }
        return true;
      case 'addtimestamp':
        final timestamp = _stringifyArgument(node, 0);
        final index = _parseEmbedIndex(node, 1);
        response.ensureEmbed(index)['timestamp'] =
            timestamp.isEmpty ? 'now' : timestamp;
        return true;
      case 'authoricon':
        final index = _parseEmbedIndex(node, 1);
        final embed = response.ensureEmbed(index);
        final author =
            (embed['author'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        author['icon_url'] = _stringifyArgument(node, 0);
        embed['author'] = author;
        return true;
      case 'authorurl':
        final index = _parseEmbedIndex(node, 1);
        final embed = response.ensureEmbed(index);
        final author =
            (embed['author'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        author['url'] = _stringifyArgument(node, 0);
        embed['author'] = author;
        return true;
      case 'embeddedurl':
        final index = _parseEmbedIndex(node, 1);
        response.ensureEmbed(index)['url'] = _stringifyArgument(node, 0);
        return true;
      case 'footericon':
        final index = _parseEmbedIndex(node, 1);
        final embed = response.ensureEmbed(index);
        final footer =
            (embed['footer'] as Map<String, dynamic>?) ?? <String, dynamic>{};
        footer['icon_url'] = _stringifyArgument(node, 0);
        embed['footer'] = footer;
        return true;
      case 'addcontainer':
        final containerId = _stringifyArgument(node, 0);
        final containerColor = _stringifyArgument(node, 1);
        final containerSpoiler = _parseBooleanLike(_stringifyArgument(node, 2));
        response.addComponent(<String, dynamic>{
          'type': 'container',
          if (containerId.isNotEmpty) 'id': containerId,
          if (containerColor.isNotEmpty) 'accentColor': containerColor,
          if (containerSpoiler) 'spoiler': true,
        });
        return true;
      case 'addsection':
        final sectionId = _stringifyArgument(node, 0);
        response.addComponent(<String, dynamic>{
          'type': 'section',
          if (sectionId.isNotEmpty) 'id': sectionId,
        });
        return true;
      case 'addthumbnail':
        final thumbUrl = _stringifyArgument(node, 0);
        final thumbDesc = _stringifyArgument(node, 1);
        final thumbSpoiler = _parseBooleanLike(_stringifyArgument(node, 2));
        response.addComponent(<String, dynamic>{
          'type': 'thumbnail',
          'url': thumbUrl,
          if (thumbDesc.isNotEmpty) 'description': thumbDesc,
          if (thumbSpoiler) 'spoiler': true,
        });
        return true;
      case 'addmediagallery':
        final galleryId = _stringifyArgument(node, 0);
        response.addComponent(<String, dynamic>{
          'type': 'mediaGallery',
          if (galleryId.isNotEmpty) 'id': galleryId,
          'items': <Map<String, dynamic>>[],
        });
        return true;
      case 'addmediagalleryitem':
        final itemUrl = _stringifyArgument(node, 0);
        final itemDesc = _stringifyArgument(node, 1);
        final itemSpoiler = _parseBooleanLike(_stringifyArgument(node, 2));
        final galleryRef = _stringifyArgument(node, 3);
        final item = <String, dynamic>{
          'url': itemUrl,
          if (itemDesc.isNotEmpty) 'description': itemDesc,
          if (itemSpoiler) 'spoiler': true,
        };
        if (response.lastComponentType == 'mediaGallery') {
          (response.lastComponent!['items'] as List).add(item);
        } else {
          response.addComponent(<String, dynamic>{
            'type': 'mediaGallery',
            if (galleryRef.isNotEmpty) 'id': galleryRef,
            'items': [item],
          });
        }
        return true;
      case 'addactionrow':
        final actionRowId = _stringifyArgument(node, 0);
        response.addComponent(<String, dynamic>{
          'type': 'actionRow',
          if (actionRowId.isNotEmpty) 'id': actionRowId,
        });
        return true;
      case 'addbuttoncv2':
        final interactionIdOrUrl = _stringifyArgument(node, 0);
        final label = _stringifyArgument(node, 1);
        final style = _stringifyArgument(node, 2).trim().toLowerCase();
        final disabled = _parseBooleanLike(_stringifyArgument(node, 3));
        final emoji = _stringifyArgument(node, 4);
        response.addButton(
          newRow: false,
          interactionIdOrUrl: interactionIdOrUrl,
          label: label,
          style: style.isEmpty ? 'primary' : style,
          disabled: disabled,
          emoji: emoji,
        );
        return true;
      case 'addmentionableselect':
        final customId = _stringifyArgument(node, 0);
        final placeholder = _stringifyArgument(node, 1);
        final minValues = _stringifyArgument(node, 2);
        final maxValues = _stringifyArgument(node, 3);
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        response._currentSelectMenuId = customId;
        response.addComponent(<String, dynamic>{
          'type': 'selectMenu',
          'menuType': 'mentionable',
          'customId': customId,
          if (placeholder.isNotEmpty) 'placeholder': placeholder,
          if (minValues.isNotEmpty) 'minValues': int.tryParse(minValues) ?? 1,
          if (maxValues.isNotEmpty) 'maxValues': int.tryParse(maxValues) ?? 1,
          'disabled': disabled,
        });
        return true;
      case 'adduserselect':
        final customId = _stringifyArgument(node, 0);
        final placeholder = _stringifyArgument(node, 1);
        final minValues = _stringifyArgument(node, 2);
        final maxValues = _stringifyArgument(node, 3);
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        response._currentSelectMenuId = customId;
        response.addComponent(<String, dynamic>{
          'type': 'selectMenu',
          'menuType': 'user',
          'customId': customId,
          if (placeholder.isNotEmpty) 'placeholder': placeholder,
          if (minValues.isNotEmpty) 'minValues': int.tryParse(minValues) ?? 1,
          if (maxValues.isNotEmpty) 'maxValues': int.tryParse(maxValues) ?? 1,
          'disabled': disabled,
        });
        return true;
      case 'addroleselect':
        final customId = _stringifyArgument(node, 0);
        final placeholder = _stringifyArgument(node, 1);
        final minValues = _stringifyArgument(node, 2);
        final maxValues = _stringifyArgument(node, 3);
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        response._currentSelectMenuId = customId;
        response.addComponent(<String, dynamic>{
          'type': 'selectMenu',
          'menuType': 'role',
          'customId': customId,
          if (placeholder.isNotEmpty) 'placeholder': placeholder,
          if (minValues.isNotEmpty) 'minValues': int.tryParse(minValues) ?? 1,
          if (maxValues.isNotEmpty) 'maxValues': int.tryParse(maxValues) ?? 1,
          'disabled': disabled,
        });
        return true;
      case 'addchannelselect':
        final customId = _stringifyArgument(node, 0);
        final placeholder = _stringifyArgument(node, 1);
        final minValues = _stringifyArgument(node, 2);
        final maxValues = _stringifyArgument(node, 3);
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        final channelTypes = _stringifyArgument(node, 6);
        response._currentSelectMenuId = customId;
        response.addComponent(<String, dynamic>{
          'type': 'selectMenu',
          'menuType': 'channel',
          'customId': customId,
          if (placeholder.isNotEmpty) 'placeholder': placeholder,
          if (minValues.isNotEmpty) 'minValues': int.tryParse(minValues) ?? 1,
          if (maxValues.isNotEmpty) 'maxValues': int.tryParse(maxValues) ?? 1,
          'disabled': disabled,
          if (channelTypes.isNotEmpty) 'channelTypes': channelTypes,
        });
        return true;
      case 'addstringselect':
        final customId = _stringifyArgument(node, 0);
        final placeholder = _stringifyArgument(node, 1);
        final minValues = _stringifyArgument(node, 2);
        final maxValues = _stringifyArgument(node, 3);
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        response._currentSelectMenuId = customId;
        response.addComponent(<String, dynamic>{
          'type': 'selectMenu',
          'menuType': 'string',
          'customId': customId,
          if (placeholder.isNotEmpty) 'placeholder': placeholder,
          if (minValues.isNotEmpty) 'minValues': int.tryParse(minValues) ?? 1,
          if (maxValues.isNotEmpty) 'maxValues': int.tryParse(maxValues) ?? 1,
          'disabled': disabled,
        });
        return true;
      case 'addstringselectoption':
        final soLabel = _stringifyArgument(node, 0);
        final soValue = _stringifyArgument(node, 1);
        final soDescription = _stringifyArgument(node, 2);
        final soEmoji = _stringifyArgument(node, 3);
        final soDefault = _parseBooleanLike(_stringifyArgument(node, 4));
        final soMenuId = _stringifyArgument(node, 5);
        final resolvedMenuId =
            soMenuId.isNotEmpty
                ? soMenuId
                : (response._currentSelectMenuId ?? '');
        response.addSelectMenuOption(
          menuId: resolvedMenuId,
          label: soLabel,
          value: soValue,
          description: soDescription,
          isDefault: soDefault,
          emoji: soEmoji,
        );
        return true;
      case 'addbutton':
        final newRow = _parseBooleanLike(_stringifyArgument(node, 0));
        final interactionIdOrUrl = _stringifyArgument(node, 1);
        final label = _stringifyArgument(node, 2);
        final style = _stringifyArgument(node, 3).trim().toLowerCase();
        final disabled = _parseBooleanLike(_stringifyArgument(node, 4));
        final emoji = _stringifyArgument(node, 5);
        final messageId = _stringifyArgument(node, 6);
        response.addButton(
          newRow: newRow,
          interactionIdOrUrl: interactionIdOrUrl,
          label: label,
          style: style.isEmpty ? 'primary' : style,
          disabled: disabled,
          emoji: emoji,
          messageId: messageId,
        );
        return true;
      case 'addselectmenuoption':
        final menuId = _stringifyArgument(node, 0);
        final resolvedMenuId =
            menuId.isNotEmpty ? menuId : (response._currentSelectMenuId ?? '');
        final label = _stringifyArgument(node, 1);
        final value = _stringifyArgument(node, 2);
        final description = _stringifyArgument(node, 3);
        final isDefault = _parseBooleanLike(_stringifyArgument(node, 4));
        final emoji = _stringifyArgument(node, 5);
        response.addSelectMenuOption(
          menuId: resolvedMenuId,
          label: label,
          value: value,
          description: description,
          isDefault: isDefault,
          emoji: emoji,
        );
        return true;
      case 'newselectmenu':
        final customId = _stringifyArgument(node, 0);
        final minValues = _stringifyArgument(node, 1);
        final maxValues = _stringifyArgument(node, 2);
        final placeholder = _stringifyArgument(node, 3);
        response._currentSelectMenuId = customId;
        response.addComponent(<String, dynamic>{
          'type': 'selectMenu',
          'customId': customId,
          if (placeholder.isNotEmpty) 'placeholder': placeholder,
          if (minValues.isNotEmpty) 'minValues': int.tryParse(minValues) ?? 1,
          if (maxValues.isNotEmpty) 'maxValues': int.tryParse(maxValues) ?? 1,
        });
        return true;
      case 'editselectmenu':
        final editMenuId = _stringifyArgument(node, 0);
        final editMenuMinStr = _stringifyArgument(node, 1);
        final editMenuMaxStr = _stringifyArgument(node, 2);
        final editMenuPlaceholder = _stringifyArgument(node, 3);
        response.editSelectMenu(
          customId: editMenuId,
          placeholder: editMenuPlaceholder.isEmpty ? null : editMenuPlaceholder,
          minValues:
              editMenuMinStr.isEmpty ? null : int.tryParse(editMenuMinStr),
          maxValues:
              editMenuMaxStr.isEmpty ? null : int.tryParse(editMenuMaxStr),
        );
        return true;
      case 'editselectmenuoption':
        final editOptMenuId = _stringifyArgument(node, 0);
        final editOptLabel = _stringifyArgument(node, 1);
        final editOptValue = _stringifyArgument(node, 2);
        final editOptDesc = _stringifyArgument(node, 3);
        final editOptDefaultStr = _stringifyArgument(node, 4);
        final editOptEmoji = _stringifyArgument(node, 5);
        response.editSelectMenuOption(
          menuId: editOptMenuId,
          index: 1,
          label: editOptLabel.isEmpty ? null : editOptLabel,
          value: editOptValue.isEmpty ? null : editOptValue,
          description: editOptDesc,
          isDefault:
              editOptDefaultStr.isEmpty
                  ? null
                  : _parseBooleanLike(editOptDefaultStr),
          emoji: editOptEmoji,
        );
        return true;
      case 'editbutton':
        final editBtnIdOrUrl = _stringifyArgument(node, 0);
        final editBtnLabel = _stringifyArgument(node, 1);
        final editBtnStyle = _stringifyArgument(node, 2).trim().toLowerCase();
        final editBtnDisabledStr = _stringifyArgument(node, 3);
        final editBtnEmoji = _stringifyArgument(node, 4);
        response.editButtonByIdOrUrl(
          buttonIdOrUrl: editBtnIdOrUrl,
          label: editBtnLabel.isEmpty ? null : editBtnLabel,
          style: editBtnStyle.isEmpty ? null : editBtnStyle,
          disabled:
              editBtnDisabledStr.isEmpty
                  ? null
                  : _parseBooleanLike(editBtnDisabledStr),
          emoji: editBtnEmoji.isEmpty ? null : editBtnEmoji,
        );
        return true;
      case 'removeallcomponents':
        response.clearComponents();
        return true;
      case 'removebuttons':
        response.clearButtons();
        return true;
      case 'removecomponent':
        final customId = _stringifyArgument(node, 0);
        response.removeComponent(customId);
        return true;
      case 'addseparator':
        final sepDivider = _stringifyArgument(node, 0);
        final sepSpacing = _stringifyArgument(node, 1);
        response.addComponent(<String, dynamic>{
          'type': 'separator',
          'divider': _parseBooleanLike(sepDivider.isEmpty ? 'yes' : sepDivider),
          if (sepSpacing.isNotEmpty) 'spacing': sepSpacing,
        });
        return true;
      case 'addtextdisplay':
        response.addComponent(<String, dynamic>{
          'type': 'textDisplay',
          'content': _stringifyArgument(node, 0),
        });
        return true;
      case 'reply':
        if (node.arguments.isEmpty) {
          // $reply (0 args) -> reply to the author's message.
          response.markAsReply();
          return true;
        }
        if (node.arguments.length == 2) {
          // $reply[channelId;messageId] -> reply to a specific message.
          final channelId = _stringifyArgument(node, 0).trim();
          final messageId = _stringifyArgument(node, 1).trim();
          if (channelId.isNotEmpty && messageId.isNotEmpty) {
            response.markAsReply(channelId: channelId, messageId: messageId);
            return true;
          }
        }
        return false;
      case 'ephemeral':
        response._ephemeral = true;
        return true;
      case 'allowmention':
        response._allowMentions = true;
        return true;
      case 'allowusermentions':
        final userIds = <String>[];
        for (var i = 0; i < node.arguments.length; i++) {
          final id = _stringifyArgument(node, i).trim();
          if (id.isNotEmpty) userIds.add(id);
        }
        response._allowedUsers = userIds;
        return true;
      case 'tts':
        response._tts = true;
        return true;
      case 'removelinks':
        response._removeLinks = true;
        return true;
      case 'allowrolementions':
        final roleIds = <String>[];
        for (var i = 0; i < node.arguments.length; i++) {
          final id = _stringifyArgument(node, i).trim();
          if (id.isNotEmpty) roleIds.add(id);
        }
        response._allowedRoles = roleIds;
        return true;
      case 'suppresserrors':
        _suppressErrors = true;
        return true;
      case 'embedsuppresserrors':
        _suppressErrors = true;
        return true;
      default:
        return false;
    }
  }

  Action? _transpileStandaloneFunction(
    BdfdFunctionCallAst node, {
    _PendingResponse? pendingResponse,
  }) {
    switch (node.normalizedName) {
      case 'if':
        return _transpileIf(node);
      case 'onlyif':
        return _transpileOnlyIf(node);
      case 'onlyforusers':
        return _transpileOnlyForUsers(node);
      case 'onlyforchannels':
        return _transpileOnlyForChannels(node);
      case 'onlyforroles':
        return _transpileOnlyForRoles(node);
      case 'onlyforids':
        return _transpileOnlyForIds(node);
      case 'onlyforroleids':
        return _transpileOnlyForRoleIds(node);
      case 'onlyforservers':
        return _transpileOnlyForServers(node);
      case 'onlyforcategories':
        return _transpileOnlyForCategories(node);
      case 'ignorechannels':
        return _transpileIgnoreChannels(node);
      case 'onlynsfw':
        return _transpileOnlyNsfw(node);
      case 'onlyadmin':
        return _transpileOnlyAdmin(node);
      case 'onlyperms':
        return _transpileOnlyPerms(node, bot: false);
      case 'onlybotperms':
        return _transpileOnlyPerms(node, bot: true);
      case 'onlybotchannelperms':
        return _transpileOnlyBotChannelPerms(node);
      case 'checkuserperms':
      case 'checkusersperms':
        return _transpileCheckUserPerms(node);
      case 'onlyifmessagecontains':
        return _transpileOnlyIfMessageContains(node);
      case 'stop':
        return _buildForcedStopAction();
      case 'sendmessage':
        final content = _stringifyArgument(node, 0);
        return _buildRespondWithMessageAction(content: content);

      case 'channelsendmessage':
        return _buildChannelSendMessageAction(node);
      case 'changeusername':
        return _buildChangeUsernameAction(node);
      case 'changeusernamewithid':
        return _buildChangeUsernameWithIdAction(node);
      case 'startthread':
        return _buildStartThreadAction(node);
      case 'editthread':
        return _buildEditThreadAction(node);
      case 'threadaddmember':
        return _buildThreadMemberAction(node, add: true);
      case 'threadremovemember':
        return _buildThreadMemberAction(node, add: false);
      case 'httpaddheader':
        _storePendingHttpHeader(node);
        return null;
      case 'httpget':
        return _buildHttpRequestAction(method: 'GET', node: node);
      case 'httppost':
        return _buildHttpRequestAction(method: 'POST', node: node);
      case 'httpput':
        return _buildHttpRequestAction(method: 'PUT', node: node);
      case 'httpdelete':
        return _buildHttpRequestAction(method: 'DELETE', node: node);
      case 'httppatch':
        return _buildHttpRequestAction(method: 'PATCH', node: node);
      case 'setuservar':
        return _buildSetScopedVariableAction(scope: 'user', node: node);
      case 'setservervar':
      case 'setguildvar':
        return _buildSetScopedVariableAction(scope: 'guild', node: node);
      case 'setchannelvar':
        return _buildSetScopedVariableAction(scope: 'channel', node: node);
      case 'setmembervar':
      case 'setguildmembervar':
        return _buildSetScopedVariableAction(scope: 'guildMember', node: node);
      case 'setmessagevar':
        return _buildSetScopedVariableAction(scope: 'message', node: node);
      case 'var':
        if (node.arguments.length >= 2) {
          return _buildSetTemporaryVariableAction(node);
        }
        return null;
      case 'awaitfunc':
        return _buildAwaitFuncAction(node);
      case 'jsonparse':
        // _jsonParse internally flushes any previous deferred JSON block.
        // We capture and return it so it gets emitted as an action.
        final previousBlock = _flushDeferredJson();
        _jsonParse(node);
        return previousBlock;
      case 'jsonset':
        _jsonSet(node, forceString: false);
        return null;
      case 'jsonsetstring':
        _jsonSet(node, forceString: true);
        return null;
      case 'jsonunset':
        _jsonUnset(node);
        return null;
      case 'jsonclear':
        _jsonClear();
        return null;
      case 'jsonarray':
        _jsonArray(node);
        return null;
      case 'jsonarrayappend':
        _jsonArrayAppend(node);
        return null;
      case 'jsonarrayunshift':
        _jsonArrayUnshift(node);
        return null;
      case 'jsonarraysort':
        _jsonArraySort(node);
        return null;
      case 'jsonarrayreverse':
        _jsonArrayReverse(node);
        return null;
      // Logging
      case 'log':
        final logMessage = _stringifyArgument(node, 0);
        final logLevel = _stringifyArgument(node, 1).toLowerCase();
        return Action(
          type: BotCreatorActionType.log,
          payload: <String, dynamic>{
            'message': logMessage,
            if (logLevel.isNotEmpty) 'level': logLevel,
          },
        );
      case 'suppresserrorlogging':
        // No-op flag – absorbed at transpile time.
        return null;
      // Moderation actions
      case 'registerguildcommands':
        return _buildRegisterGuildCommandsAction(node);
      case 'unregisterguildcommands':
        return _buildUnregisterGuildCommandsAction(node);
      case 'ban':
        return _buildBanAction(node);
      case 'banid':
        return _buildBanIdAction(node);
      case 'unban':
        return _buildUnbanAction(node);
      case 'unbanid':
        return _buildUnbanIdAction(node);
      case 'kick':
        return _buildKickAction(node);
      case 'kickmention':
        return _buildKickMentionAction(node);
      case 'timeout':
        return _buildTimeoutAction(node);
      case 'mute':
        return _buildMuteAction(node);
      case 'untimeout':
        return _buildUntimeoutAction(node);
      case 'unmute':
        return _buildUnmuteAction(node);
      case 'clear':
        return _buildClearAction(node);
      // Role actions
      case 'giverole':
        return _buildGiveRoleAction(node);
      case 'giveroles':
        final giveRolesActions = _buildMultiRoleAction(node, give: true);
        if (giveRolesActions.isNotEmpty) {
          _deferredInlineActions.addAll(giveRolesActions);
        }
        return null;
      case 'rolegrant':
        final roleGrantActions = _buildRoleGrantAction(node);
        if (roleGrantActions.isNotEmpty) {
          _deferredInlineActions.addAll(roleGrantActions);
        }
        return null;
      case 'takerole':
        return _buildTakeRoleAction(node);
      case 'takeroles':
        final takeRolesActions = _buildMultiRoleAction(node, give: false);
        if (takeRolesActions.isNotEmpty) {
          _deferredInlineActions.addAll(takeRolesActions);
        }
        return null;
      case 'createrole':
        return _buildCreateRoleAction(node);
      case 'deleterole':
        return _buildDeleteRoleAction(node);
      case 'colorrole':
        return _buildColorRoleAction(node);
      case 'modifyrole':
        return _buildModifyRoleAction(node);
      case 'modifyroleperms':
        return _buildModifyRolePermsAction(node);
      case 'setuserroles':
        return _buildSetUserRolesAction(node);
      // Message actions
      case 'deletemessage':
        return _buildDeleteMessageAction(node);
      case 'deletein':
        return _buildDeleteInAction(node);
      case 'dm':
        return _buildDmAction(node);
      case 'editmessage':
        return _buildEditMessageAction(node);
      case 'editin':
        return _buildEditInAction(node);
      case 'editembedin':
        return _buildEditEmbedInAction(node);
      case 'pinmessage':
        return _buildPinMessageAction(node);
      case 'unpinmessage':
        return _buildUnpinMessageAction(node);
      case 'publishmessage':
        return _buildPublishMessageAction(node);
      case 'replyin':
        return _buildReplyInAction(node);
      case 'sendembedmessage':
        return _buildSendEmbedMessageAction(node);
      case 'usechannel':
        return _buildUseChannelAction(node);
      // Channel actions
      case 'createchannel':
        return _buildCreateChannelAction(node);
      case 'deletechannels':
      case 'deletechannelsbyname':
        return _buildDeleteChannelsAction(node);
      case 'modifychannel':
        return _buildModifyChannelAction(node);
      case 'editchannelperms':
        return _buildEditChannelPermsAction(node);
      case 'modifychannelperms':
        return _buildModifyChannelPermsAction(node);
      case 'slowmode':
        return _buildSlowmodeAction(node);
      case 'wait':
        return _buildWaitAction(node);
      case 'deletecommand':
        return _buildDeleteTriggerAction(node);
      case 'setnickname':
        return _buildSetNicknameAction(node);
      // Reaction actions
      case 'addreactions':
        return _buildAddReactionsAction(node);
      case 'addcmdreactions':
        return _buildAddCmdReactionsAction(node);
      case 'addmessagereactions':
        return _buildAddMessageReactionsAction(node);
      case 'clearreactions':
        return _buildClearReactionsAction(node);
      // Emoji actions
      case 'addemoji':
        return _buildAddEmojiAction(node);
      case 'removeemoji':
        return _buildRemoveEmojiAction(node);
      // Webhook actions
      case 'webhooksend':
        return _buildWebhookSendAction(node);
      case 'webhookcreate':
        return _buildWebhookCreateAction(node);
      case 'webhookdelete':
        return _buildWebhookDeleteAction(node);
      // Modal action
      case 'newmodal':
        return _buildNewModalAction(node);
      case 'addtextinput':
        _pendingModalInputs.add(<String, dynamic>{
          'customId': _stringifyArgument(node, 0),
          'style': _stringifyArgument(node, 1),
          'label': _stringifyArgument(node, 2),
          if (_stringifyArgument(node, 3).isNotEmpty)
            'minLength': int.tryParse(_stringifyArgument(node, 3)) ?? 0,
          if (_stringifyArgument(node, 4).isNotEmpty)
            'maxLength': int.tryParse(_stringifyArgument(node, 4)) ?? 4000,
          'required': _parseBooleanLike(
            _stringifyArgument(node, 5).isEmpty
                ? 'yes'
                : _stringifyArgument(node, 5),
          ),
          if (_stringifyArgument(node, 6).isNotEmpty)
            'value': _stringifyArgument(node, 6),
          if (_stringifyArgument(node, 7).isNotEmpty)
            'placeholder': _stringifyArgument(node, 7),
        });
        return null;
      // Defer action
      case 'defer':
        return Action(
          type: BotCreatorActionType.respondWithMessage,
          payload: const <String, dynamic>{
            'content': '',
            'deferred': true,
            'ephemeral': false,
          },
        );
      // Cooldown actions
      case 'cooldown':
        return _buildCooldownAction(node, scope: 'user');
      case 'globalcooldown':
        return _buildCooldownAction(node, scope: 'global');
      case 'servercooldown':
        return _buildCooldownAction(node, scope: 'guild');
      case 'changecooldowntime':
        return _buildChangeCooldownTimeAction(node);
      // Variable operations
      case 'setvar':
        // BDFD wiki: $setVar[Variable name;New value;(User ID)]
        final svUserId =
            node.arguments.length > 2 ? _stringifyArgument(node, 2).trim() : '';
        return _buildSetScopedVariableAction(
          scope: svUserId.isNotEmpty ? 'user' : 'global',
          node: node,
        );
      case 'resetuservar':
        return _buildResetScopedVariableAction(scope: 'user', node: node);
      case 'resetservervar':
      case 'resetguildvar':
        return _buildResetScopedVariableAction(scope: 'guild', node: node);
      case 'resetchannelvar':
        return _buildResetScopedVariableAction(scope: 'channel', node: node);
      case 'resetmembervar':
      case 'resetguildmembervar':
        return _buildResetScopedVariableAction(
          scope: 'guildMember',
          node: node,
        );
      // Text split state
      case 'textsplit':
        _textSplitState(node);
        return null;
      // Blacklist guards
      case 'blacklistids':
        return _transpileBlacklistIds(node);
      case 'blacklistroles':
        return _transpileBlacklistRoles(node);
      case 'blacklistrolesids':
      case 'blacklistroleids':
        return _transpileBlacklistRoleIds(node);
      case 'blacklistservers':
        return _transpileBlacklistServers(node);
      case 'blacklistusers':
        return _transpileBlacklistUsers(node);
      // Bot actions
      case 'botleave':
        return Action(
          type: BotCreatorActionType.leaveGuild,
          payload: const <String, dynamic>{},
        );
      case 'bottyping':
        return Action(
          type: BotCreatorActionType.sendMessage,
          payload: const <String, dynamic>{
            'targetType': 'typing',
            'channelId': '((channel.id))',
          },
        );
      // Close/new ticket scaffolding
      case 'closeticket':
        // BDFD wiki: $closeTicket[Error message] — error message is sent when
        // the channel is not a ticket.
        final ctErrorMsg = _stringifyArgument(node, 0).trim();
        return Action(
          type: BotCreatorActionType.updateChannel,
          payload: <String, dynamic>{
            'channelId': '((channel.id))',
            'archived': true,
            'locked': true,
            if (ctErrorMsg.isNotEmpty) 'errorMessage': ctErrorMsg,
          },
        );
      case 'newticket':
        return _buildNewTicketAction(node);
      // Args check
      case 'argscheck':
        return _buildArgsCheckAction(node);
      // Workflow call
      case 'callworkflow':
        return _buildCallWorkflowAction(node);
      // Dynamic eval
      case 'eval':
        return _buildEvalAction(node);
      // Enabled guard
      case 'enabled':
        return _transpileEnabled(node);
      // Debug profiling
      case 'debug':
        return _buildDebugAction(node);
      default:
        if (pendingResponse != null && node.arguments.isEmpty) {
          // Unknown no-arg tokens (for example `$test`) are treated as
          // plain text literals to match BDFD fallback behavior.
          pendingResponse.appendContent(node.name);
          return null;
        }
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Unsupported BDFD function for action transpilation: ${node.name}.',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        return null;
    }
  }

  Action _transpileIf(BdfdFunctionCallAst node) {
    final condition = _parseCondition(_stringifyArgument(node, 0), node);
    final conditionDeferredJson = _flushDeferredJson();
    if (conditionDeferredJson != null) {
      _enqueuePendingConditionAction(conditionDeferredJson);
    }

    final thenActions = _transpileBranchArgument(node, 1);
    final elseActions = _transpileBranchArgument(node, 2);

    return Action(
      type: BotCreatorActionType.ifBlock,
      payload: <String, dynamic>{
        ...condition.toPayload(prefix: 'condition.'),
        'thenActions': thenActions.map((action) => action.toJson()).toList(),
        'elseIfConditions': const <Map<String, dynamic>>[],
        'elseActions': elseActions.map((action) => action.toJson()).toList(),
      },
    );
  }

  Action _transpileOnlyIf(BdfdFunctionCallAst node) {
    final condition = _parseCondition(_stringifyArgument(node, 0), node);
    final conditionDeferredJson = _flushDeferredJson();
    if (conditionDeferredJson != null) {
      _enqueuePendingConditionAction(conditionDeferredJson);
    }

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(
        message: _stringifyArgument(node, 1),
      ),
    );
  }

  /// Transpiles `$enabled[Enabled;Error message]`.
  ///
  /// The command is allowed to proceed when the first argument resolves to a
  /// truthy value (`yes`, `true`, `1`).  When it resolves to a falsy value
  /// (`no`, `false`, `0`) execution is stopped with the optional error
  /// message from the second argument.
  Action? _transpileEnabled(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return null;
    }
    final enabledValue = _stringifyArgument(node, 0);
    final errorMessage = _stringifyArgument(node, 1);

    // Guard: NOT (value == 'no' OR value == 'false' OR value == '0')
    // When the condition is satisfied (value is disabled), the else branch
    // fires, sending the error message and stopping execution.
    final condition = _ParsedCondition.logical(
      group: 'or',
      negate: true,
      conditions: <_ParsedCondition>[
        _ParsedCondition(left: enabledValue, operator: 'equals', right: 'no'),
        _ParsedCondition(
          left: enabledValue,
          operator: 'equals',
          right: 'false',
        ),
        _ParsedCondition(left: enabledValue, operator: 'equals', right: '0'),
      ],
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: errorMessage),
    );
  }

  Action? _transpileOnlyForUsers(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one username.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
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
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one user ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
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
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForChannels(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one channel ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((channel.id))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForRoles(BdfdFunctionCallAst node) {
    final guard = _extractGuardValuesAndMessage(node);
    if (guard.values.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one role name.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.values
          .map(
            (name) => _ParsedCondition.logical(
              group: 'or',
              conditions: <_ParsedCondition>[
                _ParsedCondition(
                  left: '((member.roles))',
                  operator: 'contains',
                  right: name,
                ),
                _ParsedCondition(
                  left: '((member.roleNames))',
                  operator: 'contains',
                  right: name,
                ),
              ],
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForRoleIds(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one role ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
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
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForServers(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one server ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
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
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileOnlyForCategories(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one category ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((channel.parentId))',
              operator: 'equals',
              right: id,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: guard.message),
    );
  }

  Action? _transpileIgnoreChannels(BdfdFunctionCallAst node) {
    final guard = _extractGuardIdsAndMessage(node);
    if (guard.ids.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one channel ID.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: guard.ids
          .map(
            (id) => _ParsedCondition(
              left: '((channel.id))',
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

  Action _transpileOnlyNsfw(BdfdFunctionCallAst node) {
    const condition = _ParsedCondition(
      left: '((channel.nsfw))',
      operator: 'equals',
      right: 'true',
    );
    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(
        message: _stringifyArgument(node, 0),
      ),
    );
  }

  Action _transpileOnlyAdmin(BdfdFunctionCallAst node) {
    final condition = _ParsedCondition.logical(
      group: 'or',
      conditions: const <_ParsedCondition>[
        _ParsedCondition(
          left: '((member.isAdmin))',
          operator: 'equals',
          right: 'true',
        ),
        _ParsedCondition(
          left: '((member.permissions))',
          operator: 'contains',
          right: 'administrator',
        ),
        _ParsedCondition(
          left: '((author.id))',
          operator: 'equals',
          right: '((guild.ownerId))',
        ),
      ],
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(
        message: _stringifyArgument(node, 0),
      ),
    );
  }

  Action? _transpileOnlyPerms(BdfdFunctionCallAst node, {required bool bot}) {
    final extracted = _extractPermissionGuardArgs(node);
    if (extracted.permissions.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final source = bot ? '((bot.permissions))' : '((member.permissions))';
    final condition = _ParsedCondition.logical(
      group: 'and',
      conditions: extracted.permissions
          .map(
            (permission) => _ParsedCondition(
              left: source,
              operator: 'contains',
              right: permission,
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: extracted.message),
    );
  }

  Action? _transpileOnlyBotChannelPerms(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final firstArgumentRaw = _stringifyArgument(node, 0).trim();
    final firstArgumentPermission = _normalizePermissionToken(firstArgumentRaw);
    final firstLooksLikePermission = _looksLikePermissionToken(
      firstArgumentPermission,
    );

    String channelId;
    int permissionsStartAt;
    if (firstLooksLikePermission) {
      channelId = '((channel.id))';
      permissionsStartAt = 0;
    } else {
      final normalizedChannel = _normalizeDiscordIdToken(firstArgumentRaw);
      channelId =
          normalizedChannel.isEmpty ? '((channel.id))' : normalizedChannel;
      permissionsStartAt = 1;
    }

    final extracted = _extractPermissionGuardArgs(
      node,
      startAt: permissionsStartAt,
    );
    if (extracted.permissions.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final conditions = <_ParsedCondition>[];
    if (channelId != '((channel.id))') {
      conditions.add(
        _ParsedCondition(
          left: '((channel.id))',
          operator: 'equals',
          right: channelId,
        ),
      );
    }
    conditions.addAll(
      extracted.permissions.map(
        (permission) => _ParsedCondition(
          left: '((bot.permissions))',
          operator: 'contains',
          right: permission,
        ),
      ),
    );

    final condition = _ParsedCondition.logical(
      group: 'and',
      conditions: conditions,
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: extracted.message),
    );
  }

  Action? _transpileCheckUserPerms(BdfdFunctionCallAst node) {
    final parsed = _buildCheckUserPermsCondition(node);
    if (parsed == null) {
      return null;
    }

    return _buildGuardIfAction(
      condition: parsed.condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: parsed.message),
    );
  }

  _CheckUserPermsParsed? _buildCheckUserPermsCondition(
    BdfdFunctionCallAst node,
  ) {
    final userId = _normalizeDiscordIdToken(_stringifyArgument(node, 0));
    if (userId.isEmpty) {
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

    final extracted = _extractPermissionGuardArgs(node, startAt: 1);
    if (extracted.permissions.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one permission value.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final selfMemberBranch = _ParsedCondition.logical(
      group: 'and',
      conditions: <_ParsedCondition>[
        _ParsedCondition(
          left: '((author.id))',
          operator: 'equals',
          right: userId,
        ),
        ...extracted.permissions.map(
          (permission) => _ParsedCondition(
            left: '((member.permissions))',
            operator: 'contains',
            right: permission,
          ),
        ),
      ],
    );

    final byIdBranch = _ParsedCondition.logical(
      group: 'and',
      conditions: extracted.permissions
          .map(
            (permission) => _ParsedCondition(
              left: 'permissions.byId.$userId',
              operator: 'contains',
              right: permission,
            ),
          )
          .toList(growable: false),
    );

    final ownerBranch = _ParsedCondition(
      left: userId,
      operator: 'equals',
      right: '((guild.ownerId))',
    );

    return _CheckUserPermsParsed(
      condition: _ParsedCondition.logical(
        group: 'or',
        conditions: <_ParsedCondition>[
          selfMemberBranch,
          byIdBranch,
          ownerBranch,
        ],
      ),
      message: extracted.message,
    );
  }

  Action? _transpileOnlyIfMessageContains(BdfdFunctionCallAst node) {
    final parsed = _extractMessageContainsArgs(node);
    if (parsed.words.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one word to match.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final condition = _ParsedCondition.logical(
      group: 'and',
      conditions: parsed.words
          .map(
            (word) => _ParsedCondition(
              left: parsed.message,
              operator: 'matches',
              right: '(?i).*${RegExp.escape(word)}.*',
            ),
          )
          .toList(growable: false),
    );

    return _buildGuardIfAction(
      condition: condition,
      thenActions: const <Action>[],
      elseActions: _buildGuardFailureActions(message: parsed.errorMessage),
    );
  }

  _MessageContainsArgs _extractMessageContainsArgs(BdfdFunctionCallAst node) {
    final defaultMessage = '((message.content))';
    if (node.arguments.isEmpty) {
      return const _MessageContainsArgs(
        message: '((message.content))',
        words: <String>[],
        errorMessage: '',
      );
    }

    final rawMessage = _stringifyArgument(node, 0).trim();
    final message = rawMessage.isEmpty ? defaultMessage : rawMessage;

    if (node.arguments.length == 1) {
      return _MessageContainsArgs(
        message: message,
        words: const <String>[],
        errorMessage: '',
      );
    }

    final words = <String>[];
    var errorMessage = '';
    final hasErrorMessage =
        node.arguments.length >= 3 &&
        _looksLikeLikelyErrorMessage(_stringifyNodes(node.arguments.last));
    final wordsEndExclusive =
        hasErrorMessage ? node.arguments.length - 1 : node.arguments.length;

    for (var index = 1; index < wordsEndExclusive; index++) {
      final word = _stringifyArgument(node, index).trim();
      if (word.isNotEmpty) {
        words.add(word);
      }
    }

    if (hasErrorMessage) {
      errorMessage = _stringifyNodes(node.arguments.last).trim();
    }

    return _MessageContainsArgs(
      message: message,
      words: words,
      errorMessage: errorMessage,
    );
  }

  Action _buildGuardIfAction({
    required _ParsedCondition condition,
    required List<Action> thenActions,
    required List<Action> elseActions,
  }) {
    return Action(
      type: BotCreatorActionType.ifBlock,
      payload: <String, dynamic>{
        ...condition.toPayload(prefix: 'condition.'),
        'thenActions': thenActions.map((action) => action.toJson()).toList(),
        'elseIfConditions': const <Map<String, dynamic>>[],
        'elseActions': elseActions.map((action) => action.toJson()).toList(),
      },
    );
  }

  Action _buildForcedStopAction() {
    return Action(
      type: BotCreatorActionType.stop,
      payload: const <String, dynamic>{},
    );
  }

  List<Action> _buildGuardFailureActions({required String message}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return <Action>[_buildForcedStopAction()];
    }
    return <Action>[
      _buildRespondWithMessageAction(content: trimmed),
      _buildForcedStopAction(),
    ];
  }

  _GuardIdsAndMessage _extractGuardIdsAndMessage(BdfdFunctionCallAst node) {
    if (node.arguments.isEmpty) {
      return const _GuardIdsAndMessage(ids: <String>[], message: '');
    }

    if (node.arguments.length == 1) {
      return _GuardIdsAndMessage(
        ids: _extractIdArguments(node.arguments),
        message: '',
      );
    }

    final idArguments = node.arguments.sublist(0, node.arguments.length - 1);
    return _GuardIdsAndMessage(
      ids: _extractIdArguments(idArguments),
      message: _stringifyNodes(node.arguments.last),
    );
  }

  _GuardValuesAndMessage _extractGuardValuesAndMessage(
    BdfdFunctionCallAst node,
  ) {
    if (node.arguments.isEmpty) {
      return const _GuardValuesAndMessage(values: <String>[], message: '');
    }

    if (node.arguments.length == 1) {
      return _GuardValuesAndMessage(
        values: _extractValueArguments(node.arguments),
        message: '',
      );
    }

    final lastArgument = _stringifyNodes(node.arguments.last);
    final hasMessage = _looksLikeLikelyErrorMessage(lastArgument);
    final valueArguments =
        hasMessage
            ? node.arguments.sublist(0, node.arguments.length - 1)
            : node.arguments;
    return _GuardValuesAndMessage(
      values: _extractValueArguments(valueArguments),
      message: hasMessage ? lastArgument : '',
    );
  }

  List<String> _extractValueArguments(List<List<BdfdAstNode>> arguments) {
    final values = <String>{};
    for (final argument in arguments) {
      final raw = _stringifyNodes(argument).trim();
      if (raw.isNotEmpty) {
        values.add(raw);
      }
    }
    return values.toList(growable: false);
  }

  bool _looksLikeLikelyErrorMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return false;
    }

    if (trimmed.contains(RegExp(r'\s'))) {
      return true;
    }

    return trimmed.contains('!') ||
        trimmed.contains('?') ||
        trimmed.contains('`') ||
        trimmed.contains('❌') ||
        trimmed.contains('✅');
  }

  List<String> _extractIdArguments(List<List<BdfdAstNode>> arguments) {
    final ids = <String>{};
    for (final argument in arguments) {
      final raw = _stringifyNodes(argument);
      final parts = raw.split(RegExp(r'[\s,]+'));
      for (final part in parts) {
        final normalized = _normalizeDiscordIdToken(part);
        if (normalized.isNotEmpty) {
          ids.add(normalized);
        }
      }
    }
    return ids.toList(growable: false);
  }

  String _normalizeDiscordIdToken(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final digits =
        RegExp(r'\d+').allMatches(trimmed).map((m) => m.group(0)!).join();
    if (digits.isNotEmpty) {
      return digits;
    }
    return trimmed;
  }

  _PermissionGuardArgs _extractPermissionGuardArgs(
    BdfdFunctionCallAst node, {
    int startAt = 0,
  }) {
    final permissions = <String>[];
    var message = '';

    for (var index = startAt; index < node.arguments.length; index++) {
      final rawArgument = _stringifyNodes(node.arguments[index]).trim();
      if (rawArgument.isEmpty) {
        continue;
      }

      final parts = rawArgument
          .split(RegExp(r'[\s,]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);

      final isLastArgument = index == node.arguments.length - 1;
      final normalizedParts = parts
          .map(_normalizePermissionToken)
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
      final allPartsArePermissions =
          normalizedParts.isNotEmpty &&
          normalizedParts.every(_looksLikePermissionToken);

      if (isLastArgument && !allPartsArePermissions) {
        message = rawArgument;
        break;
      }

      permissions.addAll(normalizedParts);
    }

    return _PermissionGuardArgs(
      permissions: permissions.toSet().toList(growable: false),
      message: message,
    );
  }

  bool _looksLikePermissionToken(String normalized) {
    if (normalized.isEmpty) {
      return false;
    }
    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return true;
    }
    return _knownBdfdPermissionTokens.contains(normalized);
  }

  String _normalizePermissionToken(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    if (normalized.isEmpty) {
      return '';
    }
    return _permissionTokenAliases[normalized] ?? normalized;
  }

  List<Action> _transpileBranchArgument(BdfdFunctionCallAst node, int index) {
    if (index >= node.arguments.length) {
      return const <Action>[];
    }

    return _transpileNodesPreservingTempVariables(node.arguments[index]);
  }

  List<Action> _transpileNodesPreservingTempVariables(List<BdfdAstNode> nodes) {
    return _transpileNodes(nodes);
  }

  _ParsedCondition _parseCondition(
    String expression,
    BdfdFunctionCallAst node,
  ) {
    final trimmed = expression.trim();
    if (trimmed.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'IF condition cannot be empty.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return const _ParsedCondition(
        left: '',
        operator: 'isNotEmpty',
        right: '',
      );
    }

    final logical = _parseLogicalCondition(trimmed, node);
    if (logical != null) {
      return logical;
    }

    return _parseSimpleCondition(trimmed);
  }

  _ParsedCondition _parseSimpleCondition(String trimmed) {
    const symbolOperators = <String, String>{
      '>=': 'greaterOrEqual',
      '<=': 'lessOrEqual',
      '==': 'equals',
      '!=': 'notEquals',
      '>': 'greaterThan',
      '<': 'lessThan',
    };

    for (final entry in symbolOperators.entries) {
      final splitIndex = trimmed.indexOf(entry.key);
      if (splitIndex <= 0) {
        continue;
      }
      final left = trimmed.substring(0, splitIndex).trim();
      final right = trimmed.substring(splitIndex + entry.key.length).trim();
      return _ParsedCondition(left: left, operator: entry.value, right: right);
    }

    const wordOperators = <String, String>{
      ' notcontains ': 'notContains',
      ' contains ': 'contains',
      ' startswith ': 'startsWith',
      ' endswith ': 'endsWith',
    };

    final lowered = ' ${trimmed.toLowerCase()} ';
    for (final entry in wordOperators.entries) {
      final index = lowered.indexOf(entry.key);
      if (index < 0) {
        continue;
      }
      final left = trimmed.substring(0, index).trim();
      final right = trimmed.substring(index + entry.key.trim().length).trim();
      return _ParsedCondition(left: left, operator: entry.value, right: right);
    }

    return _ParsedCondition(left: trimmed, operator: 'isNotEmpty', right: '');
  }

  _ParsedCondition? _parseLogicalCondition(
    String expression,
    BdfdFunctionCallAst node,
  ) {
    final lowered = expression.toLowerCase();
    String? group;
    if (lowered.startsWith(r'$and[')) {
      group = 'and';
    } else if (lowered.startsWith(r'$or[')) {
      group = 'or';
    } else if (lowered.startsWith(r'((and[')) {
      group = 'and';
    } else if (lowered.startsWith(r'((or[')) {
      group = 'or';
    }

    if (group == null) {
      return null;
    }

    final bracketStart = expression.indexOf('[');
    if (bracketStart < 0) {
      return null;
    }

    final bracketEnd = _findMatchingBracketIndex(expression, bracketStart);
    if (bracketEnd < 0) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} has an invalid logical condition syntax.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    final body = expression.substring(bracketStart + 1, bracketEnd);
    var trailing = expression.substring(bracketEnd + 1).trim();
    if (trailing.startsWith('))')) {
      trailing = trailing.substring(2).trim();
    }
    final conditionStrings = _splitTopLevel(body, ';')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);

    if (conditionStrings.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${node.name} requires at least one condition.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }

    var negate = false;
    if (trailing.isNotEmpty) {
      final comparison = _parseBooleanComparison(trailing);
      if (comparison == null) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Unable to parse logical condition trailing comparator "$trailing"; assuming true.',
            severity: BdfdTranspileDiagnosticSeverity.warning,
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
      } else {
        negate = !comparison;
      }
    }

    final parsedConditions = conditionStrings
        .map(_parseSimpleCondition)
        .toList(growable: false);

    return _ParsedCondition.logical(
      group: group,
      conditions: parsedConditions,
      negate: negate,
    );
  }

  int _findMatchingBracketIndex(String value, int openIndex) {
    var depth = 0;
    for (var index = openIndex; index < value.length; index++) {
      final char = value[index];
      if (char == '[') {
        depth += 1;
      } else if (char == ']') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }
    return -1;
  }

  List<String> _splitTopLevel(String value, String separator) {
    final items = <String>[];
    var bracketDepth = 0;
    var lastStart = 0;

    for (var index = 0; index < value.length; index++) {
      final char = value[index];
      if (char == '[') {
        bracketDepth += 1;
        continue;
      }
      if (char == ']') {
        if (bracketDepth > 0) {
          bracketDepth -= 1;
        }
        continue;
      }
      if (char == separator && bracketDepth == 0) {
        items.add(value.substring(lastStart, index));
        lastStart = index + 1;
      }
    }

    items.add(value.substring(lastStart));
    return items;
  }

  bool? _parseBooleanComparison(String trailing) {
    final normalized = trailing.replaceAll(' ', '').toLowerCase();
    if (normalized.isEmpty) {
      return true;
    }

    if (normalized.startsWith('==')) {
      return _parseBooleanToken(normalized.substring(2));
    }
    if (normalized.startsWith('!=')) {
      final compared = _parseBooleanToken(normalized.substring(2));
      if (compared == null) {
        return null;
      }
      return !compared;
    }

    return null;
  }

  bool? _parseBooleanToken(String value) {
    switch (value) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'off':
        return false;
      default:
        return null;
    }
  }

  String _stringifyArgument(BdfdFunctionCallAst node, int index) {
    if (index >= node.arguments.length) {
      return '';
    }
    return _stringifyNodes(node.arguments[index]);
  }

  String _stringifyNodes(List<BdfdAstNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      if (node is BdfdTextAst) {
        buffer.write(node.value);
        continue;
      }

      if (node is BdfdFunctionCallAst) {
        final inlineReplacement = _stringifyInlineFunction(node);
        if (inlineReplacement != null) {
          buffer.write(inlineReplacement);
          continue;
        }

        if (_isInlineOnlyNode(node)) {
          continue;
        }

        final rebuilt = _rebuildFunctionSource(node);
        buffer.write(rebuilt);
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Nested BDFD function ${node.name} was preserved as raw text in this transpilation pass.',
            severity: BdfdTranspileDiagnosticSeverity.warning,
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
      }
    }
    return buffer.toString();
  }

  int _parseEmbedIndex(BdfdFunctionCallAst node, int parameterIndex) {
    if (parameterIndex >= node.arguments.length) {
      return 0;
    }
    final arg = _stringifyArgument(node, parameterIndex).trim();
    return int.tryParse(arg) ?? 0;
  }
}
