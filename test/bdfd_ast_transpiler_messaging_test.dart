import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler — messaging & user identity', () {
    test('supports inline message[] argument lookups', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('First='),
            BdfdFunctionCallAst(
              name: r'$message',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
              ],
            ),
            BdfdTextAst(', Last='),
            BdfdFunctionCallAst(
              name: r'$message',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('>')],
              ],
            ),
            BdfdTextAst(', Slash='),
            BdfdFunctionCallAst(
              name: r'$message',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('text')],
              ],
            ),
            BdfdTextAst(', Mixed='),
            BdfdFunctionCallAst(
              name: r'$message',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[BdfdTextAst('text')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        'First=((message.content[0])), Last=((last(split(message.content, " ")))), Slash=((opts.text)), Mixed=((message.content[0]|opts.text))',
      );
    });

    test('supports inline message without brackets', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('Raw='),
            BdfdFunctionCallAst(name: r'$message'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        'Raw=((message.content))',
      );
    });

    test('transpiles channelSendMessage to sendMessage action', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$channelSendMessage',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123456789012345678')],
                <BdfdAstNode>[BdfdTextAst('Hello!')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['channelId'], '123456789012345678');
      expect(result.actions.single.payload['content'], 'Hello!');
    });

    test('resolves user identity helper functions inline', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdFunctionCallAst(name: r'$authorAvatar'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$authorID'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$authorOfMessage'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$creationDate'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$discriminator'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$displayName'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(
              name: r'$displayName',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123')],
              ],
            ),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$getUserStatus'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$getCustomStatus'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$isAdmin'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$isBooster'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$isBot'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$isUserDMEnabled'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$nickname'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(
              name: r'$nickname',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123')],
              ],
            ),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userAvatar'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userBadges'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userBanner'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userBannerColor'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userExists'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userID'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userInfo'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userJoined'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userJoinedDiscord'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$username'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(
              name: r'$username',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123')],
              ],
            ),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userPerms'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$userServerAvatar'),
            BdfdTextAst('|'),
            BdfdFunctionCallAst(name: r'$findUser'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      final content =
          result.actions.single.payload['content']?.toString() ?? '';
      expect(content, contains('((author.avatar))'));
      expect(content, contains('((author.id))'));
      expect(content, contains('((target.message.author.id|author.id))'));
      expect(content, contains('((member.nick|author.displayName|author.username))'));
      expect(content, contains('((userperms[;-1;, ]))'));
      expect(content, contains('((member.avatar))'));
      expect(content, contains('((user.id))'));
    });

    test('transpiles changeUsername helpers to actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$changeUsername',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('NewName')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$changeUsernameWithID',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1234567890')],
                <BdfdAstNode>[BdfdTextAst('AnotherName')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions[0].type, BotCreatorActionType.updateSelfUser);
      expect(result.actions[0].payload['username'], 'NewName');
      expect(result.actions[1].type, BotCreatorActionType.ifBlock);
    });

    test('supports inline mentionedChannels lookup', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('Mention='),
            BdfdFunctionCallAst(
              name: r'$mentionedChannels',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
              ],
            ),
            BdfdTextAst(', Fallback='),
            BdfdFunctionCallAst(
              name: r'$mentionedChannels',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.sendMessage);
      expect(result.actions.single.payload['targetType'], 'reply');
      expect(
        result.actions.single.payload['content'],
        'Mention=((message.mentions[0])), Fallback=((message.mentions[0]|channel.id))',
      );
    });
  });
}
