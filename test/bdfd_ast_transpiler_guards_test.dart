import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler — threads, guards & permissions', () {
    test('transpiles startThread inline with returned ID placeholder', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('New thread: '),
            BdfdFunctionCallAst(
              name: r'$startThread',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Cool Thread')],
                <BdfdAstNode>[BdfdTextAst('123')],
                <BdfdAstNode>[BdfdTextAst('')],
                <BdfdAstNode>[BdfdTextAst('1440')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.createThread);
      expect(result.actions.first.payload['name'], 'Cool Thread');
      expect(result.actions.first.payload['channelId'], '123');
      expect(
        result.actions.last.payload['content'],
        'New thread: ((thread.lastId))',
      );
    });

    test('transpiles editThread and thread member functions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$editThread',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[BdfdTextAst('Renamed')],
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('!unchanged')],
                <BdfdAstNode>[BdfdTextAst('!unchanged')],
                <BdfdAstNode>[BdfdTextAst('5')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$threadAddMember',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[BdfdTextAst('999')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$threadRemoveMember',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[BdfdTextAst('999')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.updateChannel);
      expect(result.actions[0].payload['channelId'], '555');
      expect(result.actions[0].payload['name'], 'Renamed');
      expect(result.actions[0].payload['archived'], false);
      expect(result.actions[0].payload['slowmode'], '5');
      expect(result.actions[1].type, BotCreatorActionType.addThreadMember);
      expect(result.actions[2].type, BotCreatorActionType.removeThreadMember);
    });

    test('transpiles guard helpers to ifBlock and stopUnless actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyIf',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>10')],
                <BdfdAstNode>[BdfdTextAst('Too low')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForUsers',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Nicky')],
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
                <BdfdAstNode>[BdfdTextAst('Denied user')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForChannels',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('333')],
                <BdfdAstNode>[BdfdTextAst('Wrong channel')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$ignoreChannels',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('444')],
                <BdfdAstNode>[BdfdTextAst('555')],
                <BdfdAstNode>[
                  BdfdTextAst("❌ That command can't be used in this channel!"),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyNSFW',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('NSFW only')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(5));

      final onlyIfPayload = result.actions[0].payload;
      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(onlyIfPayload['condition.operator'], 'greaterThan');
      final onlyIfElse = List<Map<String, dynamic>>.from(
        onlyIfPayload['elseActions'] as List,
      );
      expect(onlyIfElse, hasLength(2));
      expect(onlyIfElse[0]['type'], 'respondWithMessage');
      expect(onlyIfElse[1]['type'], 'stop');

      final onlyForUsersPayload = result.actions[1].payload;
      expect(onlyForUsersPayload['condition.group'], 'or');
      final onlyForUsersConditions = List<Map<String, dynamic>>.from(
        onlyForUsersPayload['condition.conditions'] as List,
      );
      expect(onlyForUsersConditions, hasLength(2));
      expect(onlyForUsersConditions[0]['variable'], '((author.username))');
      expect(onlyForUsersConditions[0]['operator'], 'matches');
      expect(onlyForUsersConditions[1]['value'], '(?i)^Jeremy\$');

      final onlyForChannelsPayload = result.actions[2].payload;
      final onlyForChannelConditions = List<Map<String, dynamic>>.from(
        onlyForChannelsPayload['condition.conditions'] as List,
      );
      expect(onlyForChannelConditions.single['variable'], '((channel.id))');

      final ignorePayload = result.actions[3].payload;
      final ignoreThen = List<Map<String, dynamic>>.from(
        ignorePayload['thenActions'] as List,
      );
      expect(ignoreThen, hasLength(2));
      expect(ignoreThen[0]['type'], 'respondWithMessage');
      expect(
        ignoreThen[0]['payload']['content'],
        "❌ That command can't be used in this channel!",
      );
      expect(ignoreThen[1]['type'], 'stop');

      final onlyNsfwPayload = result.actions[4].payload;
      expect(onlyNsfwPayload['condition.variable'], '((channel.nsfw))');
      expect(onlyNsfwPayload['condition.value'], 'true');
    });

    test('transpiles permission and role guard helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('manageMessages')],
                <BdfdAstNode>[BdfdTextAst('kickMembers')],
                <BdfdAstNode>[BdfdTextAst('Missing perms')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyBotPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('manageRoles')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyAdmin',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Admins only')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$checkUserPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('<@1234567890>')],
                <BdfdAstNode>[BdfdTextAst('banMembers')],
                <BdfdAstNode>[BdfdTextAst('Denied')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForRoles',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Moderator')],
                <BdfdAstNode>[BdfdTextAst('Role required')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(5));

      final onlyPermsPayload = result.actions[0].payload;
      expect(onlyPermsPayload['condition.group'], 'and');
      final onlyPermsConditions = List<Map<String, dynamic>>.from(
        onlyPermsPayload['condition.conditions'] as List,
      );
      expect(onlyPermsConditions, hasLength(2));
      expect(onlyPermsConditions.first['variable'], '((member.permissions))');
      expect(onlyPermsConditions.first['value'], 'managemessages');

      final onlyBotPermsPayload = result.actions[1].payload;
      final onlyBotPermsConditions = List<Map<String, dynamic>>.from(
        onlyBotPermsPayload['condition.conditions'] as List,
      );
      expect(onlyBotPermsConditions.single['variable'], '((bot.permissions))');

      final onlyAdminPayload = result.actions[2].payload;
      expect(onlyAdminPayload['condition.group'], 'or');

      final checkUserPermsPayload = result.actions[3].payload;
      final checkUserPermsConditions = List<Map<String, dynamic>>.from(
        checkUserPermsPayload['condition.conditions'] as List,
      );
      expect(checkUserPermsPayload['condition.group'], 'or');
      final selfBranchConditions = List<Map<String, dynamic>>.from(
        checkUserPermsConditions.first['conditions'] as List,
      );
      expect(selfBranchConditions.first['variable'], '((author.id))');
      expect(selfBranchConditions.first['value'], '1234567890');
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

      final onlyForRolesPayload = result.actions[4].payload;
      final onlyForRolesConditions = List<Map<String, dynamic>>.from(
        onlyForRolesPayload['condition.conditions'] as List,
      );
      expect(onlyForRolesConditions.single['group'], 'or');
      final roleBranchConditions = List<Map<String, dynamic>>.from(
        onlyForRolesConditions.single['conditions'] as List,
      );
      expect(roleBranchConditions[0]['variable'], '((member.roles))');
      expect(roleBranchConditions[1]['variable'], '((member.roleNames))');
    });

    test('transpiles wave 3 guard helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyForIDs',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('111')],
                <BdfdAstNode>[BdfdTextAst('Denied ID')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForRoleIDs',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('222')],
                <BdfdAstNode>[BdfdTextAst('Denied role id')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForServers',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('333')],
                <BdfdAstNode>[BdfdTextAst('Wrong server')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyForCategories',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('444')],
                <BdfdAstNode>[BdfdTextAst('Wrong category')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyBotChannelPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((channel.id))')],
                <BdfdAstNode>[BdfdTextAst('manageMessages')],
                <BdfdAstNode>[BdfdTextAst('Bot missing perms')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$onlyIfMessageContains',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((message.content))')],
                <BdfdAstNode>[BdfdTextAst('Hello')],
                <BdfdAstNode>[BdfdTextAst('Hi')],
                <BdfdAstNode>[BdfdTextAst('Missing text')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(6));

      final onlyForIdsPayload = result.actions[0].payload;
      final onlyForIdsConditions = List<Map<String, dynamic>>.from(
        onlyForIdsPayload['condition.conditions'] as List,
      );
      expect(onlyForIdsConditions.single['variable'], '((author.id))');

      final onlyForRoleIdsPayload = result.actions[1].payload;
      final onlyForRoleIdsConditions = List<Map<String, dynamic>>.from(
        onlyForRoleIdsPayload['condition.conditions'] as List,
      );
      expect(onlyForRoleIdsConditions.single['variable'], '((member.roles))');

      final onlyForServersPayload = result.actions[2].payload;
      final onlyForServersConditions = List<Map<String, dynamic>>.from(
        onlyForServersPayload['condition.conditions'] as List,
      );
      expect(onlyForServersConditions.single['variable'], '((guild.id))');

      final onlyForCategoriesPayload = result.actions[3].payload;
      final onlyForCategoriesConditions = List<Map<String, dynamic>>.from(
        onlyForCategoriesPayload['condition.conditions'] as List,
      );
      expect(
        onlyForCategoriesConditions.single['variable'],
        '((channel.parentId))',
      );

      final onlyBotChannelPermsPayload = result.actions[4].payload;
      final onlyBotChannelPermsConditions = List<Map<String, dynamic>>.from(
        onlyBotChannelPermsPayload['condition.conditions'] as List,
      );
      expect(
        onlyBotChannelPermsConditions.single['variable'],
        '((bot.permissions))',
      );

      final onlyIfMessageContainsPayload = result.actions[5].payload;
      expect(onlyIfMessageContainsPayload['condition.group'], 'and');
      final containsConditions = List<Map<String, dynamic>>.from(
        onlyIfMessageContainsPayload['condition.conditions'] as List,
      );
      expect(containsConditions, hasLength(2));
      expect(containsConditions[0]['variable'], '((message.content))');
      expect(containsConditions[0]['operator'], 'matches');
      expect(containsConditions[0]['value'], '(?i).*Hello.*');
      expect(containsConditions[1]['value'], '(?i).*Hi.*');
    });

    test('normalizes BDFD wiki permission aliases', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyPerms',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('admin')],
                <BdfdAstNode>[BdfdTextAst('ban')],
                <BdfdAstNode>[BdfdTextAst('slashcommands')],
                <BdfdAstNode>[BdfdTextAst('Denied')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));

      final payload = result.actions.single.payload;
      final conditions = List<Map<String, dynamic>>.from(
        payload['condition.conditions'] as List,
      );
      final values = conditions
          .map((entry) => entry['value']?.toString() ?? '')
          .toList(growable: false);
      expect(values, contains('administrator'));
      expect(values, contains('banmembers'));
      expect(values, contains('useapplicationcommands'));
    });

    test('supports inline checkUserPerms boolean output', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('Admin perms?: '),
            BdfdFunctionCallAst(
              name: r'$checkUserPerms',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$authorID')],
                <BdfdAstNode>[BdfdTextAst('administrator')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));

      expect(result.actions[0].type, BotCreatorActionType.ifBlock);
      expect(result.actions[1].type, BotCreatorActionType.sendMessage);
      expect(result.actions[1].payload['targetType'], 'reply');

      final content = result.actions[1].payload['content']?.toString() ?? '';
      expect(content, startsWith('Admin perms?: '));
      expect(content, contains('((message.bc_check_user_perms_0))'));
    });
  });
}
