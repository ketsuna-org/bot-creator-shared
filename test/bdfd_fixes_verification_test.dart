import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/utils/embed_fields.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('BDFD Fixes Verification', () {
    group(r'$addField Dynamic Freezing & Resolution', () {
      test(r'compiles $addField with dynamic inline raw string', () {
        final result = BdfdCompiler().compile(r'$title[Test]$addField[Name;Value;yes]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        final embeds = action.payload['embeds'] as List;
        expect(embeds, hasLength(1));

        final embed = embeds.first;
        final fields = embed['fields'] as List;
        expect(fields, hasLength(1));
        expect(fields.first['inline'], 'yes');
      });

      test(r'resolves $addField inline argument dynamically in buildResolvedEmbedFields', () {
        final staticEmbedJson = {
          'fields': [
            {'name': 'Field 1', 'value': 'Val 1', 'inline': 'yes'},
            {'name': 'Field 2', 'value': 'Val 2', 'inline': 'no'},
            {'name': 'Field 3', 'value': 'Val 3', 'inline': '((dynamicInline))'},
          ]
        };

        // Case 1: Dynamic inline resolves to 'yes'
        final resolvedFields1 = buildResolvedEmbedFields(
          embedJson: staticEmbedJson,
          resolve: (input) => resolveTemplatePlaceholders(input, {'dynamicInline': 'yes'}),
        );
        expect(resolvedFields1, hasLength(3));
        expect(resolvedFields1[0].isInline, isTrue);
        expect(resolvedFields1[1].isInline, isFalse);
        expect(resolvedFields1[2].isInline, isTrue);

        // Case 2: Dynamic inline resolves to 'no'
        final resolvedFields2 = buildResolvedEmbedFields(
          embedJson: staticEmbedJson,
          resolve: (input) => resolveTemplatePlaceholders(input, {'dynamicInline': 'no'}),
        );
        expect(resolvedFields2, hasLength(3));
        expect(resolvedFields2[0].isInline, isTrue);
        expect(resolvedFields2[1].isInline, isFalse);
        expect(resolvedFields2[2].isInline, isFalse);
      });
    });

    group(r'$giveRoles & $takeRoles Multi-Role Correctness', () {
      test(r'compiles $giveRoles with first arg as userId and loops roles from index 1', () {
        final result = BdfdCompiler().compile(r'$giveRoles[$authorID;111;222;333]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(3));

        expect(result.actions[0].type, BotCreatorActionType.addRole);
        expect(result.actions[0].payload['userId'], '((author.id))');
        expect(result.actions[0].payload['roleId'], '111');

        expect(result.actions[1].type, BotCreatorActionType.addRole);
        expect(result.actions[1].payload['userId'], '((author.id))');
        expect(result.actions[1].payload['roleId'], '222');

        expect(result.actions[2].type, BotCreatorActionType.addRole);
        expect(result.actions[2].payload['userId'], '((author.id))');
        expect(result.actions[2].payload['roleId'], '333');
      });

      test(r'compiles $takeRoles with first arg as userId and loops roles from index 1', () {
        final result = BdfdCompiler().compile(r'$takeRoles[$authorID;444;555]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(2));

        expect(result.actions[0].type, BotCreatorActionType.removeRole);
        expect(result.actions[0].payload['userId'], '((author.id))');
        expect(result.actions[0].payload['roleId'], '444');

        expect(result.actions[1].type, BotCreatorActionType.removeRole);
        expect(result.actions[1].payload['userId'], '((author.id))');
        expect(result.actions[1].payload['roleId'], '555');
      });
    });

    group(r'$allowMention / $allowUserMentions / $allowRoleMentions AllowedMentions Payloads', () {
      test(r'$allowMention enables all mentions', () {
        final result = BdfdCompiler().compile(r'Hello$allowMention');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        final allowed = action.payload['allowedMentions'];
        expect(allowed, isNotNull);
        expect(allowed['parse'], containsAll(['users', 'roles']));
      });

      test(r'$allowUserMentions restrains to specified user IDs and retains defaults', () {
        final result = BdfdCompiler().compile(r'Hello$allowUserMentions[123;456]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        final allowed = action.payload['allowedMentions'];
        expect(allowed, isNotNull);
        expect(allowed['users'], ['123', '456']);
        expect(allowed['parse'], contains('roles'));
        expect(allowed['parse'], isNot(contains('users')));
      });

      test(r'$allowRoleMentions restrains to specified role IDs and retains defaults', () {
        final result = BdfdCompiler().compile(r'Hello$allowRoleMentions[789;999]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        final allowed = action.payload['allowedMentions'];
        expect(allowed, isNotNull);
        expect(allowed['roles'], ['789', '999']);
        expect(allowed['parse'], contains('users'));
        expect(allowed['parse'], isNot(contains('roles')));
      });
    });

    group(r'$addReactions & $addMessageReactions Target lastSentMessageId', () {
      test(r'compiles $addReactions targeting ((lastSentMessageId))', () {
        final result = BdfdCompiler().compile(r'Send this$addReactions[🔥;✨;🌟]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(2));

        final reactAction = result.actions[1];
        expect(reactAction.type, BotCreatorActionType.addReaction);
        expect(reactAction.payload['messageId'], '((lastSentMessageId))');
        expect(reactAction.payload['emojis'], ['🔥', '✨', '🌟']);
      });

      test(r'compiles $addMessageReactions targeting specified channel/message', () {
        final result = BdfdCompiler().compile(r'Send this$addMessageReactions[999999;123456789;👍;👎]');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(2));

        final reactAction = result.actions[1];
        expect(reactAction.type, BotCreatorActionType.addReaction);
        expect(reactAction.payload['channelId'], '999999');
        expect(reactAction.payload['messageId'], '123456789');
        expect(reactAction.payload['emojis'], ['👍', '👎']);
      });
    });

    group(r'$botLeave Guild Leave Support', () {
      test(r'compiles $botLeave to leaveGuild action', () {
        final result = BdfdCompiler().compile(r'$botLeave');
        expect(result.hasErrors, isFalse);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        expect(action.type, BotCreatorActionType.leaveGuild);
      });
    });
  });
}
