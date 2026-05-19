import 'dart:convert';

import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/awaited_registration.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
    test('compiles runtime variable placeholders and scoped vars', () {
      final result = BdfdCompiler().compile(
        r'Hello $username$setUserVar[lastAuthor;$authorID]$getUserVar[lastAuthor]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(
        result.actions.first.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.first.payload['content'],
        'Hello ((user.username))',
      );
      expect(result.actions[1].type, BotCreatorActionType.setScopedVariable);
      expect(result.actions[1].payload['scope'], 'user');
      expect(result.actions[1].payload['key'], 'lastAuthor');
      expect(result.actions[1].payload['value'], '((author.id))');
      expect(result.actions[2].payload['content'], '((user.bc_lastAuthor))');
    });

    test('compiles message[] helper for normal/slash fallback', () {
      final result = BdfdCompiler().compile(
        r'$reply$message[1;text]|$message[text]|$message[>]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        '((message.content[0]|opts.text))|((opts.text))|((last(split(message.content, " "))))',
      );
    });

    test('compiles message helper without brackets', () {
      final result = BdfdCompiler().compile(r'$reply$message');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(result.actions.single.payload['content'], '((message.content))');
    });

    test('compiles args helper with runtime args fallback', () {
      final result = BdfdCompiler().compile(r'$reply$args[2]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        '((message.content[1]|args.2))',
      );
    });

    test('compiles getTimestampMs as runtime placeholder', () {
      final result = BdfdCompiler().compile(r'$reply$getTimestampMs');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final raw = result.actions.single.payload['content']?.toString() ?? '';
      expect(raw, '((getTimestampMs))');

      // Verify it resolves to a current-ish timestamp at runtime.
      final resolved = resolveTemplatePlaceholders(raw, <String, String>{});
      final value = int.tryParse(resolved);
      expect(value, isNotNull);
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(value! >= now - 1000, isTrue);
      expect(value <= now + 1000, isTrue);
    });

    test(
      'resolves sub with getTimestampMs and messageTimestamp at runtime',
      () {
        final result = BdfdCompiler().compile(
          r'$reply$c[]Latency: $sub[$getTimestampMs;$messageTimestamp] ms',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final compiled =
            result.actions.single.payload['content']?.toString() ?? '';
        final messageTimestamp =
            DateTime.now().toUtc().millisecondsSinceEpoch - 25;
        final resolved = resolveTemplatePlaceholders(compiled, <String, String>{
          'message.timestamp': messageTimestamp.toString(),
        });

        final match = RegExp(r'^Latency: (\d+) ms$').firstMatch(resolved);
        expect(match, isNotNull);
        expect(int.parse(match!.group(1)!), greaterThanOrEqualTo(0));
      },
    );

    test('resolves ping compiled to bot.ping at runtime', () {
      final result = BdfdCompiler().compile(r'$reply$c[]Ping: $ping ms');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final compiled =
          result.actions.single.payload['content']?.toString() ?? '';
      // Verify the compiled output contains bot.ping reference
      expect(compiled, contains('bot.ping'));

      final resolved = resolveTemplatePlaceholders(compiled, <String, String>{
        'bot.ping': '52',
      });

      expect(resolved, 'Ping: 52 ms');
    });

    test('compiles channelSendMessage helper', () {
      final result = BdfdCompiler().compile(
        r'$channelSendMessage[123456789012345678;Hello!]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['channelId'], '123456789012345678');
      expect(result.actions.single.payload['content'], 'Hello!');
    });

    test('compiles mentionedChannels helper', () {
      final result = BdfdCompiler().compile(
        r'$reply$mentionedChannels[1]|$mentionedChannels[1;yes]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        '((message.mentions[0]))|((message.mentions[0]|channel.id))',
      );
    });

    test('compiles user identity helper functions without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$reply$authorAvatar|$authorID|$authorOfMessage|$creationDate|$discriminator|$displayName|$displayName[123]|$getUserStatus|$getCustomStatus|$isAdmin|$isBooster|$isBot|$isUserDMEnabled|$nickname|$nickname[123]|$userAvatar|$userBadges|$userBanner|$userBannerColor|$userExists|$userID|$userInfo|$userJoined|$userJoinedDiscord|$username|$username[123]|$userPerms|$userServerAvatar|$findUser',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final content =
          result.actions.single.payload['content']?.toString() ?? '';
      expect(content, contains('((author.avatar))'));
      expect(content, contains('((author.id))'));
      expect(content, contains('((member.permissions))'));
      expect(content, contains('((user.id))'));
    });

    test('compiles changeUsername and changeUsernameWithID helpers', () {
      final result = BdfdCompiler().compile(
        r'$changeUsername[NewName]'
        r'$changeUsernameWithID[1234567890;AnotherName]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.updateSelfUser);
      expect(result.actions[0].payload['username'], 'NewName');
      expect(result.actions[1].type, BotCreatorActionType.ifBlock);
    });

    test('surfaces unsupported functions as compile errors', () {
      final result = BdfdCompiler().compile(r'$totallyFakeFunction[$authorID]');

      expect(result.hasErrors, isTrue);
      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$totallyFakeFunction');
      expect(
        result.diagnostics.single.stage,
        BdfdCompileDiagnosticStage.transpiler,
      );
    });

    test('treats unresolved no-arg dollar token as literal text', () {
      final result = BdfdCompiler().compile(r'$reply$test');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(result.actions.single.payload['content'], r'$test');
    });

    test('preserves nested unsupported text functions as warnings only', () {
      final result = BdfdCompiler().compile(
        r'$description[Hello $unknownFunction[test]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.diagnostics.single.severity,
        BdfdCompileDiagnosticSeverity.warning,
      );
    });

    test('compiles BDFD http helpers to httpRequest and placeholders', () {
      final result = BdfdCompiler().compile(
        r'$httpAddHeader[content-type;application/x-www-form-urlencoded]'
        r'$httpPost[https://pastebin.com/api/api_post.php;api_option=paste]'
        r'$reply$httpStatus|$httpResult',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.httpRequest);
      expect(result.actions.first.payload['method'], 'POST');
      expect(result.actions.first.payload['bodyText'], 'api_option=paste');
      expect(result.actions.first.payload['headers'], {
        'content-type': 'application/x-www-form-urlencoded',
      });
      expect(
        result.actions.last.payload['content'],
        '((http.status))|((http.body))',
      );
    });

    test('surfaces httpStatus before request as compile error', () {
      final result = BdfdCompiler().compile(r'$reply$httpStatus');

      expect(result.hasErrors, isTrue);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$httpStatus');
    });

    test('compiles awaitFunc to scoped awaited registration action', () {
      final result = BdfdCompiler().compile(
        r'$reply$c[]What do you want me to say?$awaitFunc[say]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions.last.type, BotCreatorActionType.setScopedVariable);
      expect(result.actions.last.payload['scope'], 'user');
      expect(result.actions.last.payload['key'], 'await_say');
      expect(result.actions.last.payload['valueType'], 'json');
      expect(
        (result.actions.last.payload['jsonValue'] as String),
        contains('"name":"say"'),
      );
    });

    test('compiles block if/elseif/else/endif and logical conditions', () {
      final result = BdfdCompiler().compile(
        r'$if[$or[((score))>10;((isAdmin))==true]==true]'
        r'Gold\n'
        r'$elseif[((score))==10]'
        r'Silver\n'
        r'$else\n'
        r'Bronze\n'
        r'$endif',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.ifBlock);

      final payload = result.actions.single.payload;
      expect(payload['condition.group'], 'or');

      final elseIfConditions = List<Map<String, dynamic>>.from(
        payload['elseIfConditions'] as List,
      );
      expect(elseIfConditions, hasLength(1));
      expect(elseIfConditions.single['condition.operator'], 'equals');
    });

    test('compiles stop to stop action', () {
      final result = BdfdCompiler().compile(r'$stop');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.stop);
    });

    test('compiles json helper workflow without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{}]'
        r'$jsonArray[scores]'
        r'$jsonArrayAppend[scores;5]'
        r'$jsonArrayAppend[scores;8]'
        r'$jsonArrayAppend[scores;10]'
        r'$reply$c[]Count=$jsonArrayCount[scores]|Top=$json[ scores;1 ]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(result.actions.single.payload['content'], 'Count=3|Top=8');
    });

    test('compiles jsonKeys to list all keys of root object', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"a":1,"b":2,"c":3}]'
        r'$reply$jsonKeys[]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'a,b,c');
    });

    test('compiles jsonKeys with custom separator', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"x":1,"y":2}]'
        r'$reply$jsonKeys[;|]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'x|y');
    });

    test('compiles jsonKeys at nested path', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"data":{"name":"test","value":42}}]'
        r'$reply$jsonKeys[data]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'name,value');
    });

    test('compiles jsonForEach to jsonForEachLoop action', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"a":1,"b":2}]'
        r'$jsonForEach[]'
        r'$reply$jsonKey=$jsonValue'
        r'$endJsonForEach',
      );

      expect(result.hasErrors, isFalse);
      // jsonParse with a literal embeds the source in the jsonForEachLoop payload
      final feActions = result.actions.where(
        (a) => a.type == BotCreatorActionType.jsonForEachLoop,
      );
      expect(feActions, hasLength(1));
      final payload = feActions.first.payload;
      expect(payload['path'], isEmpty);
      expect(payload['bodyActions'], isA<List>());
      expect((payload['bodyActions'] as List), isNotEmpty);
      expect(payload['source'], '{"a":1,"b":2}');
    });

    test('compiles jsonForEach with nested path', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"data":{"x":1,"y":2}}]'
        r'$jsonForEach[data]'
        r'$reply$jsonKey'
        r'$endJsonForEach',
      );

      expect(result.hasErrors, isFalse);
      final feActions = result.actions.where(
        (a) => a.type == BotCreatorActionType.jsonForEachLoop,
      );
      expect(feActions, hasLength(1));
      final payload = feActions.first.payload;
      expect(payload['path'], ['data']);
    });

    test('compiles jsonForEach with \$jsonIndex placeholder', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{"a":1}]'
        r'$jsonForEach[]'
        r'$reply$jsonIndex: $jsonKey=$jsonValue'
        r'$endJsonForEach',
      );

      expect(result.hasErrors, isFalse);
      final feActions = result.actions.where(
        (a) => a.type == BotCreatorActionType.jsonForEachLoop,
      );
      expect(feActions, hasLength(1));
      // Body actions should contain placeholders for jsonindex, jsonkey, jsonvalue
      final bodyActions = feActions.first.payload['bodyActions'] as List;
      expect(bodyActions, isNotEmpty);
      final content =
          (bodyActions.first as Map<String, dynamic>)['payload']?['content'] ??
          '';
      expect(content, contains('((_loop.var.jsonindex))'));
      expect(content, contains('((_loop.var.jsonkey))'));
      expect(content, contains('((_loop.var.jsonvalue))'));
    });

    test('emits diagnostic for unclosed jsonForEach', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{}]'
        r'$jsonForEach[]'
        r'$reply$c[]test',
      );

      // Should still compile but with a diagnostic warning
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any((d) => d.message.contains(r'$endJsonForEach')),
        isTrue,
      );
    });

    test('emits diagnostic for standalone endJsonForEach', () {
      final result = BdfdCompiler().compile(
        r'$reply$c[]test'
        r'$endJsonForEach',
      );

      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.any((d) => d.message.contains(r'$jsonForEach')),
        isTrue,
      );
    });

    test('compiles invalid jsonParse without blocking diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[{invalid}]'
        r'$reply$c[]Value=$json[user;name]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'Value=');
    });

    test('compiles thread helpers without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$startThread[Cool Thread;123;;1440;yes]'
        r'$editThread[12345;Cool Thread 😎;no;!unchanged;!unchanged;5]'
        r'$threadAddMember[12345;999]'
        r'$threadRemoveMember[12345;999]'
        r'$reply$c[]Thread created: $startThread[Second Thread;123;;60;yes]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].type, BotCreatorActionType.createThread);
      expect(result.actions[1].type, BotCreatorActionType.updateChannel);
      expect(result.actions[2].type, BotCreatorActionType.addThreadMember);
      expect(result.actions[3].type, BotCreatorActionType.removeThreadMember);
      expect(result.actions[4].type, BotCreatorActionType.createThread);
      expect(result.actions[5].type, BotCreatorActionType.sendMessage);
      expect(result.actions[5].payload['targetType'], 'reply');
      expect(
        result.actions[5].payload['content'],
        '((thread.lastId))Thread created: ((thread.lastId))',
      );
    });

    test(
      'compiles additem flow with deferred json stringify into setServerVar payload',
      () {
        final result = BdfdCompiler().compile(
          r'$onlyIf[$argCount>0;usage]'
          r'$jsonParse[$getServerVar[items_db]]'
          r'$jsonArrayAppend[items;$args[2]]'
          r'$setServerVar[items_db;$jsonStringify]'
          r'$reply$c[]ok',
        );

        expect(result.hasErrors, isFalse);

        final runtimeIndex = result.actions.indexWhere(
          (a) => a.type == BotCreatorActionType.runtimeJsonBlock,
        );
        final setVarIndex = result.actions.indexWhere(
          (a) => a.type == BotCreatorActionType.setScopedVariable,
        );

        expect(runtimeIndex, greaterThanOrEqualTo(0));
        expect(setVarIndex, greaterThanOrEqualTo(0));
        expect(runtimeIndex, lessThan(setVarIndex));

        final setPayload = result.actions[setVarIndex].payload;
        expect(setPayload['scope'], 'guild');
        expect(setPayload['key'], 'items_db');

        final value = (setPayload['value'] ?? '').toString();
        expect(value, contains('rtJson_'));
        expect(value, isNot(contains('.json_')));
      },
    );

    test('compiles finditem flow with runtime json before if block', () {
      final result = BdfdCompiler().compile(
        r'$onlyIf[$argCount>0;usage]'
        r'$jsonParse[$getServerVar[items_db]]'
        r'$var[idx;$jsonArrayIndex[items;$args[2]]]'
        r'$if[$var[idx]==-1;$reply$c[]not found;$reply$c[]found at $var[idx]: $json[items;$var[idx]]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[2].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[3].type, BotCreatorActionType.ifBlock);

      final tempPayload = result.actions[2].payload;
      expect(tempPayload['key'], 'idx');
      expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
      expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));

      final conditionVariable =
          (result.actions[3].payload['condition.variable'] ?? '').toString();
      expect(conditionVariable, '((temp.idx))');

      final elseActions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['elseActions'] as List? ?? const [],
      );
      expect(elseActions, hasLength(2));
      expect(elseActions[0]['type'], 'runtimeJsonBlock');
      expect(elseActions[1]['type'], 'sendMessage');
      expect(
        (elseActions[1]['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );

      final elseContent =
          (elseActions[1]['payload'] as Map<String, dynamic>)['content']
              .toString();
      expect(elseContent, contains('((temp.idx))'));
      expect(elseContent, contains('rtJson_1.json_0'));
    });

    test(
      'compiles try block after runtime json with temp runtime var body',
      () {
        final result = BdfdCompiler().compile(
          r'$jsonParse[$getServerVar[items_db]]'
          r'$try'
          r'$var[idx;$jsonArrayIndex[items;$message[1]]]'
          r'$reply$var[idx]'
          r'$catch'
          r'$reply$c[]fallback'
          r'$endtry',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(2));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[1].type, BotCreatorActionType.ifBlock);

        final thenActions = List<Map<String, dynamic>>.from(
          result.actions[1].payload['thenActions'] as List? ?? const [],
        );
        expect(thenActions, hasLength(3));
        expect(thenActions[0]['type'], 'runtimeJsonBlock');
        expect(thenActions[1]['type'], 'setTemporaryVariable');
        expect(thenActions[2]['type'], 'sendMessage');
        expect(
          (thenActions[2]['payload'] as Map<String, dynamic>)['targetType'],
          'reply',
        );

        final bodyJsonPayload = Map<String, dynamic>.from(
          thenActions[0]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect((bodyJsonPayload['source'] ?? '').toString(), '((rtJson_0))');

        final tempPayload = Map<String, dynamic>.from(
          thenActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect(tempPayload['key'], 'idx');
        expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
        expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));
        expect(
          (thenActions[2]['payload'] as Map<String, dynamic>)['content'],
          '((temp.idx))',
        );

        final elseActions = List<Map<String, dynamic>>.from(
          result.actions[1].payload['elseActions'] as List? ?? const [],
        );
        expect(elseActions, hasLength(1));
        expect(elseActions.single['type'], 'sendMessage');
        expect(
          (elseActions.single['payload'] as Map<String, dynamic>)['targetType'],
          'reply',
        );
        expect(
          (elseActions.single['payload'] as Map<String, dynamic>)['content'],
          'fallback',
        );
      },
    );

    test('compiles additem flow with literal setServerVar value', () {
      final result = BdfdCompiler().compile(
        r'$onlyIf[$argCount>0;usage]'
        r'$jsonParse[$getServerVar[items_db]]'
        r'$jsonArrayAppend[items;$args[2]]'
        r'$setServerVar[items_db;teststorage]'
        r'$reply$c[]ok',
      );

      expect(result.hasErrors, isFalse);

      final setVarIndex = result.actions.indexWhere(
        (a) => a.type == BotCreatorActionType.setScopedVariable,
      );
      expect(setVarIndex, greaterThanOrEqualTo(0));

      final setPayload = result.actions[setVarIndex].payload;
      expect(setPayload['scope'], 'guild');
      expect(setPayload['key'], 'items_db');
      expect(setPayload['value'], 'teststorage');
    });

    test('compiles guard helpers without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$onlyIf[((score))>=5;Need at least five points]'
        r'$onlyForUsers[Nicky;Jeremy;Not authorized]'
        r'$onlyForChannels[333;Wrong channel]'
        r"$ignoreChannels[444;555;❌ That command can't be used in this channel!]"
        r'$onlyNSFW[NSFW channel only]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(
        result.actions.every(
          (action) => action.type == BotCreatorActionType.ifBlock,
        ),
        isTrue,
      );
      expect(result.actions[0].payload['condition.operator'], 'greaterOrEqual');
      expect(
        result.actions[4].payload['condition.variable'],
        '((channel.nsfw))',
      );

      final ignoreThenActions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['thenActions'] as List,
      );
      expect(ignoreThenActions[0]['type'], 'respondWithMessage');
      expect(
        ignoreThenActions[0]['payload']['content'],
        "❌ That command can't be used in this channel!",
      );
    });

    test('compiles for loop blocks into repeated actions', () {
      final result = BdfdCompiler().compile(
        r'$for[2]'
        r'$reply$c[]Loop'
        r'$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.sendMessage);
      expect(result.actions[0].payload['targetType'], 'reply');
      expect(result.actions[1].type, BotCreatorActionType.sendMessage);
      expect(result.actions[1].payload['targetType'], 'reply');
      expect(result.actions[0].payload['content'], 'Loop');
      expect(result.actions[1].payload['content'], 'Loop');
    });

    test('compiles permission and role guards without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$onlyPerms[manageMessages;kickMembers;Missing perms]'
        r'$onlyBotPerms[manageRoles]'
        r'$onlyAdmin[Admins only]'
        r'$checkUserPerms[1234567890;banMembers;Denied]'
        r'$onlyForRoles[Moderator;Role required]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(
        result.actions.every(
          (action) => action.type == BotCreatorActionType.ifBlock,
        ),
        isTrue,
      );

      final onlyPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[0].payload['condition.conditions'] as List,
      );
      expect(onlyPermsConditions.first['variable'], '((member.permissions))');

      final onlyBotPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[1].payload['condition.conditions'] as List,
      );
      expect(onlyBotPermsConditions.first['variable'], '((bot.permissions))');

      expect(result.actions[2].payload['condition.group'], 'or');

      final checkUserPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['condition.conditions'] as List,
      );
      expect(result.actions[3].payload['condition.group'], 'or');
      final checkUserPermsSelfBranch = List<Map<String, dynamic>>.from(
        checkUserPermsConditions.first['conditions'] as List,
      );
      expect(checkUserPermsSelfBranch.first['variable'], '((author.id))');
      expect(checkUserPermsSelfBranch.first['value'], '1234567890');
      expect(
        checkUserPermsConditions[1]['conditions'][0]['variable'],
        'permissions.byId.1234567890',
      );
      expect(
        checkUserPermsConditions[1]['conditions'][0]['value'],
        'banmembers',
      );
      expect(checkUserPermsConditions[2]['variable'], '1234567890');
      expect(checkUserPermsConditions[2]['operator'], 'equals');
      expect(checkUserPermsConditions[2]['value'], '((guild.ownerId))');

      final onlyForRolesConditions = List<Map<String, dynamic>>.from(
        result.actions[4].payload['condition.conditions'] as List,
      );
      expect(onlyForRolesConditions.single['group'], 'or');
    });

    test('supports checkUsersPerms alias', () {
      final result = BdfdCompiler().compile(
        r'$checkUserPerms[1234567890;administrator;Denied]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);

      final conditions = List<Map<String, dynamic>>.from(
        result.actions[0].payload['condition.conditions'] as List,
      );
      expect(result.actions[0].payload['condition.group'], 'or');
      expect(conditions[1]['conditions'][0]['value'], 'administrator');
    });

    test('compiles wave 3 guards without diagnostics', () {
      final result = BdfdCompiler().compile(
        r'$onlyForIDs[111;Denied ID]'
        r'$onlyForRoleIDs[222;Denied role id]'
        r'$onlyForServers[333;Wrong server]'
        r'$onlyForCategories[444;Wrong category]'
        r'$onlyBotChannelPerms[$channelID;manageMessages;Bot missing perms]'
        r'$onlyIfMessageContains[$message;Hello;Hi;Missing text]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(
        result.actions.every(
          (action) => action.type == BotCreatorActionType.ifBlock,
        ),
        isTrue,
      );

      final onlyForIdsConditions = List<Map<String, dynamic>>.from(
        result.actions[0].payload['condition.conditions'] as List,
      );
      expect(onlyForIdsConditions.single['variable'], '((author.id))');

      final onlyForRoleIdsConditions = List<Map<String, dynamic>>.from(
        result.actions[1].payload['condition.conditions'] as List,
      );
      expect(onlyForRoleIdsConditions.single['variable'], '((member.roles))');

      final onlyForServersConditions = List<Map<String, dynamic>>.from(
        result.actions[2].payload['condition.conditions'] as List,
      );
      expect(onlyForServersConditions.single['variable'], '((guild.id))');

      final onlyForCategoriesConditions = List<Map<String, dynamic>>.from(
        result.actions[3].payload['condition.conditions'] as List,
      );
      expect(
        onlyForCategoriesConditions.single['variable'],
        '((channel.parentId))',
      );

      final onlyBotChannelPermsConditions = List<Map<String, dynamic>>.from(
        result.actions[4].payload['condition.conditions'] as List,
      );
      expect(
        onlyBotChannelPermsConditions.single['variable'],
        '((bot.permissions))',
      );

      expect(result.actions[5].payload['condition.group'], 'and');
      final onlyIfContainsConditions = List<Map<String, dynamic>>.from(
        result.actions[5].payload['condition.conditions'] as List,
      );
      expect(onlyIfContainsConditions[0]['variable'], '((message.content))');
      expect(onlyIfContainsConditions[0]['value'], '(?i).*Hello.*');
      expect(onlyIfContainsConditions[1]['value'], '(?i).*Hi.*');
    });

    test('accepts BDFD wiki permission tokens in checkUserPerms', () {
      final result = BdfdCompiler().compile(
        r'$checkUserPerms[1234567890;admin;ban;slashcommands;Denied]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));

      final conditions = List<Map<String, dynamic>>.from(
        result.actions.single.payload['condition.conditions'] as List,
      );
      expect(result.actions.single.payload['condition.group'], 'or');
      final byIdConditions = List<Map<String, dynamic>>.from(
        conditions[1]['conditions'] as List,
      );
      expect(byIdConditions, hasLength(3));
      expect(byIdConditions[0]['value'], 'administrator');
      expect(byIdConditions[1]['value'], 'banmembers');
      expect(byIdConditions[2]['value'], 'useapplicationcommands');
    });

    test('supports inline checkUserPerms in plain text script content', () {
      final result = BdfdCompiler().compile(
        'Admin perms?: \$checkUserPerms[1234567890;administrator]\n',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);

      final content = result.actions[1].payload['content']?.toString() ?? '';
      expect(content, startsWith('Admin perms?: '));
      expect(content, contains('((message.bc_check_user_perms_0))'));
    });

    test('supports checkUserPerms with option user id placeholder', () {
      final result = BdfdCompiler().compile(
        r'$checkUserPerms[((opts.user.id));administrator;Denied]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final conditions = List<Map<String, dynamic>>.from(
        result.actions.single.payload['condition.conditions'] as List,
      );
      expect(
        conditions[1]['conditions'][0]['variable'],
        'permissions.byId.((opts.user.id))',
      );
      expect(conditions[1]['conditions'][0]['value'], 'administrator');
    });

    test('supports userPerms with explicit user id placeholder', () {
      final result = BdfdCompiler().compile(
        r'$reply$c[]Perms: $userPerms[$authorID]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final content =
          result.actions.single.payload['content']?.toString() ?? '';
      expect(
        content,
        contains('((permissions.byId.((author.id))|member.permissions))'),
      );
    });

    test('resolves loop computed variables \$i and \$loopCount', () {
      final result = BdfdCompiler().compile(
        r'$for[3]$reply$i is $loopCount$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].payload['content'], '0 is 1');
      expect(result.actions[1].payload['content'], '1 is 2');
      expect(result.actions[2].payload['content'], '2 is 3');
    });

    test('resolves \$loopIndex as alias for \$i', () {
      final result = BdfdCompiler().compile(
        r'$for[2]$reply$c[]index=$loopIndex$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].payload['content'], 'index=0');
      expect(result.actions[1].payload['content'], 'index=1');
    });

    test('restores loop index after nested loops', () {
      final result = BdfdCompiler().compile(
        r'$for[2]$reply$c[]outer=$i$for[2]$reply$c[]inner=$i$endfor$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].payload['content'], 'outer=0');
      expect(result.actions[1].payload['content'], 'inner=0');
      expect(result.actions[2].payload['content'], 'inner=1');
      expect(result.actions[3].payload['content'], 'outer=1');
      expect(result.actions[4].payload['content'], 'inner=0');
      expect(result.actions[5].payload['content'], 'inner=1');
    });

    test('inlines response-only loop body into pending embed', () {
      final result = BdfdCompiler().compile(
        r'$title[Test]$for[3]$addField[Item $loopCount;val $i;yes]$endfor$color[#FF0000]$footer[Done]',
      );

      expect(result.hasErrors, isFalse);
      // Should produce a SINGLE respondWithMessage action with all fields.
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['embeds'], isList);
      final embeds = payload['embeds'] as List;
      expect(embeds, hasLength(1));
      final embed = embeds[0] as Map<String, dynamic>;
      expect(embed['title'], 'Test');
      expect(embed['color'], '#FF0000');
      expect(embed['footer'], containsPair('text', 'Done'));
      final fields = embed['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'Item 1');
      expect(fields[0]['value'], 'val 0');
      expect(fields[1]['name'], 'Item 2');
      expect(fields[1]['value'], 'val 1');
      expect(fields[2]['name'], 'Item 3');
      expect(fields[2]['value'], 'val 2');
    });

    test('inlines json-mutation loop then reads results in embed', () {
      final result = BdfdCompiler().compile(
        r'$jsonClear$jsonArray[n]$for[5]$jsonArrayAppend[n;$i]$endfor$title[Count: $jsonArrayCount[n]]$description[$jsonJoinArray[n;-]]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final embed =
          (result.actions.single.payload['embeds'] as List)[0]
              as Map<String, dynamic>;
      expect(embed['title'], 'Count: 5');
      expect(embed['description'], '0-1-2-3-4');
    });

    test('C-style for loop with single variable', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 5; i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '1');
      expect(result.actions[4].payload['content'], '4');
    });

    test('C-style for loop with two variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0, j = 10; i <= 3; i++, j--]$reply$i-$j$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].payload['content'], '0-10');
      expect(result.actions[1].payload['content'], '1-9');
      expect(result.actions[2].payload['content'], '2-8');
      expect(result.actions[3].payload['content'], '3-7');
    });

    test('C-style for loop with += and -= updates', () {
      final result = BdfdCompiler().compile(
        r'$for[x = 0; x < 20; x += 5]$reply$x$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '5');
      expect(result.actions[2].payload['content'], '10');
      expect(result.actions[3].payload['content'], '15');
    });

    test('C-style for loop with decrement', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 5; i > 0; i--]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(5));
      expect(result.actions[0].payload['content'], '5');
      expect(result.actions[1].payload['content'], '4');
      expect(result.actions[4].payload['content'], '1');
    });

    test('C-style for loop respects max iteration limit', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 9999; i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      // Capped at 100
      expect(result.actions, hasLength(100));
    });

    test('C-style for loop inlines into embed response', () {
      final result = BdfdCompiler().compile(
        r'$title[Countdown]$for[i = 3; i >= 1; i--]$addField[Step $i;Go;no]$endfor$color[#00FF00]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final embed =
          (result.actions.single.payload['embeds'] as List)[0]
              as Map<String, dynamic>;
      expect(embed['title'], 'Countdown');
      expect(embed['color'], '#00FF00');
      final fields = embed['fields'] as List;
      expect(fields, hasLength(3));
      expect(fields[0]['name'], 'Step 3');
      expect(fields[1]['name'], 'Step 2');
      expect(fields[2]['name'], 'Step 1');
    });

    test('C-style for loop with condition comparing two variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0, j = 3; i < j; i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].payload['content'], '0');
      expect(result.actions[1].payload['content'], '1');
      expect(result.actions[2].payload['content'], '2');
    });

    test('C-style for loop reports diagnostic for invalid init', () {
      final result = BdfdCompiler().compile(
        r'$for[badstuff; i < 5; i++]$reply$c[]x$endfor',
      );

      expect(result.hasErrors, isTrue);
      expect(result.actions, isEmpty);
    });

    test('nested C-style loop restores variables', () {
      final result = BdfdCompiler().compile(
        r'$for[i = 0; i < 2; i++]$reply$c[]outer=$i$for[j = 10; j < 12; j++]$reply$c[]inner=$j$endfor$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(6));
      expect(result.actions[0].payload['content'], 'outer=0');
      expect(result.actions[1].payload['content'], 'inner=10');
      expect(result.actions[2].payload['content'], 'inner=11');
      expect(result.actions[3].payload['content'], 'outer=1');
      expect(result.actions[4].payload['content'], 'inner=10');
      expect(result.actions[5].payload['content'], 'inner=11');
    });

    test('simple runtime loop emits forLoop action for dynamic iterations', () {
      final result = BdfdCompiler().compile(
        r'$for[$args[2]]$reply$c[]hello$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);
      expect(result.actions.single.payload['mode'], 'simple');
      expect(result.actions.single.payload['iterations'], contains('(('));
      final bodyActions = result.actions.single.payload['bodyActions'] as List;
      expect(bodyActions, hasLength(1));
    });

    test('runtime loop can consume a temporary runtime variable', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[$getServerVar[$args[2]]]'
        r'$var[looping;$jsonArrayCount[currencies]]'
        r'$for[$var[looping]]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.forLoop);
      expect(result.actions[2].payload['mode'], 'simple');
      expect(result.actions[2].payload['iterations'], '((temp.looping))');

      final tempPayload = result.actions[1].payload;
      expect(tempPayload['key'], 'looping');
      expect((tempPayload['value'] ?? '').toString(), contains('rtJson_'));
      expect((tempPayload['value'] ?? '').toString(), contains('.json_0'));
    });

    test('simple runtime loop with \$loop alias', () {
      final result = BdfdCompiler().compile(
        r'$loop[$args[1]]$reply$c[]hi$endloop',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);
      expect(result.actions.single.payload['mode'], 'simple');
    });

    test(
      'C-style runtime loop emits forLoop action when condition has placeholder',
      () {
        final result = BdfdCompiler().compile(
          r'$for[i=0;i<$args[2];i++]$reply$i$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        final action = result.actions.single;
        expect(action.type, BotCreatorActionType.forLoop);
        expect(action.payload['mode'], 'cstyle');
        expect(action.payload['init'], 'i=0');
        expect(action.payload['condition'], contains('(('));
        expect(action.payload['update'], 'i++');
        expect(action.payload['varNames'], contains('i'));
        final bodyActions = action.payload['bodyActions'] as List;
        expect(bodyActions, hasLength(1));
        // Body should contain loop variable placeholder.
        final bodyPayload = bodyActions[0] as Map;
        final content = (bodyPayload['payload'] as Map)['content'] as String;
        expect(content, contains('((_loop.var.i))'));
      },
    );

    test('C-style runtime loop with runtime init value', () {
      final result = BdfdCompiler().compile(
        r'$for[i=$args[0];i<$args[2];i++]$reply$i$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      final action = result.actions.single;
      expect(action.type, BotCreatorActionType.forLoop);
      expect(action.payload['mode'], 'cstyle');
      expect(action.payload['init'], contains('(('));
    });

    test('static loops still unrolled at compile-time (backward compat)', () {
      final result = BdfdCompiler().compile(r'$for[3]$reply$c[]x$endfor');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      // Should NOT be a forLoop action – should be unrolled.
      for (final action in result.actions) {
        expect(action.type, isNot(BotCreatorActionType.forLoop));
      }
    });

    test(
      'runtime loop body uses ((_loop.index)) and ((_loop.count)) placeholders',
      () {
        final result = BdfdCompiler().compile(
          r'$for[$args[0]]$reply$i is $loopCount$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        final action = result.actions.single;
        expect(action.type, BotCreatorActionType.forLoop);
        final bodyActions = action.payload['bodyActions'] as List;
        final content = (bodyActions[0] as Map)['payload']['content'] as String;
        expect(content, contains('((_loop.index))'));
        expect(content, contains('((_loop.count))'));
      },
    );

    test('runtime loop body preserves temp variable actions', () {
      final result = BdfdCompiler().compile(
        r'$for[$message[1]]$var[current;$i]$reply$var[current]$endfor',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.forLoop);

      final bodyActions = List<Map<String, dynamic>>.from(
        result.actions.single.payload['bodyActions'] as List? ?? const [],
      );
      expect(bodyActions, hasLength(2));
      expect(bodyActions[0]['type'], 'setTemporaryVariable');
      expect(bodyActions[1]['type'], 'sendMessage');
      expect(
        (bodyActions[1]['payload'] as Map<String, dynamic>)['targetType'],
        'reply',
      );

      final tempPayload = Map<String, dynamic>.from(
        bodyActions[0]['payload'] as Map? ?? const <String, dynamic>{},
      );
      expect(tempPayload['key'], 'current');
      expect(tempPayload['value'], '((_loop.index))');
      expect(
        (bodyActions[1]['payload'] as Map<String, dynamic>)['content'],
        '((temp.current))',
      );
    });

    test(
      'weighted roll style loop keeps nested json and if blocks runtime',
      () {
        final result = BdfdCompiler().compile(
          r'$jsonParse[$getServerVar[items_db]]'
          r'$var[in;items]'
          r'$var[target;sword]'
          r'$var[looping;$jsonArrayCount[$var[in]]]'
          r'$for[$var[looping]]'
          r'$if[$json[$var[in];$i;name]==$var[target]]'
          r'$reply$json[$var[in];$i;weight]'
          r'$endif'
          r'$endfor',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(6));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[1].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[1].payload['key'], 'in');
        expect(
          result.actions[2].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[2].payload['key'], 'target');
        expect(result.actions[3].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[4].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[4].payload['key'], 'looping');
        expect(result.actions[5].type, BotCreatorActionType.forLoop);
        expect(result.actions[5].payload['iterations'], '((temp.looping))');

        final loopingValue =
            (result.actions[4].payload['value'] ?? '').toString();
        expect(loopingValue, contains('rtJson_'));
        expect(loopingValue, contains('.json_0'));

        final bodyActions = List<Map<String, dynamic>>.from(
          result.actions[5].payload['bodyActions'] as List? ?? const [],
        );
        expect(bodyActions, hasLength(2));
        expect(bodyActions[0]['type'], 'runtimeJsonBlock');
        expect(bodyActions[1]['type'], 'ifBlock');

        final ifPayload = Map<String, dynamic>.from(
          bodyActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        final conditionVariable =
            (ifPayload['condition.variable'] ?? '').toString();
        expect(conditionVariable, contains('rtJson_'));
        expect(conditionVariable, contains('.json_0'));
        expect(ifPayload['condition.value'], '((temp.target))');

        final thenActions = List<Map<String, dynamic>>.from(
          ifPayload['thenActions'] as List? ?? const [],
        );
        expect(thenActions, hasLength(2));
        expect(thenActions[0]['type'], 'runtimeJsonBlock');
        expect(thenActions[1]['type'], 'sendMessage');
        expect(
          (thenActions[1]['payload'] as Map<String, dynamic>)['targetType'],
          'reply',
        );

        final weightContent =
            (thenActions[1]['payload'] as Map<String, dynamic>)['content']
                .toString();
        expect(weightContent, contains('rtJson_'));
        expect(weightContent, contains('.json_'));
      },
    );

    test(
      'full weighted roll compiles accumulation, random threshold, and winner selection',
      () {
        final result = BdfdCompiler().compile(
          r'$jsonParse[$getServerVar[items_db]]'
          r'$var[in;items]'
          r'$var[looping;$jsonArrayCount[$var[in]]]'
          r'$var[totalWeight;0]'
          r'$for[$var[looping]]'
          r'$var[itemWeight;$json[$var[in];$i;weight]]'
          r'$var[totalWeight;$calculate[$var[totalWeight]+$var[itemWeight]]]'
          r'$endfor'
          r'$var[roll;$random[1;10]]'
          r'$var[currentWeight;0]'
          r'$for[$var[looping]]'
          r'$var[itemName;$json[$var[in];$i;name]]'
          r'$var[itemWeight;$json[$var[in];$i;weight]]'
          r'$var[currentWeight;$calculate[$var[currentWeight]+$var[itemWeight]]]'
          r'$if[$var[roll]<=$var[currentWeight]]'
          r'$var[winner;$var[itemName]]'
          r'$reply$var[winner]'
          r'$endif'
          r'$endfor',
        );

        expect(result.hasErrors, isFalse);

        final topLevelLoops = result.actions
            .where((action) => action.type == BotCreatorActionType.forLoop)
            .toList(growable: false);
        expect(topLevelLoops, hasLength(2));

        final topLevelTempKeys = result.actions
            .where(
              (action) =>
                  action.type == BotCreatorActionType.setTemporaryVariable,
            )
            .map((action) => (action.payload['key'] ?? '').toString())
            .toList(growable: false);
        expect(
          topLevelTempKeys,
          containsAll(<String>[
            'in',
            'looping',
            'totalWeight',
            'roll',
            'currentWeight',
          ]),
        );

        final rollAction = result.actions.firstWhere(
          (action) =>
              action.type == BotCreatorActionType.setTemporaryVariable &&
              action.payload['key'] == 'roll',
        );
        final rollValue = (rollAction.payload['value'] ?? '').toString();
        expect(rollValue, contains('((random[1;10]))'));

        final accumulationBody = List<Map<String, dynamic>>.from(
          topLevelLoops[0].payload['bodyActions'] as List? ?? const [],
        );
        expect(
          accumulationBody.any(
            (action) => action['type'] == 'runtimeJsonBlock',
          ),
          isTrue,
        );
        final accumulationTempKeys = accumulationBody
            .where((action) => action['type'] == 'setTemporaryVariable')
            .map(
              (action) =>
                  ((action['payload'] as Map?)?['key'] ?? '').toString(),
            )
            .toList(growable: false);
        expect(
          accumulationTempKeys,
          containsAll(<String>['itemWeight', 'totalWeight']),
        );

        final selectionBody = List<Map<String, dynamic>>.from(
          topLevelLoops[1].payload['bodyActions'] as List? ?? const [],
        );
        expect(
          selectionBody.any((action) => action['type'] == 'runtimeJsonBlock'),
          isTrue,
        );
        final selectionTempKeys = selectionBody
            .where((action) => action['type'] == 'setTemporaryVariable')
            .map(
              (action) =>
                  ((action['payload'] as Map?)?['key'] ?? '').toString(),
            )
            .toList(growable: false);
        expect(
          selectionTempKeys,
          containsAll(<String>['itemName', 'itemWeight', 'currentWeight']),
        );

        final winnerIfPayload = Map<String, dynamic>.from(
          selectionBody.firstWhere(
                    (action) => action['type'] == 'ifBlock',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );
        expect(winnerIfPayload['condition.variable'], '((temp.roll))');
        expect(winnerIfPayload['condition.value'], '((temp.currentWeight))');

        final winnerThenActions = List<Map<String, dynamic>>.from(
          winnerIfPayload['thenActions'] as List? ?? const [],
        );
        final winnerTempKeys = winnerThenActions
            .where((action) => action['type'] == 'setTemporaryVariable')
            .map(
              (action) =>
                  ((action['payload'] as Map?)?['key'] ?? '').toString(),
            )
            .toList(growable: false);
        expect(winnerTempKeys, contains('winner'));

        final winnerReply = Map<String, dynamic>.from(
          winnerThenActions.firstWhere(
                    (action) => action['type'] == 'sendMessage',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );
        expect(winnerReply['content'], '((temp.winner))');
      },
    );

    test('standalone if hoists runtime json condition before if action', () {
      final result = BdfdCompiler().compile(
        r'$jsonParse[$getServerVar[items_db]]'
        r'$var[in;items]'
        r'$if[$json[$var[in];$message[1];enabled]==true;$reply$c[]enabled;$reply$c[]disabled]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[3].type, BotCreatorActionType.ifBlock);

      final ifPayload = result.actions[3].payload;
      expect(
        (ifPayload['condition.variable'] ?? '').toString(),
        contains('rtJson_'),
      );
      expect(
        (ifPayload['condition.variable'] ?? '').toString(),
        contains('.json_0'),
      );
      expect(ifPayload['condition.value'], 'true');

      final thenActions = List<Map<String, dynamic>>.from(
        ifPayload['thenActions'] as List? ?? const [],
      );
      final elseActions = List<Map<String, dynamic>>.from(
        ifPayload['elseActions'] as List? ?? const [],
      );
      expect(
        (thenActions.single['payload'] as Map<String, dynamic>)['content'],
        'enabled',
      );
      expect(
        (elseActions.single['payload'] as Map<String, dynamic>)['content'],
        'disabled',
      );
    });

    test(
      'loot flow compiles tiers, enabled gate, fallback, and first-win stop',
      () {
        final result = BdfdCompiler().compile(
          r'$jsonParse[$getServerVar[items_db]]'
          r'$var[in;items]'
          r'$var[looping;$jsonArrayCount[$var[in]]]'
          r'$var[roll;$random[1;10]]'
          r'$var[currentWeight;0]'
          r'$var[winner;]'
          r'$for[$var[looping]]'
          r'$if[$json[$var[in];$i;enabled]==true]'
          r'$if[$json[$var[in];$i;rarity]==legendary]'
          r'$var[bonus;2]'
          r'$else'
          r'$var[bonus;0]'
          r'$endif'
          r'$var[itemWeight;$json[$var[in];$i;weight]]'
          r'$var[currentWeight;$calculate[$var[currentWeight]+$var[itemWeight]+$var[bonus]]]'
          r'$if[$var[winner]==]'
          r'$if[$var[roll]<=$var[currentWeight]]'
          r'$var[winner;$json[$var[in];$i;name]]'
          r'$reply$var[winner]'
          r'$stop'
          r'$endif'
          r'$endif'
          r'$endif'
          r'$endfor'
          r'$if[$var[winner]==]'
          r'$reply$c[]fallback_common'
          r'$endif',
        );

        expect(result.hasErrors, isFalse);

        final topLevelLoops = result.actions
            .where((action) => action.type == BotCreatorActionType.forLoop)
            .toList(growable: false);
        expect(topLevelLoops, hasLength(1));

        final fallbackIf = result.actions.lastWhere(
          (action) => action.type == BotCreatorActionType.ifBlock,
        );
        expect(fallbackIf.payload['condition.variable'], '((temp.winner))');
        expect(fallbackIf.payload['condition.value'], '');
        final fallbackThen = List<Map<String, dynamic>>.from(
          fallbackIf.payload['thenActions'] as List? ?? const [],
        );
        expect(
          (fallbackThen.single['payload'] as Map<String, dynamic>)['content'],
          'fallback_common',
        );

        final loopBody = List<Map<String, dynamic>>.from(
          topLevelLoops.single.payload['bodyActions'] as List? ?? const [],
        );
        expect(
          loopBody.any((action) => action['type'] == 'runtimeJsonBlock'),
          isTrue,
        );
        final enabledIf = Map<String, dynamic>.from(
          loopBody.firstWhere(
                    (action) => action['type'] == 'ifBlock',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );
        expect(
          (enabledIf['condition.variable'] ?? '').toString(),
          contains('rtJson_'),
        );
        expect(enabledIf['condition.value'], 'true');

        final enabledThen = List<Map<String, dynamic>>.from(
          enabledIf['thenActions'] as List? ?? const [],
        );
        expect(
          enabledThen.any((action) => action['type'] == 'ifBlock'),
          isTrue,
        );
        expect(
          enabledThen.any(
            (action) =>
                action['type'] == 'setTemporaryVariable' &&
                ((action['payload'] as Map?)?['key'] ?? '') == 'currentWeight',
          ),
          isTrue,
        );

        final winnerGate = Map<String, dynamic>.from(
          enabledThen
              .where((action) => action['type'] == 'ifBlock')
              .map(
                (action) => Map<String, dynamic>.from(
                  action['payload'] as Map? ?? const <String, dynamic>{},
                ),
              )
              .firstWhere(
                (payload) => payload['condition.variable'] == '((temp.winner))',
              ),
        );
        final rollGate = Map<String, dynamic>.from(
          List<Map<String, dynamic>>.from(
                    winnerGate['thenActions'] as List? ?? const [],
                  ).firstWhere(
                    (action) => action['type'] == 'ifBlock',
                  )['payload']
                  as Map? ??
              const <String, dynamic>{},
        );
        expect(rollGate['condition.variable'], '((temp.roll))');
        expect(rollGate['condition.value'], '((temp.currentWeight))');

        final winnerThen = List<Map<String, dynamic>>.from(
          rollGate['thenActions'] as List? ?? const [],
        );
        expect(
          winnerThen.any(
            (action) =>
                action['type'] == 'setTemporaryVariable' &&
                ((action['payload'] as Map?)?['key'] ?? '') == 'winner',
          ),
          isTrue,
        );
        expect(
          winnerThen.any((action) => action['type'] == 'stop'),
          isTrue,
        );
      },
    );
  });

  group('temporary variables via \$var', () {
    test('set and retrieve a temporary variable', () {
      final result = BdfdCompiler().compile(
        r'$var[name;World]Hello $var[name]!',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[0].payload['key'], 'name');
      expect(result.actions[0].payload['value'], 'World');
      expect(result.actions[1].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[1].payload['content'], 'Hello ((temp.name))!');
    });

    test('overwrite a temporary variable', () {
      final result = BdfdCompiler().compile(
        r'$var[x;first]$var[x;second]Value: $var[x]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[0].payload['value'], 'first');
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[1].payload['value'], 'second');
      expect(result.actions[2].payload['content'], 'Value: ((temp.x))');
    });

    test('multiple independent temporary variables', () {
      final result = BdfdCompiler().compile(
        r'$var[a;1]$var[b;2]$var[a]+$var[b]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].payload['content'], '((temp.a))+((temp.b))');

      final runtimeVariables = <String, String>{'temp.a': '1', 'temp.b': '2'};
      expect(
        resolveTemplatePlaceholders(
          result.actions[2].payload['content'] as String,
          runtimeVariables,
        ),
        '1+2',
      );
    });

    test('unknown temp var falls back to runtime placeholder', () {
      final result = BdfdCompiler().compile(r'Value: $var[unknown]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Value: ((temp.unknown))',
      );
    });

    test('temp var set produces no visible output', () {
      final result = BdfdCompiler().compile(r'$var[x;hello]$var[x]');

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[1].payload['content'], '((temp.x))');
      expect(
        resolveTemplatePlaceholders(
          result.actions[1].payload['content'] as String,
          <String, String>{'temp.x': 'hello'},
        ),
        'hello',
      );
    });

    test('temp var with computed value from inline function', () {
      final result = BdfdCompiler().compile(
        r'$var[upper;$toUpperCase[hello]]Result: $var[upper]',
      );

      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[0].payload['value'], 'HELLO');
      expect(result.actions[1].payload['content'], 'Result: ((temp.upper))');
    });

    test(
      'runtime inline math stays dynamic and temp vars persist through branches',
      () {
        final result = BdfdCompiler().compile(
          r'$if[$isbot[$authorID]==false]'
          '\n'
          r' $enabledecimals[yes]'
          '\n'
          r' $var[toadd;$multi[$charcount[$message];0.5]]'
          '\n'
          r' $channelSendMessage[$channelID;$message, charcount $charcount[$message], after mult $var[toadd]]'
          '\n'
          r' $if[$var[toadd]>15]'
          '\n'
          r'  $channelSendMessage[$channelID;over 15, clmaped]'
          '\n'
          r'  $var[toadd;15]'
          '\n'
          r' $endif'
          '\n'
          r' $channelSendMessage[$channelID;you have been given $var[toadd] xp]'
          '\n'
          r' $setUserVar[xp;$calculate[$getUserVar[xp]+$var[toadd]]]'
          '\n'
          r' $channelSendMessage[$channelID;new xp $getUserVar[xp]]'
          '\n'
          r'$endif',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));
        expect(result.actions.single.type, BotCreatorActionType.ifBlock);

        final thenActions = List<Map<String, dynamic>>.from(
              result.actions.single.payload['thenActions'] as List,
            )
            .map((json) => Action.fromJson(Map<String, dynamic>.from(json)))
            .toList(growable: false);
        expect(thenActions.map((action) => action.type), <BotCreatorActionType>[
          BotCreatorActionType.setTemporaryVariable,
          BotCreatorActionType.sendMessage,
          BotCreatorActionType.ifBlock,
          BotCreatorActionType.sendMessage,
          BotCreatorActionType.setScopedVariable,
          BotCreatorActionType.sendMessage,
        ]);

        final tempSetValue = thenActions[0].payload['value'] as String;
        expect(tempSetValue, contains('((multi['));

        final runtimeVariables = <String, String>{
          'message.content': 'bzbd',
          'author.isBot': 'false',
        };
        final resolvedTemp = resolveTemplatePlaceholders(
          tempSetValue,
          runtimeVariables,
        );
        expect(resolvedTemp, '2');
        runtimeVariables['temp.toadd'] = resolvedTemp;

        final previewContent = thenActions[1].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(previewContent, runtimeVariables),
          'bzbd, charcount 4, after mult 2',
        );

        final clampCondition =
            thenActions[2].payload['condition.variable'] as String;
        expect(
          resolveTemplatePlaceholders(clampCondition, runtimeVariables),
          '2',
        );

        final awardContent = thenActions[3].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(awardContent, runtimeVariables),
          'you have been given 2 xp',
        );

        final setXpValue = thenActions[4].payload['value'] as String;
        final resolvedXp = resolveTemplatePlaceholders(
          setXpValue,
          runtimeVariables,
        );
        expect(resolvedXp, '2');

        runtimeVariables['user.bc_xp'] = resolvedXp;
        final newXpContent = thenActions[5].payload['content'] as String;
        expect(
          resolveTemplatePlaceholders(newXpContent, runtimeVariables),
          'new xp 2',
        );
      },
    );

    test(
      'runtime uppercase keeps placeholder keys intact until resolution',
      () {
        final result = BdfdCompiler().compile(
          r'$reply$toUpperCase[$username]',
        );

        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final content = result.actions.single.payload['content'] as String;
        expect(content, '((touppercase[((user.username))]))');
        expect(
          resolveTemplatePlaceholders(content, <String, String>{
            'user.username': 'niek dev',
          }),
          'NIEK DEV',
        );
      },
    );
  });

  group(r'$callWorkflow', () {
    test('simple call with name only', () {
      final result = BdfdCompiler().compile(r'$callWorkflow[myFlow]');
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runWorkflow);
      expect(result.actions[0].payload['workflowName'], 'myFlow');
      expect(result.actions[0].payload.containsKey('arguments'), isFalse);
    });

    test('call with positional arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;hello;world]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['workflowName'], 'myFlow');
      expect(result.actions[0].payload['arguments'], {
        '1': 'hello',
        '2': 'world',
      });
    });

    test('call with key=value arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;user=Alice;count=3]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {
        'user': 'Alice',
        'count': '3',
      });
    });

    test('call with mixed positional and key=value arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;hello;key=val]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {
        '1': 'hello',
        'key': 'val',
      });
    });

    test('missing workflow name emits diagnostic', () {
      final result = BdfdCompiler().compile(r'$callWorkflow[]');
      expect(result.actions, isEmpty);
      expect(result.diagnostics, isNotEmpty);
    });

    test('arguments can use inline BDFD functions', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow;$toUpperCase[hello]]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].payload['arguments'], {'1': 'HELLO'});
    });
  });

  group(r'$workflowResponse', () {
    test('produces placeholder with property path', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'Result: $workflowResponse[status.code]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response.status.code))'),
      );
    });

    test('produces placeholder without arguments', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'Result: $workflowResponse',
      );
      expect(result.diagnostics, isEmpty);
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response))'),
      );
    });

    test('emits diagnostic when no preceding callWorkflow', () {
      final result = BdfdCompiler().compile(
        r'Response: $workflowResponse[data]',
      );
      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.first.message,
        contains('requires a preceding'),
      );
    });

    test('tracks latest callWorkflow across multiple calls', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[flowA]'
        '\n'
        r'$callWorkflow[flowB]'
        '\n'
        r'Result: $workflowResponse[output]',
      );
      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      // Both callWorkflow actions have distinct keys
      expect(result.actions[0].key, '_bdfd_callworkflow_0');
      expect(result.actions[1].key, '_bdfd_callworkflow_1');
      expect(
        result.actions[2].payload['content'],
        contains('((workflow.response.output))'),
      );
    });

    test('can use inline function in property argument', () {
      final result = BdfdCompiler().compile(
        r'$callWorkflow[myFlow]'
        '\n'
        r'$workflowResponse[$toUpperCase[key]]',
      );
      expect(result.diagnostics, isEmpty);
      expect(
        result.actions[1].payload['content'],
        contains('((workflow.response.KEY))'),
      );
    });
  });

  group(r'$eval', () {
    test('emits runBdfdScript action with script content', () {
      final result = BdfdCompiler().compile(r'$eval[$username]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], r'((user.username))');
    });

    test('passes through runtime placeholders in script content', () {
      final result = BdfdCompiler().compile(r'$eval[((opts.script))]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], '((opts.script))');
    });

    test('flushes pending response before eval', () {
      final result = BdfdCompiler().compile(
        'Hello\n'
        r'$eval[$username]',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[0].payload['content'], contains('Hello'));
      expect(result.actions[1].type, BotCreatorActionType.runBdfdScript);
    });

    test('eval with complex BDFD content', () {
      final result = BdfdCompiler().compile(r'$eval[$reply$c[]Hello $username]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
    });

    test('eval with empty argument', () {
      final result = BdfdCompiler().compile(r'$eval[]');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.runBdfdScript);
      expect(result.actions[0].payload['scriptContent'], '');
    });
  });

  group(r'$debug', () {
    test('emits debugProfile action', () {
      final result = BdfdCompiler().compile(r'$debug');
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(1));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
    });

    test('flushes pending response before debug', () {
      final result = BdfdCompiler().compile(
        'Hello\n'
        r'$debug',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.respondWithMessage);
      expect(result.actions[0].payload['content'], contains('Hello'));
      expect(result.actions[1].type, BotCreatorActionType.debugProfile);
    });

    test('produces correct action sequence with other functions', () {
      final result = BdfdCompiler().compile(
        r'$debug'
        '\n'
        r'$reply$c[]pong',
      );
      expect(result.hasErrors, isFalse);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
      expect(result.actions[1].type, BotCreatorActionType.sendMessage);
      expect(result.actions[1].payload['targetType'], 'reply');
    });

    test('carries compilation timing metadata', () {
      final result = BdfdCompiler().compile(r'$debug');
      expect(result.hasErrors, isFalse);
      final debugAction = result.actions[0];
      expect(debugAction.payload['compilationMs'], isA<int>());
      expect(debugAction.payload['sourceLength'], equals(6));
      expect(debugAction.payload['actionCount'], equals(1));
    });

    test('loop actions carry iteration metadata', () {
      final result = BdfdCompiler().compile(
        r'$debug'
        '\n'
        r'$for[3]'
        '\n'
        r'  $channelSendMessage[$channelID;iter $i]'
        '\n'
        r'$endfor',
      );
      expect(result.hasErrors, isFalse);
      // debugProfile + 3 sendMessage
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.debugProfile);
      for (var i = 1; i <= 3; i++) {
        final a = result.actions[i];
        expect(a.type, BotCreatorActionType.sendMessage);
        expect(a.payload['_debugLoopDepth'], equals(1));
        expect(a.payload['_debugLoopIteration'], equals(i - 1));
      }
    });

    test(
      'recursive awaitFunc produces different snapshots on each compilation',
      () async {
        // Simulate a callback command that echoes and re-arms:
        //   $message
        //   $awaitFunc[say]
        const script = r'$message$awaitFunc[say]';

        // First compilation (initial command execution)
        final first = BdfdCompiler().compile(script);
        expect(first.hasErrors, isFalse);
        final firstSet = first.actions.firstWhere(
          (a) => a.type == BotCreatorActionType.setScopedVariable,
        );
        expect(firstSet.payload['key'], 'await_say');
        expect(firstSet.payload['valueType'], 'json');
        final firstJson = firstSet.payload['jsonValue'] as String;
        final firstResolved = resolveTemplatePlaceholders(firstJson, {
          'author.id': '111',
          'channel.id': '222',
        });
        final firstValue = jsonDecode(firstResolved) as Map<String, dynamic>;
        final firstSnapshot = awaitedRegistrationSnapshot(firstValue);

        // Tiny delay so DateTime.now() differs
        await Future<void>.delayed(const Duration(milliseconds: 2));

        // Second compilation (callback re-arms)
        BdfdCompiler.clearCache();
        final second = BdfdCompiler().compile(script);
        expect(second.hasErrors, isFalse);
        final secondSet = second.actions.firstWhere(
          (a) => a.type == BotCreatorActionType.setScopedVariable,
        );
        final secondJson = secondSet.payload['jsonValue'] as String;
        final secondResolved = resolveTemplatePlaceholders(secondJson, {
          'author.id': '111',
          'channel.id': '222',
        });
        final secondValue = jsonDecode(secondResolved) as Map<String, dynamic>;
        final secondSnapshot = awaitedRegistrationSnapshot(secondValue);

        // Snapshots MUST differ for re-arm to be detected
        expect(
          secondSnapshot,
          isNot(firstSnapshot),
          reason:
              'Each compilation must produce a unique createdAt so that '
              'the re-arm check detects the change.',
        );
      },
    );

    test(
      'pre-compiled awaitFunc actions produce identical snapshots (no re-arm)',
      () {
        // When using workflow-mode (pre-compiled actions), the same action
        // JSON is reused. The createdAt is static → snapshots are identical
        // → re-arm is NOT detected.
        const script = r'$awaitFunc[echo]';
        final compiled = BdfdCompiler().compile(script);
        expect(compiled.hasErrors, isFalse);
        final action = compiled.actions.single;
        // Serialize to JSON and deserialize (simulating workflow-mode storage)
        final actionJson = action.toJson();

        final firstResolved = resolveTemplatePlaceholders(
          (actionJson['payload'] as Map)['jsonValue'] as String,
          {'author.id': '111', 'channel.id': '222'},
        );
        final firstSnapshot = awaitedRegistrationSnapshot(
          jsonDecode(firstResolved),
        );

        // Reuse same serialized action JSON (workflow mode)
        final secondResolved = resolveTemplatePlaceholders(
          (actionJson['payload'] as Map)['jsonValue'] as String,
          {'author.id': '111', 'channel.id': '222'},
        );
        final secondSnapshot = awaitedRegistrationSnapshot(
          jsonDecode(secondResolved),
        );

        // Same static payload → identical snapshots → no re-arm!
        expect(
          secondSnapshot,
          equals(firstSnapshot),
          reason:
              'Pre-compiled actions have a static createdAt, so '
              'snapshots are identical and re-arm is not detected.',
        );
      },
    );
  });
}
