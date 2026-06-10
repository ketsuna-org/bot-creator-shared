import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdCompiler', () {
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
        contains('((userperms[((author.id));-1;, ]))'),
      );
    });
  });
}
