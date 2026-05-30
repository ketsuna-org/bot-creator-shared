part of '../bdfd_ast_transpiler.dart';

extension _BdfdAstTranspilationScopeInlineRuntime
    on _BdfdAstTranspilationScope {
  String? _stringifyInlineFunction(BdfdFunctionCallAst node) {
    // Runtime loop variable placeholders (e.g. $i → ((_loop.var.i))).
    if (_runtimeLoopVarNames != null &&
        _loopDepth > 0 &&
        node.arguments.isEmpty) {
      final name = node.normalizedName;
      if (_runtimeLoopVarNames!.contains(name)) {
        return '((_loop.var.$name))';
      }
      if (name == 'i' || name == 'loopindex' || name == 'loopiteration') {
        return '((_loop.index))';
      }
      if (name == 'loopcount') {
        return '((_loop.count))';
      }
    }
    // C-style loop variables take precedence (e.g. $i, $j in a for loop).
    if (_loopDepth > 0 && node.arguments.isEmpty) {
      final loopVar = _loopVariables[node.normalizedName];
      if (loopVar != null) return loopVar.toString();
    }
    switch (node.normalizedName) {
      case 'startthread':
        final action = _buildStartThreadAction(node);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return _shouldReturnStartThreadId(node) ? '((thread.lastId))' : '';
      case 'editthread':
        final action = _buildEditThreadAction(node);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return '';
      case 'threadaddmember':
        final action = _buildThreadMemberAction(node, add: true);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return '';
      case 'threadremovemember':
        final action = _buildThreadMemberAction(node, add: false);
        if (action != null) {
          _deferredInlineActions.add(action);
        }
        return '';
      case 'checkuserperms':
      case 'checkusersperms':
        return _inlineCheckUserPerms(node);
      case 'message':
        return _inlineMessageArgument(node);
      case 'args':
        return _inlineArgsArgument(node);
      case 'i':
      case 'loopindex':
      case 'loopiteration':
        return _loopDepth > 0 ? _loopIterationIndex.toString() : '0';
      case 'loopcount':
        return _loopDepth > 0 ? (_loopIterationIndex + 1).toString() : '0';
      case 'mentionedchannels':
        return _inlineMentionedChannels(node);
      // ── Select menu interaction results ──
      case 'getmentionableselectuserid':
        final pos = _stringifyArgument(node, 0).trim();
        return '((interaction.mentionableSelect.userId${pos.isNotEmpty ? '[$pos]' : ''}))';
      case 'getmentionableselectuserids':
        final sep = _stringifyArgument(node, 0).trim();
        return '((interaction.mentionableSelect.userIds${sep.isNotEmpty ? '[$sep]' : ''}))';
      case 'getuserselectuserid':
        final pos = _stringifyArgument(node, 0).trim();
        return '((interaction.userSelect.userId${pos.isNotEmpty ? '[$pos]' : ''}))';
      case 'getuserselectuserids':
        final sep = _stringifyArgument(node, 0).trim();
        return '((interaction.userSelect.userIds${sep.isNotEmpty ? '[$sep]' : ''}))';
      case 'getroleselectroleid':
        final pos = _stringifyArgument(node, 0).trim();
        return '((interaction.roleSelect.roleId${pos.isNotEmpty ? '[$pos]' : ''}))';
      case 'getroleselectroleids':
        final sep = _stringifyArgument(node, 0).trim();
        return '((interaction.roleSelect.roleIds${sep.isNotEmpty ? '[$sep]' : ''}))';
      case 'getchannelselectchannelid':
        final pos = _stringifyArgument(node, 0).trim();
        return '((interaction.channelSelect.channelId${pos.isNotEmpty ? '[$pos]' : ''}))';
      case 'getchannelselectchannelids':
        final sep = _stringifyArgument(node, 0).trim();
        final limit = _stringifyArgument(node, 1).trim();
        return '((interaction.channelSelect.channelIds${sep.isNotEmpty ? '[$sep${limit.isNotEmpty ? ';$limit' : ''}]' : ''}))';
      case 'getstringselectvalue':
        final pos = _stringifyArgument(node, 0).trim();
        return '((interaction.stringSelect.value${pos.isNotEmpty ? '[$pos]' : ''}))';
      case 'getstringselectvalues':
        final sep = _stringifyArgument(node, 0).trim();
        final limit = _stringifyArgument(node, 1).trim();
        return '((interaction.stringSelect.values${sep.isNotEmpty ? '[$sep${limit.isNotEmpty ? ';$limit' : ''}]' : ''}))';
      case 'user':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '<@$userId>';
          }
        }
        return _inlineRuntimeVariables['user'];
      case 'username':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].username))';
          }
        }
        return _inlineRuntimeVariables['username'];
      case 'nickname':
      case 'membernick':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((member[$userId].nick|member[$userId].displayName|user[$userId].displayName|user[$userId].username))';
          }
        }
        return _inlineRuntimeVariables[node.normalizedName];
      case 'displayname':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((member[$userId].displayName|user[$userId].displayName))';
          }
        }
        return _inlineRuntimeVariables['displayname'];
      case 'isadmin':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((member[$userId].isAdmin))';
          }
        }
        return _inlineRuntimeVariables['isadmin'];
      case 'isbooster':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((member[$userId].isBooster))';
          }
        }
        return _inlineRuntimeVariables['isbooster'];
      case 'userexists':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].exists))';
          }
        }
        return _inlineRuntimeVariables['userexists'];
      case 'channelexists':
      case 'serverchannelexists':
        if (node.arguments.isNotEmpty) {
          final channelId = _stringifyArgument(node, 0).trim();
          if (channelId.isNotEmpty) {
            return '((channel[$channelId].exists))';
          }
        }
        return _inlineRuntimeVariables[node.normalizedName] ?? 'false';
      case 'guildexists':
      case 'serverexists':
        if (node.arguments.isNotEmpty) {
          final guildId = _stringifyArgument(node, 0).trim();
          if (guildId.isNotEmpty) {
            return '((guild[$guildId].exists))';
          }
        }
        return _inlineRuntimeVariables[node.normalizedName] ?? 'false';
      case 'memberscount':
      case 'allmemberscount':
        if (node.arguments.isNotEmpty) {
          final presence = _stringifyArgument(node, 0).trim().toLowerCase();
          if (presence.isNotEmpty) {
            return '((guild.${presence}Members))';
          }
        }
        return _inlineRuntimeVariables[node.normalizedName];
      case 'servernames':
        if (node.arguments.isNotEmpty) {
          final amount = _stringifyArgument(node, 0).trim();
          final separator = node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : ', ';
          return '((servernames[$amount;$separator]))';
        }
        return _inlineRuntimeVariables['servernames'];
      // Parametric channel/guild lookups
      case 'channelid':
      case 'channelidfromname':
        if (node.arguments.isNotEmpty) {
          final channelName = _stringifyArgument(node, 0).trim();
          if (channelName.isNotEmpty) {
            return '((channel[$channelName].id))';
          }
        }
        return _inlineRuntimeVariables['channelid'];
      case 'guildid':
        if (node.arguments.isNotEmpty) {
          final guildName = _stringifyArgument(node, 0).trim();
          if (guildName.isNotEmpty) {
            return '((guild[$guildName].id))';
          }
        }
        return _inlineRuntimeVariables['guildid'];
      case 'roleid':
        final roleName = _stringifyArgument(node, 0).trim();
        if (roleName.isNotEmpty) {
          return '((role[$roleName].id))';
        }
        return '';
      case 'rolename':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].name))';
        }
        return '';
      case 'roleinfo':
        final roleId = _stringifyArgument(node, 0).trim();
        final property = _stringifyArgument(node, 1).trim();
        if (roleId.isNotEmpty) {
          if (property.isNotEmpty) {
            return '((role[$roleId].$property))';
          }
          return '((role[$roleId].info))';
        }
        return '';
      case 'roleexists':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].exists))';
        }
        return 'false';
      case 'roleperms':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].permissions))';
        }
        return '';
      case 'roleposition':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].position))';
        }
        return '';
      case 'getrolecolor':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].color))';
        }
        return '';
      case 'ishoisted':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].hoist))';
        }
        return 'false';
      case 'ismentionable':
        final roleId = _stringifyArgument(node, 0).trim();
        if (roleId.isNotEmpty) {
          return '((role[$roleId].mentionable))';
        }
        return 'false';
      case 'findrole':
        final roleName = _stringifyArgument(node, 0).trim();
        if (roleName.isNotEmpty) {
          return '((role[$roleName].id))';
        }
        return '';
      case 'hasrole':
        final userId = _stringifyArgument(node, 0).trim();
        final roleId = _stringifyArgument(node, 1).trim();
        if (roleId.isNotEmpty) {
          return '((member[$userId].hasRole[$roleId]))';
        }
        if (userId.isNotEmpty) {
          return '((member.hasRole[$userId]))';
        }
        return 'false';
      case 'userswithrole':
        final uwrRoleId = _stringifyArgument(node, 0).trim();
        if (uwrRoleId.isNotEmpty) {
          return '((role[$uwrRoleId].memberCount))';
        }
        return '0';
      // Parametric user info lookups
      case 'useravatar':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].avatar))';
          }
        }
        return _inlineRuntimeVariables['useravatar'];
      case 'userbanner':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].banner))';
          }
        }
        return _inlineRuntimeVariables['userbanner'];
      case 'userperms':
        final userId = node.arguments.isNotEmpty ? _stringifyArgument(node, 0).trim() : '';
        final returnAmount = node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '-1';
        final separator = node.arguments.length > 2 ? _stringifyArgument(node, 2).trim() : ', ';
        return '((userperms[$userId;$returnAmount;$separator]))';
      case 'isbot':
        if (node.arguments.isNotEmpty) {
          final userId = _stringifyArgument(node, 0).trim();
          if (userId.isNotEmpty) {
            return '((user[$userId].isBot))';
          }
        }
        return _inlineRuntimeVariables['isbot'];
      // Mentioned helper with index
      case 'mentioned':
        final returnSelf = node.arguments.length > 1 &&
            _stringifyArgument(node, 1).trim().toLowerCase() == 'yes';
        if (node.arguments.isNotEmpty) {
          final indexRaw = _stringifyArgument(node, 0).trim();
          final index = int.tryParse(indexRaw);
          if (index != null && index >= 1) {
            return returnSelf
                ? '((message.mentions[${index - 1}]|author.id))'
                : '((message.mentions[${index - 1}]))';
          }
        }
        return returnSelf
            ? '((message.mentions[0]|author.id))'
            : '((message.mentions[0]))';
      // All mentions (comma-separated user IDs)
      case 'mentions':
        return '((message.mentions))';
      // Reactions
      case 'getreactions':
        final emoji = _stringifyArgument(node, 0).trim();
        if (emoji.isNotEmpty) {
          return '((message.reactions[$emoji]))';
        }
        return '((message.reactions))';
      case 'userreacted':
        final userId = _stringifyArgument(node, 0).trim();
        final emoji = _stringifyArgument(node, 1).trim();
        return '((message.reactions[$emoji].includes[$userId]))';
      // Emoji info
      case 'customemoji':
        final emojiName = _stringifyArgument(node, 0).trim();
        if (emojiName.isNotEmpty) {
          return '((emoji[$emojiName]))';
        }
        return '';
      case 'emotecount':
      case 'emojicount':
        return '((guild.emojiCount))';
      case 'emojiexists':
        final emojiName = _stringifyArgument(node, 0).trim();
        if (emojiName.isNotEmpty) {
          return '((emoji[$emojiName].exists))';
        }
        return 'false';
      case 'emojiname':
        final emojiId = _stringifyArgument(node, 0).trim();
        if (emojiId.isNotEmpty) {
          return '((emoji[$emojiId].name))';
        }
        return '';
      case 'isemojianimated':
        final emojiId = _stringifyArgument(node, 0).trim();
        if (emojiId.isNotEmpty) {
          return '((emoji[$emojiId].animated))';
        }
        return 'false';
      // Webhook info
      case 'webhookavatarurl':
        return '((webhook.avatarURL))';
      case 'webhookcolor':
        return '((webhook.color))';
      case 'webhookdescription':
        return '((webhook.description))';
      case 'webhookfooter':
        return '((webhook.footer))';
      case 'webhooktitle':
        return '((webhook.title))';
      case 'webhookusername':
        return '((webhook.username))';
      case 'webhookcontent':
        return '((webhook.content))';
      // Ticket
      case 'isticket':
        return '((channel.isTicket))';
      // getMessage
      case 'getmessage':
        return _inlineGetMessage(node);
      // $c - comment function, returns empty
      case 'c':
        return '';
      default:
        break;
    }

    final placeholder = _inlineRuntimePlaceholder(node);
    if (placeholder != null) {
      return placeholder;
    }

    switch (node.normalizedName) {
      // JSON functions
      case 'json':
        return _jsonGet(node);
      case 'jsonexists':
        return _jsonExists(node);
      case 'jsonstringify':
        return _jsonStringify();
      case 'jsonpretty':
        return _jsonPretty(node);
      case 'jsonarraycount':
        return _jsonArrayCount(node);
      case 'jsonarrayindex':
        return _jsonArrayIndex(node);
      case 'jsonjoinarray':
        return _jsonJoinArray(node);
      case 'jsonkeys':
        return _jsonKeys(node);
      case 'jsonarraypop':
        return _jsonArrayPop(node);
      case 'jsonarrayshift':
        return _jsonArrayShift(node);
      // HTTP results
      case 'httpstatus':
        return _latestHttpStatusPlaceholder(node);
      case 'httpresult':
        return _latestHttpResultPlaceholder(node);
      // Variable getters
      case 'getuservar':
        final gvVarName = _stringifyArgument(node, 0);
        final gvUserId =
            node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '';
        final gvGuildId =
            node.arguments.length > 2 ? _stringifyArgument(node, 2).trim() : '';

        if (gvGuildId.isNotEmpty) {
          final contextId =
              gvUserId.isEmpty ? '$gvGuildId:((author.id))' : '$gvGuildId:$gvUserId';
          return _scopedVariablePlaceholder('guildMember', gvVarName, contextId);
        }
        return _scopedVariablePlaceholder('user', gvVarName, gvUserId);
      case 'getservervar':
      case 'getguildvar':
        final gsvVarName = _stringifyArgument(node, 0);
        final gsvGuildId =
            node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '';
        return _scopedVariablePlaceholder('guild', gsvVarName, gsvGuildId);
      case 'getchannelvar':
        final gcvVarName = _stringifyArgument(node, 0);
        final gcvChannelId =
            node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '';
        return _scopedVariablePlaceholder('channel', gcvVarName, gcvChannelId);
      case 'getmembervar':
      case 'getguildmembervar':
        final gmvVarName = _stringifyArgument(node, 0);
        final gmvUserId =
            node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '';
        final gmvGuildId =
            node.arguments.length > 2 ? _stringifyArgument(node, 2).trim() : '';

        final guildPart = gmvGuildId.isNotEmpty ? gmvGuildId : '((guild.id))';
        final userPart = gmvUserId.isNotEmpty ? gmvUserId : '((author.id))';
        final contextId = '$guildPart:$userPart';
        return _scopedVariablePlaceholder(
          'guildMember',
          gmvVarName,
          contextId,
        );
      case 'getmessagevar':
        final gmvVarName = _stringifyArgument(node, 0);
        final gmvMessageId =
            node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '';
        return _scopedVariablePlaceholder(
          'message',
          gmvVarName,
          gmvMessageId,
        );
      case 'getvar':
        // BDFD wiki: $getVar[Variable name;(User ID)]
        final gvVarName = _stringifyArgument(node, 0);
        final gvUserId =
            node.arguments.length > 1 ? _stringifyArgument(node, 1).trim() : '';
        if (gvUserId.isNotEmpty) {
          return _scopedVariablePlaceholder(
            'user',
            gvVarName,
            gvUserId,
          );
        }
        return _scopedVariablePlaceholder(
          'global',
          gvVarName,
        );
      case 'var':
        if (node.arguments.length >= 2) {
          return null;
        }
        return _scopedVariablePlaceholder('temp', _stringifyArgument(node, 0));
      case 'varexists':
        final key = _stringifyArgument(node, 0).trim();
        if (key.isNotEmpty) {
          return '((variables.exists[$key]))';
        }
        return 'false';
      case 'varexisterror':
        return '';
      case 'getleaderboardposition':
        return '((leaderboard.position))';
      case 'getleaderboardvalue':
        return '((leaderboard.value))';
      case 'globaluserleaderboard':
        final guVarName = _stringifyArgument(node, 0).trim();
        final guSort = _stringifyArgument(node, 1).trim();
        return '((globalUserLeaderboard[$guVarName${guSort.isNotEmpty ? ';$guSort' : ''}]))';
      case 'serverleaderboard':
        final slVarName = _stringifyArgument(node, 0).trim();
        final slSort = _stringifyArgument(node, 1).trim();
        return '((serverLeaderboard[$slVarName${slSort.isNotEmpty ? ';$slSort' : ''}]))';
      case 'userleaderboard':
        final ulVarName = _stringifyArgument(node, 0).trim();
        final ulSort = _stringifyArgument(node, 1).trim();
        return '((userLeaderboard[$ulVarName${ulSort.isNotEmpty ? ';$ulSort' : ''}]))';
      case 'getcooldown':
        final cooldownType = _stringifyArgument(node, 0).trim();
        if (cooldownType.isNotEmpty) {
          return '((cooldown[$cooldownType].remaining))';
        }
        return '((cooldown.remaining))';
      // Workflow response
      case 'workflowresponse':
        return _latestWorkflowResponsePlaceholder(node);
      // Text manipulation (compile-time)
      case 'replacetext':
        return _inlineReplaceText(node);
      case 'tolowercase':
        final lowerValue = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(lowerValue)) {
          return _buildRuntimeBracketExpression('tolowercase', <String>[
            lowerValue,
          ]);
        }
        return lowerValue.toLowerCase();
      case 'touppercase':
        final upperValue = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(upperValue)) {
          return _buildRuntimeBracketExpression('touppercase', <String>[
            upperValue,
          ]);
        }
        return upperValue.toUpperCase();
      case 'totitlecase':
        final titleValue = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(titleValue)) {
          return _buildRuntimeBracketExpression('totitlecase', <String>[
            titleValue,
          ]);
        }
        return _inlineTitleCase(titleValue);
      case 'charcount':
        final charCountValue = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(charCountValue)) {
          return _buildRuntimeBracketExpression('charcount', <String>[
            charCountValue,
          ]);
        }
        return charCountValue.length.toString();
      case 'bytecount':
        final byteCountValue = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(byteCountValue)) {
          return _buildRuntimeBracketExpression('bytecount', <String>[
            byteCountValue,
          ]);
        }
        return utf8.encode(byteCountValue).length.toString();
      case 'linescount':
        final text = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(text)) {
          return _buildRuntimeBracketExpression('linescount', <String>[text]);
        }
        return text.isEmpty ? '0' : text.split('\n').length.toString();
      case 'croptext':
        final cropText = _stringifyArgument(node, 0);
        final cropLength = _stringifyArgument(node, 1);
        final cropSuffix = _stringifyArgument(node, 2);
        if (_containsRuntimePlaceholder(cropText) ||
            _containsRuntimePlaceholder(cropLength) ||
            _containsRuntimePlaceholder(cropSuffix)) {
          return _buildRuntimeBracketExpression('croptext', <String>[
            cropText,
            cropLength,
            cropSuffix,
          ]);
        }
        return _inlineCropText(node);
      case 'trimcontent':
        final trimContentValue = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(trimContentValue)) {
          return _buildRuntimeBracketExpression('trimcontent', <String>[
            trimContentValue,
          ]);
        }
        return trimContentValue.trim();
      case 'trimspace':
        final trimSpaceValue = _stringifyArgument(node, 0);
        if (_containsRuntimePlaceholder(trimSpaceValue)) {
          return _buildRuntimeBracketExpression('trimspace', <String>[
            trimSpaceValue,
          ]);
        }
        return trimSpaceValue.trim();
      case 'unescape':
        return _stringifyArgument(node, 0);
      case 'repeatmessage':
        return _inlineRepeatMessage(node);
      case 'removecontains':
        return _inlineRemoveContains(node);
      case 'numberseparator':
        return _inlineNumberSeparator(node);
      case 'splittext':
        return _inlineSplitText(node);
      case 'editsplittext':
        return _inlineEditSplitText(node);
      case 'gettextsplitindex':
        return _inlineGetTextSplitIndex(node);
      case 'gettextsplitlength':
        return _textSplitParts.length.toString();
      case 'joinsplittext':
        return _inlineJoinSplitText(node);
      case 'removesplittextelement':
        return _inlineRemoveSplitTextElement(node);
      // Math functions (compile-time)
      case 'calculate':
        return _inlineCalculate(node);
      case 'ceil':
        return _inlineMathUnary(node, (v) => v.ceil());
      case 'floor':
        return _inlineMathUnary(node, (v) => v.floor());
      case 'round':
        return _inlineMathUnary(node, (v) => v.round());
      case 'sqrt':
        return _inlineMathUnaryDouble(node, math.sqrt);
      case 'max':
        return _inlineMathBinary(node, math.max);
      case 'min':
        return _inlineMathBinary(node, math.min);
      case 'modulo':
        return _inlineMathBinaryOp(node, (a, b) => b != 0 ? a % b : 0);
      case 'multi':
        return _inlineMathBinaryOp(node, (a, b) => a * b);
      case 'divide':
        return _inlineMathBinaryOp(node, (a, b) => b != 0 ? a / b : 0);
      case 'sub':
        return _inlineMathBinaryOp(node, (a, b) => a - b);
      case 'sum':
        return _inlineSum(node);
      case 'sort':
        return _inlineSort(node);
      // Boolean check functions (compile-time)
      case 'isboolean':
        return _inlineIsBoolean(node);
      case 'isinteger':
        return _inlineIsInteger(node);
      case 'isnumber':
        return _inlineIsNumber(node);
      case 'isvalidhex':
        return _inlineIsValidHex(node);
      case 'checkcondition':
        return _inlineCheckCondition(node);
      case 'checkcontains':
        return _inlineCheckContains(node);
      // Random functions (compile-time)
      case 'random':
        return _inlineRandom(node);
      case 'randomstring':
        return _inlineRandomString(node);
      case 'randomtext':
        return _inlineRandomText(node);
      // Date/Time functions (runtime dynamic)
      case 'date':
        return '((date))';
      case 'day':
        return '((day))';
      case 'hour':
        return '((hour))';
      case 'minute':
        return '((minute))';
      case 'month':
        return '((month))';
      case 'second':
        return '((second))';
      case 'year':
        return '((year))';
      case 'time':
        return '((time))';
      case 'gettimestamp':
        return '((getTimestamp))';
      case 'gettimestampms':
        return '((getTimestampMs))';
      // Misc inline
      case 'getserverinvite':
        return '((guild.invite))';
      case 'getinviteinfo':
        return '((invite.info))';
      case 'hostingexpiretime':
        return '((hosting.expireTime))';
      case 'premiumexpiretime':
        return '((premium.expireTime))';
      case 'randomcategoryid':
        return '((random.categoryId))';
      case 'randomchannelid':
        return '((random.channelId))';
      case 'randomguildid':
        return '((random.guildId))';
      case 'randommention':
        return '((random.mention))';
      case 'randomroleid':
        return '((random.roleId))';
      case 'randomuser':
        return '((random.user))';
      case 'randomuserid':
        return '((random.userId))';
      // Parameterized inline functions (wiki requires arguments)
      case 'getbanreason':
        // BDFD wiki: $getBanReason[User ID;(Guild ID)]
        final brUserId = _stringifyArgument(node, 0).trim();
        if (brUserId.isNotEmpty) {
          final brGuildId = _stringifyArgument(node, 1).trim();
          if (brGuildId.isNotEmpty) {
            return '((ban.reason[$brUserId;$brGuildId]))';
          }
          return '((ban.reason[$brUserId]))';
        }
        return _inlineRuntimeVariables['getbanreason'];
      case 'isbanned':
        // BDFD wiki: $isBanned[User ID]
        final ibUserId = _stringifyArgument(node, 0).trim();
        if (ibUserId.isNotEmpty) {
          return '((member[$ibUserId].isBanned))';
        }
        return _inlineRuntimeVariables['isbanned'];
      case 'istimedout':
        // BDFD wiki: $isTimedOut[User ID]
        final itUserId = _stringifyArgument(node, 0).trim();
        if (itUserId.isNotEmpty) {
          return '((member[$itUserId].isTimedOut))';
        }
        return _inlineRuntimeVariables['istimedout'];
      case 'getslowmode':
        // BDFD wiki: $getSlowmode[(Channel ID)]
        if (node.arguments.isNotEmpty) {
          final smChannelId = _stringifyArgument(node, 0).trim();
          if (smChannelId.isNotEmpty) {
            return '((channel[$smChannelId].rateLimitPerUser))';
          }
        }
        return _inlineRuntimeVariables['getslowmode'];
      case 'isnsfw':
        // BDFD wiki: $isNSFW[Channel ID]
        final nsfwChannelId = _stringifyArgument(node, 0).trim();
        if (nsfwChannelId.isNotEmpty) {
          return '((channel[$nsfwChannelId].nsfw))';
        }
        return _inlineRuntimeVariables['isnsfw'];
      case 'ismentioned':
        // BDFD wiki: $isMentioned[User ID]
        final imUserId = _stringifyArgument(node, 0).trim();
        if (imUserId.isNotEmpty) {
          return '((message.isMentioned[$imUserId]))';
        }
        return _inlineRuntimeVariables['ismentioned'];
      case 'ismessageedited':
        // BDFD wiki: $isMessageEdited[Channel ID;Message ID]
        final meChannelId = _stringifyArgument(node, 0).trim();
        final meMessageId = _stringifyArgument(node, 1).trim();
        if (meChannelId.isNotEmpty && meMessageId.isNotEmpty) {
          return '((message[$meChannelId;$meMessageId].isEdited))';
        }
        return _inlineRuntimeVariables['ismessageedited'];
      case 'getattachments':
        // BDFD wiki: $getAttachments[Index]
        final attIndex = _stringifyArgument(node, 0).trim();
        if (attIndex.isNotEmpty) {
          return '((message.attachments[$attIndex]))';
        }
        return _inlineRuntimeVariables['getattachments'];
      case 'getembeddata':
        // BDFD wiki: $getEmbedData[Channel ID;Message ID;Embed index;Embed property]
        final edChannelId = _stringifyArgument(node, 0).trim();
        final edMessageId = _stringifyArgument(node, 1).trim();
        final edIndex = _stringifyArgument(node, 2).trim();
        final edProperty = _stringifyArgument(node, 3).trim();
        if (edChannelId.isNotEmpty && edMessageId.isNotEmpty) {
          return '((message[$edChannelId;$edMessageId].embeds[${edIndex.isEmpty ? '0' : edIndex}]${edProperty.isNotEmpty ? '.$edProperty' : ''}))';
        }
        return _inlineRuntimeVariables['getembeddata'];
      case 'and':
        final andArgs = <String>[];
        for (var i = 0; i < node.arguments.length; i++) {
          andArgs.add(_stringifyArgument(node, i));
        }
        return _buildRuntimeBracketExpression('and', andArgs);
      case 'or':
        final orArgs = <String>[];
        for (var i = 0; i < node.arguments.length; i++) {
          orArgs.add(_stringifyArgument(node, i));
        }
        return _buildRuntimeBracketExpression('or', orArgs);
      case 'listvar':
        final listvarSep = node.arguments.isNotEmpty ? _stringifyArgument(node, 0) : ',';
        return _buildRuntimeBracketExpression('listvar', <String>[listvarSep]);
      case 'variablescount':
        final vcType = node.arguments.isNotEmpty ? _stringifyArgument(node, 0) : '';
        return _buildRuntimeBracketExpression('variablescount', <String>[vcType]);
      default:
        return _inlineRuntimePlaceholder(node);
    }
  }

  String? _inlineRuntimePlaceholder(BdfdFunctionCallAst node) {
    return _inlineRuntimeVariables[node.normalizedName];
  }

  bool _isInlineOnlyNode(BdfdFunctionCallAst node) {
    if (node.normalizedName == 'var' && node.arguments.length >= 2) {
      return false;
    }
    return _isInlineOnlyFunction(node.normalizedName);
  }

  bool _isInlineOnlyFunction(String normalizedName) {
    if (_loopDepth > 0 && _loopVariables.containsKey(normalizedName)) {
      return true;
    }
    if (_runtimeLoopVarNames != null &&
        _runtimeLoopVarNames!.contains(normalizedName)) {
      return true;
    }
    switch (normalizedName) {
      case 'json':
      case 'jsonexists':
      case 'jsonstringify':
      case 'jsonpretty':
      case 'jsonarraycount':
      case 'jsonarrayindex':
      case 'jsonjoinarray':
      case 'jsonkeys':
      case 'jsonarraypop':
      case 'jsonarrayshift':
      case 'startthread':
      case 'editthread':
      case 'threadaddmember':
      case 'threadremovemember':
      case 'checkuserperms':
      case 'checkusersperms':
      case 'message':
      case 'args':
      case 'i':
      case 'loopindex':
      case 'loopiteration':
      case 'loopcount':
      case 'mentionedchannels':
      case 'httpstatus':
      case 'httpresult':
      case 'getuservar':
      case 'getservervar':
      case 'getguildvar':
      case 'getchannelvar':
      case 'getmembervar':
      case 'getguildmembervar':
      case 'getmessagevar':
      case 'getvar':
      case 'var':
      case 'varexists':
      case 'varexisterror':
      case 'workflowresponse':
      case 'getleaderboardposition':
      case 'getleaderboardvalue':
      case 'getcooldown':
      // Text manipulation
      case 'replacetext':
      case 'tolowercase':
      case 'touppercase':
      case 'totitlecase':
      case 'charcount':
      case 'bytecount':
      case 'linescount':
      case 'croptext':
      case 'trimcontent':
      case 'trimspace':
      case 'unescape':
      case 'repeatmessage':
      case 'removecontains':
      case 'numberseparator':
      case 'splittext':
      case 'editsplittext':
      case 'gettextsplitindex':
      case 'gettextsplitlength':
      case 'joinsplittext':
      case 'removesplittextelement':
      // Math
      case 'calculate':
      case 'ceil':
      case 'floor':
      case 'round':
      case 'sqrt':
      case 'max':
      case 'min':
      case 'modulo':
      case 'multi':
      case 'divide':
      case 'sub':
      case 'sum':
      case 'sort':
      // Boolean checks
      case 'isboolean':
      case 'isinteger':
      case 'isnumber':
      case 'isvalidhex':
      case 'checkcondition':
      case 'checkcontains':
      // Random
      case 'random':
      case 'randomstring':
      case 'randomtext':
      // Date/Time
      case 'date':
      case 'day':
      case 'hour':
      case 'minute':
      case 'month':
      case 'second':
      case 'year':
      case 'time':
      case 'gettimestamp':
      case 'gettimestampms':
      // Parametric lookups
      case 'channelid':
      case 'channelidfromname':
      case 'and':
      case 'or':
      case 'listvar':
      case 'variablescount':
      case 'guildid':
      case 'roleid':
      case 'rolename':
      case 'roleinfo':
      case 'roleexists':
      case 'roleperms':
      case 'roleposition':
      case 'getrolecolor':
      case 'isbot':
      case 'ishoisted':
      case 'ismentionable':
      case 'findrole':
      case 'hasrole':
      case 'userswithrole':
      case 'useravatar':
      case 'userbanner':
      case 'mentioned':
      case 'mentions':
      case 'getreactions':
      case 'userreacted':
      case 'customemoji':
      case 'emotecount':
      case 'emojicount':
      case 'emojiexists':
      case 'emojiname':
      case 'isemojianimated':
      case 'webhookavatarurl':
      case 'webhookcolor':
      case 'webhookdescription':
      case 'webhookfooter':
      case 'webhooktitle':
      case 'webhookusername':
      case 'webhookcontent':
      case 'isticket':
      case 'getmessage':
      case 'c':
      case 'globaluserleaderboard':
      case 'serverleaderboard':
      case 'userleaderboard':
      case 'getserverinvite':
      case 'getinviteinfo':
      case 'hostingexpiretime':
      case 'premiumexpiretime':
      case 'randomcategoryid':
      case 'randomchannelid':
      case 'randomguildid':
      case 'randommention':
      case 'randomroleid':
      case 'randomuser':
      case 'randomuserid':
        return true;
      default:
        return _inlineRuntimeVariables.containsKey(normalizedName);
    }
  }

  bool _requiresPendingResponseFlush(String normalizedName) {
    switch (normalizedName) {
      case 'sendmessage':
      case 'reply':
      case 'channelsendmessage':
      case 'onlyif':
      case 'onlyforusers':
      case 'onlyforchannels':
      case 'onlyforroles':
      case 'onlyforids':
      case 'onlyforroleids':
      case 'onlyforservers':
      case 'onlyforcategories':
      case 'ignorechannels':
      case 'onlynsfw':
      case 'onlyadmin':
      case 'onlyperms':
      case 'onlybotperms':
      case 'onlybotchannelperms':
      case 'checkuserperms':
      case 'checkusersperms':
      case 'onlyifmessagecontains':
      case 'enabled':
      case 'startthread':
      case 'editthread':
      case 'threadaddmember':
      case 'threadremovemember':
      case 'if':
      case 'stop':
      case 'httpget':
      case 'httppost':
      case 'httpput':
      case 'httpdelete':
      case 'httppatch':
      case 'setuservar':
      case 'setservervar':
      case 'setguildvar':
      case 'setchannelvar':
      case 'setmembervar':
      case 'setguildmembervar':
      case 'setmessagevar':
      case 'setvar':
      case 'awaitfunc':
      case 'changeusername':
      case 'changeusernamewithid':
      // Moderation
      case 'ban':
      case 'banid':
      case 'unban':
      case 'unbanid':
      case 'kick':
      case 'kickmention':
      case 'timeout':
      case 'mute':
      case 'untimeout':
      case 'unmute':
      case 'clear':
      // Roles
      case 'giverole':
      case 'giveroles':
      case 'rolegrant':
      case 'takerole':
      case 'takeroles':
      case 'createrole':
      case 'deleterole':
      case 'colorrole':
      case 'modifyrole':
      case 'modifyroleperms':
      case 'setuserroles':
      // Messages
      case 'deletemessage':
      case 'deletein':
      case 'dm':
      case 'editmessage':
      case 'editin':
      case 'editembedin':
      case 'pinmessage':
      case 'unpinmessage':
      case 'publishmessage':
      case 'replyin':
      case 'sendembedmessage':
      case 'usechannel':
      // Channels
      case 'createchannel':
      case 'deletechannels':
      case 'deletechannelsbyname':
      case 'modifychannel':
      case 'editchannelperms':
      case 'modifychannelperms':
      case 'slowmode':
      // Reactions
      case 'addreactions':
      case 'addcmdreactions':
      case 'addmessagereactions':
      case 'clearreactions':
      // Emoji
      case 'addemoji':
      case 'removeemoji':
      // Webhooks
      case 'webhooksend':
      case 'webhookcreate':
      case 'webhookdelete':
      // Modal
      case 'newmodal':
      case 'defer':
      // Cooldown
      case 'cooldown':
      case 'globalcooldown':
      case 'servercooldown':
      case 'changecooldowntime':
      // Variable reset
      case 'resetuservar':
      case 'resetservervar':
      case 'resetguildvar':
      case 'resetchannelvar':
      case 'resetmembervar':
      case 'resetguildmembervar':
      // Blacklist
      case 'blacklistids':
      case 'blacklistroles':
      case 'blacklistrolesids':
      case 'blacklistroleids':
      case 'blacklistservers':
      case 'blacklistusers':
      // Bot actions
      case 'botleave':
      case 'bottyping':
      // Ticket
      case 'closeticket':
      case 'newticket':
      // Args check
      case 'argscheck':
      // Workflow call
      case 'callworkflow':
      // Dynamic eval
      case 'eval':
      // Debug profiling
      case 'debug':
        return true;
      default:
        return false;
    }
  }

  List<Action> _drainDeferredInlineActions() {
    if (_deferredInlineActions.isEmpty) {
      return const <Action>[];
    }
    final drained = List<Action>.from(_deferredInlineActions);
    _deferredInlineActions.clear();
    return drained;
  }

  void _enqueuePendingConditionAction(Action action) {
    if (_conditionActionStack.isEmpty) {
      _deferredInlineActions.add(action);
      return;
    }
    _conditionActionStack.last.add(action);
  }

  List<Action> _drainPendingConditionActions() {
    if (_conditionActionStack.isEmpty || _conditionActionStack.last.isEmpty) {
      return const <Action>[];
    }
    final drained = List<Action>.from(_conditionActionStack.last);
    _conditionActionStack.last.clear();
    return drained;
  }
}
