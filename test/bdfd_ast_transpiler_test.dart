import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_ast_transpiler.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdAstTranspiler', () {
    test('transpiles plain text into respondWithMessage', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(nodes: [BdfdTextAst('Hello world')]),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], 'Hello world');
    });

    test(
      'transpiles embed-style functions into one respondWithMessage action',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$title',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Server Info')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$description',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('Welcome back')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$color',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('#ffcc00')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addField',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('User')],
                  <BdfdAstNode>[BdfdTextAst('Jeremy')],
                  <BdfdAstNode>[BdfdTextAst('yes')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(1));

        final action = result.actions.single;
        final embeds = List<Map<String, dynamic>>.from(
          action.payload['embeds'] as List,
        );
        expect(action.type, BotCreatorActionType.respondWithMessage);
        expect(embeds, hasLength(1));
        expect(embeds.single['title'], 'Server Info');
        expect(embeds.single['description'], 'Welcome back');
        expect(embeds.single['color'], '#ffcc00');
        expect((embeds.single['fields'] as List).first, {
          'name': 'User',
          'value': 'Jeremy',
          'inline': 'yes',
        });
      },
    );

    test('preserves icon_urls when footericon and authoricon precede footer and author', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$footericon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://footer.icon')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$footer',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('My Footer')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authoricon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://author.icon')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('My Author')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));

      final action = result.actions.single;
      final embeds = List<Map<String, dynamic>>.from(
        action.payload['embeds'] as List,
      );
      expect(embeds, hasLength(1));
      
      final footer = embeds.single['footer'] as Map<String, dynamic>;
      expect(footer['text'], 'My Footer');
      expect(footer['icon_url'], 'https://footer.icon');

      final author = embeds.single['author'] as Map<String, dynamic>;
      expect(author['name'], 'My Author');
      expect(author['icon_url'], 'https://author.icon');
    });

    test('transpiles if blocks to ifBlock actions with nested branches', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>=80')],
                <BdfdAstNode>[BdfdTextAst('great')],
                <BdfdAstNode>[BdfdTextAst('retry')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));

      final action = result.actions.single;
      expect(action.type, BotCreatorActionType.ifBlock);
      expect(action.payload['condition.variable'], '((score))');
      expect(action.payload['condition.operator'], 'greaterOrEqual');
      expect(action.payload['condition.value'], '80');

      final thenActions = List<Map<String, dynamic>>.from(
        action.payload['thenActions'] as List,
      );
      final elseActions = List<Map<String, dynamic>>.from(
        action.payload['elseActions'] as List,
      );
      expect(thenActions.single['type'], 'respondWithMessage');
      expect((thenActions.single['payload'] as Map)['content'], 'great');
      expect(elseActions.single['type'], 'respondWithMessage');
      expect((elseActions.single['payload'] as Map)['content'], 'retry');
    });

    test('transpiles for loop blocks by repeating body actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('3')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('Ping'),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      for (final action in result.actions) {
        expect(action.type, BotCreatorActionType.sendMessage);
        expect(action.payload['targetType'], 'reply');
      }
      expect(result.actions[0].payload['content'], 'Ping');
      expect(result.actions[1].payload['content'], 'Ping');
      expect(result.actions[2].payload['content'], 'Ping');
    });

    test('supports nested loop blocks', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$loop',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('Nested'),
            BdfdFunctionCallAst(name: r'$endloop'),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(4));
      expect(result.actions.first.payload['content'], 'Nested');
      expect(result.actions.last.payload['content'], 'Nested');
    });

    test('reports stray endfor delimiters', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(nodes: [BdfdFunctionCallAst(name: r'$endfor')]),
      );

      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.message, contains('Unexpected'));
      expect(result.diagnostics.single.functionName, r'$endfor');
    });

    test('flushes pending response before standalone action functions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('Intro'),
            BdfdFunctionCallAst(
              name: r'$sendMessage',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Immediate')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.payload['content'], 'Intro');
      expect(result.actions.last.payload['content'], 'Immediate');
    });

    test('reports unsupported functions as diagnostics', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$let',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('score')],
                <BdfdAstNode>[BdfdTextAst('10')],
              ],
            ),
          ],
        ),
      );

      expect(result.actions, isEmpty);
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$let');
    });

    test(
      'renders supported nested variable functions inline without diagnostic',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$description',
                arguments: [
                  <BdfdAstNode>[
                    BdfdTextAst('Hello '),
                    BdfdFunctionCallAst(name: r'$username'),
                  ],
                ],
              ),
            ],
          ),
        );

        expect(result.actions, hasLength(1));
        expect(result.diagnostics, isEmpty);

        final embeds = List<Map<String, dynamic>>.from(
          result.actions.single.payload['embeds'] as List,
        );
        expect(embeds.single['description'], 'Hello ((user.username))');
      },
    );

    test('transpiles http requests and result placeholders', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$httpAddHeader',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('authorization')],
                <BdfdAstNode>[BdfdTextAst('Bearer token')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$httpGet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://api.example.com/cat')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdTextAst('Image: '),
                  BdfdFunctionCallAst(
                    name: r'$httpResult',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('results')],
                      <BdfdAstNode>[BdfdTextAst('0')],
                      <BdfdAstNode>[BdfdTextAst('url')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(2));
      expect(result.actions.first.type, BotCreatorActionType.httpRequest);
      expect(result.actions.first.key, '_bdfd_http_0');
      expect(result.actions.first.payload['method'], 'GET');
      expect(result.actions.first.payload['headers'], {
        'authorization': 'Bearer token',
      });

      final embeds = List<Map<String, dynamic>>.from(
        result.actions.last.payload['embeds'] as List,
      );
      expect(
        embeds.single['description'],
        r'Image: ((http.body.$.results[0].url))',
      );
    });

    test('reports httpResult without preceding request as error', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$httpResult')],
              ],
            ),
          ],
        ),
      );

      expect(result.actions, hasLength(1));
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.functionName, r'$httpResult');
      expect(
        result.diagnostics.single.severity,
        BdfdTranspileDiagnosticSeverity.error,
      );
    });

    test('transpiles block if with elseif/else delimiters', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))>10')],
              ],
            ),
            BdfdTextAst('gold'),
            BdfdFunctionCallAst(
              name: r'$elseif',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((score))==10')],
              ],
            ),
            BdfdTextAst('silver'),
            BdfdFunctionCallAst(name: r'$else'),
            BdfdTextAst('bronze'),
            BdfdFunctionCallAst(name: r'$endif'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.type, BotCreatorActionType.ifBlock);

      final payload = result.actions.single.payload;
      expect(payload['condition.operator'], 'greaterThan');
      expect(payload['condition.value'], '10');

      final elseIfConditions = List<Map<String, dynamic>>.from(
        payload['elseIfConditions'] as List,
      );
      expect(elseIfConditions, hasLength(1));
      expect(elseIfConditions.single['condition.operator'], 'equals');

      final thenActions = List<Map<String, dynamic>>.from(
        payload['thenActions'] as List,
      );
      final elseActions = List<Map<String, dynamic>>.from(
        payload['elseActions'] as List,
      );
      final elseIfActions = List<Map<String, dynamic>>.from(
        elseIfConditions.single['actions'] as List,
      );

      expect((thenActions.single['payload'] as Map)['content'], 'gold');
      expect((elseIfActions.single['payload'] as Map)['content'], 'silver');
      expect((elseActions.single['payload'] as Map)['content'], 'bronze');
    });

    test('transpiles logical and-conditions and stop action', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[BdfdTextAst(r'$and[((a))==1;((b))==2]==true')],
                <BdfdAstNode>[BdfdTextAst('ok')],
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$stop')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final payload = result.actions.single.payload;
      expect(payload['condition.group'], 'and');
      final grouped = List<Map<String, dynamic>>.from(
        payload['condition.conditions'] as List,
      );
      expect(grouped, hasLength(2));

      final elseActions = List<Map<String, dynamic>>.from(
        payload['elseActions'] as List,
      );
      expect(elseActions.single['type'], 'stop');
    });

    test('supports json parse/get/set/unset/stringify helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"user":{"name":"Nia","age":16}}')],
              ],
            ),
            BdfdTextAst('Name='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', Age='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonSet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
                <BdfdAstNode>[BdfdTextAst('19')],
              ],
            ),
            BdfdTextAst(', NewAge='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('age')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonUnset',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', HasName='),
            BdfdFunctionCallAst(
              name: r'$jsonExists',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('user')],
                <BdfdAstNode>[BdfdTextAst('name')],
              ],
            ),
            BdfdTextAst(', JSON='),
            BdfdFunctionCallAst(name: r'$jsonStringify'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Name=Nia, Age=16, NewAge=19, HasName=false, JSON={"user":{"age":19}}',
      );
    });

    test('supports json array helpers', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"music":["A","B"]}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonArrayAppend',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
                <BdfdAstNode>[BdfdTextAst('C')],
              ],
            ),
            BdfdTextAst('Count='),
            BdfdFunctionCallAst(
              name: r'$jsonArrayCount',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
              ],
            ),
            BdfdTextAst(', Removed='),
            BdfdFunctionCallAst(
              name: r'$jsonArrayShift',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
              ],
            ),
            BdfdTextAst(', Joined='),
            BdfdFunctionCallAst(
              name: r'$jsonJoinArray',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('music')],
                <BdfdAstNode>[BdfdTextAst(', ')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        'Count=3, Removed=A, Joined=B, C',
      );
    });

    test(
      'keeps invalid jsonParse non-blocking and returns empty JSON lookups',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$jsonParse',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('{invalid}')],
                ],
              ),
              BdfdTextAst('Value='),
              BdfdFunctionCallAst(
                name: r'$json',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('user')],
                  <BdfdAstNode>[BdfdTextAst('name')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(1));
        expect(result.actions.single.payload['content'], 'Value=');
      },
    );

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

  group('embed helper functions', () {
    test(r'transpiles $addTimestamp without argument to "now"', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [BdfdFunctionCallAst(name: r'$addTimestamp')],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['timestamp'], 'now');
    });

    test(r'transpiles $addTimestamp with explicit value', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addTimestamp',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('2026-03-30T12:00:00Z')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['timestamp'], '2026-03-30T12:00:00Z');
    });

    test(r'transpiles $authorIcon standalone into author.icon_url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authorIcon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/icon.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final author = Map<String, dynamic>.from(embeds.single['author'] as Map);
      expect(author['name'], 'Jeremy');
      expect(author['icon_url'], 'https://example.com/icon.png');
    });

    test(r'transpiles $authorURL standalone into author.url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$author',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Jeremy')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$authorURL',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final author = Map<String, dynamic>.from(embeds.single['author'] as Map);
      expect(author['name'], 'Jeremy');
      expect(author['url'], 'https://example.com');
    });

    test(r'transpiles $embeddedURL into embed url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$title',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Click me')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$embeddedURL',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['title'], 'Click me');
      expect(embeds.single['url'], 'https://example.com');
    });

    test(r'transpiles $footerIcon standalone into footer.icon_url', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$footer',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('My footer')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$footerIcon',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/icon.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      final footer = Map<String, dynamic>.from(embeds.single['footer'] as Map);
      expect(footer['text'], 'My footer');
      expect(footer['icon_url'], 'https://example.com/icon.png');
    });

    test(r'transpiles $thumbnail into an embed thumbnail', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$thumbnail',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://embed-thumb.example.com')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['thumbnail'], {
        'url': 'https://embed-thumb.example.com',
      });
    });
  });

  group('ComponentV2 builder functions', () {
    test(
      r'transpiles $addContainer into a ComponentV2 container component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addContainer',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('container1')],
                  <BdfdAstNode>[BdfdTextAst('#ff0000')],
                  <BdfdAstNode>[BdfdTextAst('no')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithComponentV2,
        );
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        expect(items.single['type'], 'container');
        expect(items.single['accentColor'], '#ff0000');
      },
    );

    test(r'transpiles $addSection into a ComponentV2 section component', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addSection',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('section1')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      expect(items.single['type'], 'section');
      expect(items.single['id'], 'section1');
    });

    test(
      r'transpiles $addThumbnail into a ComponentV2 thumbnail component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addThumbnail',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/thumb.png')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithComponentV2,
        );
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        expect(items.single['type'], 'thumbnail');
        expect(items.single['url'], 'https://example.com/thumb.png');
      },
    );

    test(r'$addMediaGallery creates an empty media gallery with an ID', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addMediaGallery',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('gallery1')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addMediaGalleryItem',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/img1.png')],
                <BdfdAstNode>[BdfdTextAst('First image')],
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('gallery1')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addMediaGalleryItem',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://example.com/img2.png')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      // gallery1 with one targeted item + one appended-to-last item
      expect(items, hasLength(1));
      expect(items.single['type'], 'mediaGallery');
      final galleryItems = List<Map<String, dynamic>>.from(
        items.single['items'] as List,
      );
      expect(galleryItems, hasLength(2));
      expect(galleryItems[0]['url'], 'https://example.com/img1.png');
      expect(galleryItems[0]['description'], 'First image');
      expect(galleryItems[1]['url'], 'https://example.com/img2.png');
      expect(galleryItems[1].containsKey('description'), isFalse);
    });

    test(
      r'$addMediaGallery starts a new gallery after a non-gallery component',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addMediaGallery',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('gallery_a')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addMediaGalleryItem',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/a.png')],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[BdfdTextAst('gallery_a')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$addSeparator'),
              BdfdFunctionCallAst(
                name: r'$addMediaGallery',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('gallery_b')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addMediaGalleryItem',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('https://example.com/b.png')],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[],
                  <BdfdAstNode>[BdfdTextAst('gallery_b')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        final items = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        // gallery, separator, gallery
        expect(items, hasLength(3));
        expect(items[0]['type'], 'mediaGallery');
        expect(items[1]['type'], 'separator');
        expect(items[2]['type'], 'mediaGallery');
        expect(
          (items[0]['items'] as List).single['url'],
          'https://example.com/a.png',
        );
        expect(
          (items[2]['items'] as List).single['url'],
          'https://example.com/b.png',
        );
      },
    );

    test(r'rich V2 components produce respondWithComponentV2 action type', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addTextDisplay',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('Hello ComponentV2')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$addSeparator'),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_ok')],
                <BdfdAstNode>[BdfdTextAst('OK')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithComponentV2,
      );
      final items = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      expect(items[0]['type'], 'textDisplay');
      expect(items[1]['type'], 'separator');
      expect(items[2]['type'], 'button');
    });

    test(
      r'pure buttons without rich V2 keep respondWithMessage action type',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$addButton',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('no')],
                  <BdfdAstNode>[BdfdTextAst('cmd_a')],
                  <BdfdAstNode>[BdfdTextAst('Click')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(
          result.actions.single.type,
          BotCreatorActionType.respondWithMessage,
        );
      },
    );
  });

  group('ComponentV2 editing functions', () {
    test(r'$editButton modifies the button identified by custom ID', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_a')],
                <BdfdAstNode>[BdfdTextAst('Alpha')],
                <BdfdAstNode>[BdfdTextAst('primary')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('cmd_b')],
                <BdfdAstNode>[BdfdTextAst('Beta')],
                <BdfdAstNode>[BdfdTextAst('secondary')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('yes')],
                <BdfdAstNode>[BdfdTextAst('cmd_c')],
                <BdfdAstNode>[BdfdTextAst('Gamma')],
                <BdfdAstNode>[BdfdTextAst('danger')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('cmd_b')],
                <BdfdAstNode>[BdfdTextAst('BetaEdited')],
                <BdfdAstNode>[BdfdTextAst('success')],
                <BdfdAstNode>[BdfdTextAst('yes')],
                <BdfdAstNode>[BdfdTextAst('⭐')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final buttons = components
          .where((c) => c['type'] == 'button')
          .toList(growable: false);
      expect(buttons[0]['label'], 'Alpha');
      expect(buttons[1]['label'], 'BetaEdited');
      expect(buttons[1]['style'], 'success');
      expect(buttons[1]['disabled'], true);
      expect(buttons[2]['label'], 'Gamma');
    });

    test(r'$editButton on a link-style button sets url not customId', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$addButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('no')],
                <BdfdAstNode>[BdfdTextAst('https://old.example.com')],
                <BdfdAstNode>[BdfdTextAst('Visit')],
                <BdfdAstNode>[BdfdTextAst('link')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editButton',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('https://old.example.com')],
                <BdfdAstNode>[BdfdTextAst('Go')],
                <BdfdAstNode>[BdfdTextAst('link')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final button = components.firstWhere((c) => c['type'] == 'button');
      expect(button['label'], 'Go');
      // URL stays the same since we matched by it but didn't change it
      expect(button['url'], 'https://old.example.com');
    });

    test(r'$editSelectMenu updates min, max, and placeholder', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$newSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_1')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_1')],
                <BdfdAstNode>[BdfdTextAst('2')],
                <BdfdAstNode>[BdfdTextAst('3')],
                <BdfdAstNode>[BdfdTextAst('Updated placeholder')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final menu = components.firstWhere((c) => c['type'] == 'selectMenu');
      expect(menu['placeholder'], 'Updated placeholder');
      expect(menu['minValues'], 2);
      expect(menu['maxValues'], 3);
    });

    test(
      r'$editSelectMenuOption updates the first option of the given menu',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$newSelectMenu',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                  <BdfdAstNode>[BdfdTextAst('Option A')],
                  <BdfdAstNode>[BdfdTextAst('val_a')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$addSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                  <BdfdAstNode>[BdfdTextAst('Option B')],
                  <BdfdAstNode>[BdfdTextAst('val_b')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$editSelectMenuOption',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('menu_x')],
                  <BdfdAstNode>[BdfdTextAst('Option A Edited')],
                  <BdfdAstNode>[BdfdTextAst('val_a_edited')],
                  <BdfdAstNode>[BdfdTextAst('A helpful description')],
                  <BdfdAstNode>[BdfdTextAst('yes')],
                  <BdfdAstNode>[BdfdTextAst('⭐')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        final components = List<Map<String, dynamic>>.from(
          (result.actions.single.payload['components'] as Map)['items'] as List,
        );
        final options = components
            .where((c) => c['type'] == 'selectMenuOption')
            .toList(growable: false);
        expect(options[0]['label'], 'Option A Edited');
        expect(options[0]['value'], 'val_a_edited');
        expect(options[0]['description'], 'A helpful description');
        expect(options[0]['default'], true);
        expect(options[0]['emoji'], '⭐');
        expect(options[1]['label'], 'Option B');
      },
    );

    test(r'$editSelectMenuOption with empty description clears the field', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$newSelectMenu',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$addSelectMenuOption',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
                <BdfdAstNode>[BdfdTextAst('Opt')],
                <BdfdAstNode>[BdfdTextAst('v')],
                <BdfdAstNode>[BdfdTextAst('Original desc')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$editSelectMenuOption',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('menu_y')],
                <BdfdAstNode>[],
                <BdfdAstNode>[],
                <BdfdAstNode>[BdfdTextAst('')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final components = List<Map<String, dynamic>>.from(
        (result.actions.single.payload['components'] as Map)['items'] as List,
      );
      final opt = components.firstWhere((c) => c['type'] == 'selectMenuOption');
      expect(opt.containsKey('description'), isFalse);
    });
  });

  group('user/profile inline functions', () {
    test(r'$username without args resolves to ((user.username))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$username')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user.username))');
    });

    test(r'$username[userID] resolves to ((user[id].username))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$username',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('123456')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user[123456].username))');
    });

    test(r'$nickname without args resolves with fallback chains', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$nickname')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member.nick|member.displayName|author.displayName|author.username))');
    });

    test(r'$nickname[userID] resolves with fallback chains', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$nickname',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('789')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member[789].nick|member[789].displayName|user[789].displayName|user[789].username))');
    });

    test(r'$displayName without args resolves to fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$displayName')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((member.nick|author.displayName|author.username))');
    });

    test(r'$displayName[userID] resolves to targeted fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$displayName',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('456')],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(
        embeds.single['description'],
        '((member[456].displayName|user[456].displayName))',
      );
    });

    test(r'$authorAvatar resolves to ((author.avatar))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$authorAvatar')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((author.avatar))');
    });

    test(r'$authorID resolves to ((author.id))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$authorID')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((author.id))');
    });

    test(r'$findUser resolves to ((user.id))', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$description',
              arguments: [
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$findUser')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final embeds = List<Map<String, dynamic>>.from(
        result.actions.single.payload['embeds'] as List,
      );
      expect(embeds.single['description'], '((user.id))');
    });

    test(r'$mentions transpiles to ((message.mentions)) placeholder', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('Users: '),
            BdfdFunctionCallAst(name: r'$mentions'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(
        result.actions.single.payload['content'],
        'Users: ((message.mentions))',
      );
    });

    test(r'$mentioned[1;yes] transpiles to targeted mentions with author fallback', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$mentioned',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('1')],
                <BdfdAstNode>[BdfdTextAst('yes')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], '((message.mentions[0]|author.id))');
    });

    test(r'$isbot[userID] transpiles to user dynamic isBot check', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$isbot',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('123456')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], '((user[123456].isBot))');
    });

    test(r'$isbot without args transpiles to author.isBot', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$isbot',
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions.single.payload['content'], '((author.isBot))');
    });

    test(r'$jsonParse with runtime placeholder emits runtimeJsonBlock', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('data')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdTextAst('v='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('key')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      // Should have a runtimeJsonBlock action + a respondWithMessage
      final runtimeBlocks =
          result.actions
              .where((a) => a.type == BotCreatorActionType.runtimeJsonBlock)
              .toList();
      expect(runtimeBlocks, hasLength(1));

      final payload = runtimeBlocks.single.payload;
      expect(payload['source'], contains('(('));
      expect(payload['operations'], isList);
    });

    test(r'$jsonArrayAppend supports complex JSON objects at compile time', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"items":[]}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonArrayAppend',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('items')],
                <BdfdAstNode>[BdfdTextAst('{"name":"A","val":1}')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$jsonStringify'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        '{"items":[{"name":"A","val":1}]}',
      );
    });

    test(r'literal $jsonParse still works at compile-time (regression)', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"a":1}')],
              ],
            ),
            BdfdTextAst('v='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('a')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.type,
        BotCreatorActionType.respondWithMessage,
      );
      expect(result.actions.single.payload['content'], 'v=1');
      // No runtimeJsonBlock when literal JSON
      expect(
        result.actions
            .where((a) => a.type == BotCreatorActionType.runtimeJsonBlock)
            .toList(),
        isEmpty,
      );
    });

    test(r'$jsonPretty does not corrupt double-spaces inside strings', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{"msg":"hello  world"}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonPretty',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('4')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      final content = result.actions.single.payload['content'] as String;
      // The double-space inside the value MUST be preserved.
      expect(content, contains('"hello  world"'));
    });

    test(r'$jsonExists returns false when no JSON context', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdTextAst('exists='),
            BdfdFunctionCallAst(
              name: r'$jsonExists',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('key')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(result.actions.single.payload['content'], 'exists=false');
    });

    test(r'$jsonSet supports complex JSON objects', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('{}')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonSet',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('nested')],
                <BdfdAstNode>[BdfdTextAst('{"a":1,"b":2}')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$jsonStringify'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(1));
      expect(
        result.actions.single.payload['content'],
        '{"nested":{"a":1,"b":2}}',
      );
    });

    test(r'$argsCheck emits diagnostic for unknown operator', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$argsCheck',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('==')],
                <BdfdAstNode>[BdfdTextAst('3')],
                <BdfdAstNode>[BdfdTextAst('Need 3 args')],
              ],
            ),
          ],
        ),
      );

      // Should emit a diagnostic warning about unknown operator.
      expect(result.diagnostics, hasLength(1));
      expect(result.diagnostics.single.message, contains('unknown operator'));
      // Action should still be emitted (with fallback).
      expect(result.actions, isNotEmpty);
    });

    test('two consecutive deferred jsonParse blocks get unique prefixes', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('json1')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdTextAst('a='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('k')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('json2')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdTextAst('b='),
            BdfdFunctionCallAst(
              name: r'$json',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('k')],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      final blocks =
          result.actions
              .where((a) => a.type == BotCreatorActionType.runtimeJsonBlock)
              .toList();
      expect(blocks, hasLength(2));
      // Keys must be different.
      expect(blocks[0].key, isNot(equals(blocks[1].key)));
    });

    test(
      r'deferred json is flushed before setServerVar action using $jsonStringify',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$jsonParse',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$getServerVar',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('items_db')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$jsonArrayAppend',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('items')],
                  <BdfdAstNode>[BdfdTextAst('sword')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$setServerVar',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('items_db')],
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$jsonStringify')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(2));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[1].type, BotCreatorActionType.setScopedVariable);

        final value = (result.actions[1].payload['value'] ?? '').toString();
        expect(value, contains('rtJson_'));
        expect(value, isNot(contains('.json_')));
      },
    );

    test(r'full additem script keeps runtimeJsonBlock before setServerVar', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyIf',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((args.count))>0')],
                <BdfdAstNode>[BdfdTextAst('usage')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items_db')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonArrayAppend',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('items')],
                <BdfdAstNode>[BdfdTextAst('sword')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$setServerVar',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('items_db')],
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$jsonStringify')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('ok'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);

      final runtimeIndex = result.actions.indexWhere(
        (a) => a.type == BotCreatorActionType.runtimeJsonBlock,
      );
      final setVarIndex = result.actions.indexWhere(
        (a) => a.type == BotCreatorActionType.setScopedVariable,
      );

      expect(runtimeIndex, greaterThanOrEqualTo(0));
      expect(setVarIndex, greaterThanOrEqualTo(0));
      expect(runtimeIndex, lessThan(setVarIndex));

      final setValue =
          (result.actions[setVarIndex].payload['value'] ?? '').toString();
      expect(setValue, contains('rtJson_'));
      expect(setValue, isNot(contains('.json_')));
    });

    test(
      r'deferred json reads continue after setServerVar using $jsonPretty',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$jsonParse',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$getServerVar',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('items_db')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$jsonArrayAppend',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('items')],
                  <BdfdAstNode>[BdfdTextAst('sword')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$setServerVar',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('items_db')],
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$jsonStringify')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$reply'),
              BdfdTextAst('Pretty: '),
              BdfdFunctionCallAst(
                name: r'$jsonPretty',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('1')],
                ],
              ),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(4));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[1].type, BotCreatorActionType.setScopedVariable);
        expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
        expect(result.actions[3].type, BotCreatorActionType.sendMessage);
        expect(result.actions[3].payload['targetType'], 'reply');

        final setValue = (result.actions[1].payload['value'] ?? '').toString();
        expect(setValue, contains('rtJson_'));
        expect(setValue, isNot(contains('.json_')));

        final replyContent =
            (result.actions[3].payload['content'] ?? '').toString();
        expect(replyContent, contains('Pretty: '));
        expect(replyContent, contains('rtJson_'));
        expect(replyContent, contains('.json_0'));
      },
    );

    test(r'finditem flow emits runtime json before if block', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$onlyIf',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('((args.count))>0')],
                <BdfdAstNode>[BdfdTextAst('usage')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items_db')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('idx')],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$jsonArrayIndex',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items')],
                      <BdfdAstNode>[BdfdTextAst('potion')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$var',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('idx')],
                    ],
                  ),
                  BdfdTextAst('==-1'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('not found'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('found at '),
                  BdfdFunctionCallAst(
                    name: r'$var',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('idx')],
                    ],
                  ),
                  BdfdTextAst(': '),
                  BdfdFunctionCallAst(
                    name: r'$json',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items')],
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$var',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('idx')],
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
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

    test(r'try block flushes runtime json before temp var actions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items_db')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(name: r'$try'),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('idx')],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$jsonArrayIndex',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items')],
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$message',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('1')],
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('idx')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$catch'),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdTextAst('fallback'),
            BdfdFunctionCallAst(name: r'$endtry'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
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
    });

    test(r'runtime temp var is emitted before a runtime for loop', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items_db')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('looping')],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$jsonArrayCount',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('currencies')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$var',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('looping')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdFunctionCallAst(name: r'$i'),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(3));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.forLoop);
      expect(result.actions[2].payload['iterations'], '((temp.looping))');
    });

    test(r'runtime loop body keeps temp setter actions in bodyActions', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$for',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$message',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('1')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('current')],
                <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$reply'),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('current')],
              ],
            ),
            BdfdFunctionCallAst(name: r'$endfor'),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
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
      r'weighted roll style runtime loop keeps nested json if flow dynamic',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$jsonParse',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$getServerVar',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('items_db')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('in')],
                  <BdfdAstNode>[BdfdTextAst('items')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('target')],
                  <BdfdAstNode>[BdfdTextAst('sword')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('looping')],
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$jsonArrayCount',
                      arguments: [
                        <BdfdAstNode>[
                          BdfdFunctionCallAst(
                            name: r'$var',
                            arguments: [
                              <BdfdAstNode>[BdfdTextAst('in')],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$for',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$var',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('looping')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$if',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$json',
                      arguments: [
                        <BdfdAstNode>[
                          BdfdFunctionCallAst(
                            name: r'$var',
                            arguments: [
                              <BdfdAstNode>[BdfdTextAst('in')],
                            ],
                          ),
                        ],
                        <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                        <BdfdAstNode>[BdfdTextAst('name')],
                      ],
                    ),
                    BdfdTextAst('=='),
                    BdfdFunctionCallAst(
                      name: r'$var',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('target')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(name: r'$reply'),
              BdfdFunctionCallAst(
                name: r'$json',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$var',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('in')],
                      ],
                    ),
                  ],
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                  <BdfdAstNode>[BdfdTextAst('weight')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$endif'),
              BdfdFunctionCallAst(name: r'$endfor'),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
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
      r'aggressive nested ifs in a runtime loop keep json reads executable',
      () {
        final result = BdfdAstTranspiler().transpile(
          const BdfdScriptAst(
            nodes: [
              BdfdFunctionCallAst(
                name: r'$jsonParse',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$getServerVar',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('items_db')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('in')],
                  <BdfdAstNode>[BdfdTextAst('items')],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$var',
                arguments: [
                  <BdfdAstNode>[BdfdTextAst('looping')],
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$jsonArrayCount',
                      arguments: [
                        <BdfdAstNode>[
                          BdfdFunctionCallAst(
                            name: r'$var',
                            arguments: [
                              <BdfdAstNode>[BdfdTextAst('in')],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$for',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$var',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('looping')],
                      ],
                    ),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$if',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$json',
                      arguments: [
                        <BdfdAstNode>[
                          BdfdFunctionCallAst(
                            name: r'$var',
                            arguments: [
                              <BdfdAstNode>[BdfdTextAst('in')],
                            ],
                          ),
                        ],
                        <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                        <BdfdAstNode>[BdfdTextAst('enabled')],
                      ],
                    ),
                    BdfdTextAst('==true'),
                  ],
                ],
              ),
              BdfdFunctionCallAst(
                name: r'$if',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$json',
                      arguments: [
                        <BdfdAstNode>[
                          BdfdFunctionCallAst(
                            name: r'$var',
                            arguments: [
                              <BdfdAstNode>[BdfdTextAst('in')],
                            ],
                          ),
                        ],
                        <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                        <BdfdAstNode>[BdfdTextAst('weight')],
                      ],
                    ),
                    BdfdTextAst('>5'),
                  ],
                ],
              ),
              BdfdFunctionCallAst(name: r'$reply'),
              BdfdFunctionCallAst(
                name: r'$json',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$var',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('in')],
                      ],
                    ),
                  ],
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                  <BdfdAstNode>[BdfdTextAst('name')],
                ],
              ),
              BdfdTextAst(':'),
              BdfdFunctionCallAst(
                name: r'$json',
                arguments: [
                  <BdfdAstNode>[
                    BdfdFunctionCallAst(
                      name: r'$var',
                      arguments: [
                        <BdfdAstNode>[BdfdTextAst('in')],
                      ],
                    ),
                  ],
                  <BdfdAstNode>[BdfdFunctionCallAst(name: r'$i')],
                  <BdfdAstNode>[BdfdTextAst('weight')],
                ],
              ),
              BdfdFunctionCallAst(name: r'$endif'),
              BdfdFunctionCallAst(name: r'$endif'),
              BdfdFunctionCallAst(name: r'$endfor'),
            ],
          ),
        );

        expect(result.diagnostics, isEmpty);
        expect(result.actions, hasLength(5));
        expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[1].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
        expect(
          result.actions[3].type,
          BotCreatorActionType.setTemporaryVariable,
        );
        expect(result.actions[4].type, BotCreatorActionType.forLoop);

        final bodyActions = List<Map<String, dynamic>>.from(
          result.actions[4].payload['bodyActions'] as List? ?? const [],
        );
        expect(bodyActions, hasLength(2));
        expect(bodyActions[0]['type'], 'runtimeJsonBlock');
        expect(bodyActions[1]['type'], 'ifBlock');

        final outerIfPayload = Map<String, dynamic>.from(
          bodyActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect(
          (outerIfPayload['condition.variable'] ?? '').toString(),
          contains('.json_0'),
        );

        final outerThenActions = List<Map<String, dynamic>>.from(
          outerIfPayload['thenActions'] as List? ?? const [],
        );
        expect(outerThenActions, hasLength(2));
        expect(outerThenActions[0]['type'], 'runtimeJsonBlock');
        expect(outerThenActions[1]['type'], 'ifBlock');

        final innerIfPayload = Map<String, dynamic>.from(
          outerThenActions[1]['payload'] as Map? ?? const <String, dynamic>{},
        );
        expect(
          (innerIfPayload['condition.variable'] ?? '').toString(),
          contains('.json_0'),
        );

        final innerThenActions = List<Map<String, dynamic>>.from(
          innerIfPayload['thenActions'] as List? ?? const [],
        );
        expect(innerThenActions, hasLength(2));
        expect(innerThenActions[0]['type'], 'runtimeJsonBlock');
        expect(innerThenActions[1]['type'], 'sendMessage');
        expect(
          (innerThenActions[1]['payload']
              as Map<String, dynamic>)['targetType'],
          'reply',
        );

        final nestedReply =
            (innerThenActions[1]['payload'] as Map<String, dynamic>)['content']
                .toString();
        expect(nestedReply, contains('rtJson_'));
        expect(nestedReply, contains('.json_'));
      },
    );

    test(r'standalone if hoists runtime json condition before if action', () {
      final result = BdfdAstTranspiler().transpile(
        const BdfdScriptAst(
          nodes: [
            BdfdFunctionCallAst(
              name: r'$jsonParse',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$getServerVar',
                    arguments: [
                      <BdfdAstNode>[BdfdTextAst('items_db')],
                    ],
                  ),
                ],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$var',
              arguments: [
                <BdfdAstNode>[BdfdTextAst('in')],
                <BdfdAstNode>[BdfdTextAst('items')],
              ],
            ),
            BdfdFunctionCallAst(
              name: r'$if',
              arguments: [
                <BdfdAstNode>[
                  BdfdFunctionCallAst(
                    name: r'$json',
                    arguments: [
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$var',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('in')],
                          ],
                        ),
                      ],
                      <BdfdAstNode>[
                        BdfdFunctionCallAst(
                          name: r'$message',
                          arguments: [
                            <BdfdAstNode>[BdfdTextAst('1')],
                          ],
                        ),
                      ],
                      <BdfdAstNode>[BdfdTextAst('enabled')],
                    ],
                  ),
                  BdfdTextAst('==true'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('enabled'),
                ],
                <BdfdAstNode>[
                  BdfdFunctionCallAst(name: r'$reply'),
                  BdfdTextAst('disabled'),
                ],
              ],
            ),
          ],
        ),
      );

      expect(result.diagnostics, isEmpty);
      expect(result.actions, hasLength(4));
      expect(result.actions[0].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[1].type, BotCreatorActionType.setTemporaryVariable);
      expect(result.actions[2].type, BotCreatorActionType.runtimeJsonBlock);
      expect(result.actions[3].type, BotCreatorActionType.ifBlock);

      final ifPayload = result.actions[3].payload;
      final conditionVariable =
          (ifPayload['condition.variable'] ?? '').toString();
      expect(conditionVariable, contains('rtJson_'));
      expect(conditionVariable, contains('.json_0'));
      expect(ifPayload['condition.value'], 'true');
    });
  });
}
