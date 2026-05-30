import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('resolveTemplatePlaceholders', () {
    test('resolves bot.ping placeholder', () {
      final resolved = resolveTemplatePlaceholders('Ping: ((bot.ping)) ms', {
        'bot.ping': '65',
      });

      expect(resolved, 'Ping: 65 ms');
    });

    test(
      'resolves direct keys case-insensitively with exact-match priority',
      () {
        final resolved = resolveTemplatePlaceholders('Hello ((UserName))', {
          'UserName': 'Jeremy',
          'username': 'Fallback',
        });

        expect(resolved, 'Hello Jeremy');
      },
    );

    test(
      'resolves JSON-path placeholders with case-insensitive source lookup',
      () {
        final resolved = resolveTemplatePlaceholders(
          r'Count: ((MyHttp.Body.$.items[0].count))',
          <String, String>{'myHttp.body': '{"items":[{"count":3}]}'},
        );

        expect(resolved, 'Count: 3');
      },
    );

    test(
      'keeps fallback at top level without splitting function arguments',
      () {
        final resolved = resolveTemplatePlaceholders(
          'Players: ((join(scores.\$, "|")|fallback))',
          <String, String>{'scores': '["Alice","Bob"]', 'fallback': 'nobody'},
        );

        expect(resolved, 'Players: Alice|Bob');
      },
    );

    test('falls back when the first resolved value is an empty string', () {
      final resolved = resolveTemplatePlaceholders(
        'Prefix: ((user.bc_prefix | guild.bc_prefix))',
        <String, String>{'user.bc_prefix': '', 'guild.bc_prefix': '!'},
      );

      expect(resolved, 'Prefix: !');
    });

    test('supports bare punctuation literal fallback values', () {
      final resolved = resolveTemplatePlaceholders(
        'Prefix: ((user.bc_prefix | guild.bc_prefix | !))',
        <String, String>{'user.bc_prefix': '', 'guild.bc_prefix': ''},
      );

      expect(resolved, 'Prefix: !');
    });

    test('resolves nested placeholders inside variable keys', () {
      final resolved = resolveTemplatePlaceholders(
        'Perms: ((permissions.byId.((author.id))|member.permissions))',
        <String, String>{
          'author.id': '243117191774470146',
          'permissions.byId.243117191774470146': 'manageguild,banmembers',
          'member.permissions': 'fallback',
        },
      );

      expect(resolved, 'Perms: manageguild,banmembers');
    });

    test(
      'falls back after nested key resolution when dynamic key is missing',
      () {
        final resolved = resolveTemplatePlaceholders(
          'Perms: ((permissions.byId.((author.id))|member.permissions))',
          <String, String>{
            'author.id': '243117191774470146',
            'member.permissions': 'manageguild',
          },
        );

        expect(resolved, 'Perms: manageguild');
      },
    );

    test('serializes slice results back to JSON text', () {
      final resolved = resolveTemplatePlaceholders(
        'Slice: ((slice(scores.\$, 1, 3)))',
        <String, String>{'scores': '["A","B","C","D"]'},
      );

      expect(resolved, 'Slice: ["B","C"]');
    });

    test('formats array items with nested object placeholders', () {
      final resolved = resolveTemplatePlaceholders(
        'Rows: ((formatEach(scores.\$, "{profile.name}:{score}", ", ")))',
        <String, String>{
          'scores':
              '[{"profile":{"name":"Alice"},"score":7},{"profile":{"name":"Bob"},"score":12}]',
        },
      );

      expect(resolved, 'Rows: Alice:7, Bob:12');
    });

    test('returns empty string for invalid JSON paths or missing values', () {
      final resolved = resolveTemplatePlaceholders(
        'Value=((payload.\$.items[99].name))',
        <String, String>{'payload': '{"items":[{"name":"Alpha"}]}'},
      );

      expect(resolved, 'Value=');
    });

    test('resolves BDFD select collection suffixes', () {
      final resolved = resolveTemplatePlaceholders(
        'Second=((interaction.stringSelect.value[2])) Joined=((interaction.stringSelect.values[, ])) Limited=((interaction.stringSelect.values[/;2]))',
        <String, String>{
          'interaction.stringSelect.value': 'alpha',
          'interaction.stringSelect.values': 'alpha,beta,gamma',
          '__collection.interaction.stringSelect.value':
              '["alpha","beta","gamma"]',
          '__collection.interaction.stringSelect.values':
              '["alpha","beta","gamma"]',
        },
      );

      expect(
        resolved,
        'Second=beta Joined=alpha, beta, gamma Limited=alpha/beta',
      );
    });
  });

  group('resolveTemplateExpressionValue', () {
    test('normalizes string casing and whitespace', () {
      expect(
        resolveTemplateExpressionValue(
          'lowercase("HeLLo")',
          <String, String>{},
        ),
        'hello',
      );
      expect(
        resolveTemplateExpressionValue(
          'uppercase("HeLLo")',
          <String, String>{},
        ),
        'HELLO',
      );
      expect(
        resolveTemplateExpressionValue(
          'trim("  spaced  ")',
          <String, String>{},
        ),
        'spaced',
      );
    });

    test('supports replace and contains helpers', () {
      expect(
        resolveTemplateExpressionValue(
          'replace("Hello there", "there", "world")',
          <String, String>{},
        ),
        'Hello world',
      );

      expect(
        resolveTemplatePlaceholders('((contains("AbCd", "bc")))', {}),
        'true',
      );
      expect(resolveTemplatePlaceholders('((contains("AbCd", "zz")))', {}), '');
    });

    test('supports BDScript-like casing aliases and title case', () {
      expect(
        resolveTemplateExpressionValue(
          'toLowerCase("HeLLo")',
          <String, String>{},
        ),
        'hello',
      );
      expect(
        resolveTemplateExpressionValue(
          'toUpperCase("HeLLo")',
          <String, String>{},
        ),
        'HELLO',
      );
      expect(
        resolveTemplateExpressionValue(
          'toTitleCase("hello world_from bot")',
          <String, String>{},
        ),
        'Hello World_From Bot',
      );
    });

    test('supports charCount and linesCount helpers', () {
      expect(
        resolveTemplateExpressionValue('charCount("abc")', <String, String>{}),
        3,
      );
      expect(
        resolveTemplateExpressionValue(
          'linesCount("a\\nb\\nc")',
          <String, String>{},
        ),
        3,
      );
      expect(
        resolveTemplateExpressionValue('linesCount("")', <String, String>{}),
        0,
      );
    });

    test('supports numberSeparator helper', () {
      expect(
        resolveTemplateExpressionValue(
          'numberSeparator(1234567)',
          <String, String>{},
        ),
        '1,234,567',
      );
      expect(
        resolveTemplateExpressionValue(
          'numberSeparator(1234567, " ")',
          <String, String>{},
        ),
        '1 234 567',
      );
    });

    test('supports split helper with and without index', () {
      expect(
        resolveTemplateExpressionValue(
          'split("a,b,c", ",")',
          <String, String>{},
        ),
        <String>['a', 'b', 'c'],
      );
      expect(
        resolveTemplateExpressionValue(
          'split("a,b,c", ",", 1)',
          <String, String>{},
        ),
        'b',
      );
      expect(
        resolveTemplatePlaceholders('((split("a,b,c", ",")))', {}),
        '["a","b","c"]',
      );
    });

    test('supports cropText helper', () {
      expect(
        resolveTemplateExpressionValue(
          'cropText("hello world", 5)',
          <String, String>{},
        ),
        'hello...',
      );
      expect(
        resolveTemplateExpressionValue(
          'cropText("hello world", 5, "~")',
          <String, String>{},
        ),
        'hello~',
      );
      expect(
        resolveTemplateExpressionValue(
          'cropText("hello", 10)',
          <String, String>{},
        ),
        'hello',
      );
    });

    test('supports first, last and sum for arrays', () {
      expect(
        resolveTemplateExpressionValue('first(scores.\$)', <String, String>{
          'scores': '[3,5,8]',
        }),
        3,
      );

      expect(
        resolveTemplateExpressionValue('last(scores.\$)', <String, String>{
          'scores': '[3,5,8]',
        }),
        8,
      );

      expect(
        resolveTemplateExpressionValue('sum(scores.\$)', <String, String>{
          'scores': '[3,"5",null,"x",8.5]',
        }),
        16.5,
      );
    });

    test('supports length and at helpers for arrays', () {
      expect(
        resolveTemplateExpressionValue('length(scores.\$)', <String, String>{
          'scores': '[3,5,8]',
        }),
        3,
      );

      expect(
        resolveTemplateExpressionValue('at(scores.\$, 1)', <String, String>{
          'scores': '[3,5,8]',
        }),
        5,
      );
    });

    test('builds embed field payloads from object arrays', () {
      final resolved = resolveTemplateExpressionValue(
        'embedFields(scores.\$, "{name}", "{score}", true)',
        <String, String>{
          'scores': '[{"name":"Alice","score":7},{"name":"Bob","score":12}]',
        },
      );

      expect(resolved, <Map<String, dynamic>>[
        <String, dynamic>{'name': 'Alice', 'value': '7', 'inline': true},
        <String, dynamic>{'name': 'Bob', 'value': '12', 'inline': true},
      ]);
    });

    test('rewrites avatar URL format and size', () {
      final resolved = resolveTemplateExpressionValue(
        'avatar(userAvatar, "png", 256)',
        <String, String>{
          'userAvatar':
              'https://cdn.discordapp.com/avatars/1/abc.webp?size=1024',
        },
      );

      expect(resolved, 'https://cdn.discordapp.com/avatars/1/abc.png?size=256');
    });

    test('rewrites banner URL with default values when args are missing', () {
      final resolved = resolveTemplateExpressionValue(
        'banner(userBanner)',
        <String, String>{
          'userBanner': 'https://cdn.discordapp.com/banners/1/def.png?size=512',
        },
      );

      expect(
        resolved,
        'https://cdn.discordapp.com/banners/1/def.webp?size=1024',
      );
    });
  });

  group('random template functions', () {
    test('coin() returns "true" or empty string', () {
      final results = <String>{};
      // Run multiple times to cover both outcomes.
      for (var i = 0; i < 200; i++) {
        results.add(resolveTemplatePlaceholders('((coin()))', {}));
      }
      expect(results, containsAll(['true', '']));
      // No other values should appear.
      expect(results.difference({'true', ''}), isEmpty);
    });

    test('random() returns "true" or empty string (legacy alias)', () {
      final results = <String>{};
      for (var i = 0; i < 200; i++) {
        results.add(resolveTemplatePlaceholders('((random()))', {}));
      }
      expect(results, containsAll(['true', '']));
    });

    test('randomchoice picks from provided arguments', () {
      final results = <String>{};
      for (var i = 0; i < 200; i++) {
        results.add(
          resolveTemplatePlaceholders('((randomchoice("a", "b", "c")))', {}),
        );
      }
      expect(results, containsAll(['a', 'b', 'c']));
      expect(results.difference({'a', 'b', 'c'}), isEmpty);
    });

    test('randomint returns integer in range', () {
      final results = <int>{};
      for (var i = 0; i < 200; i++) {
        final s = resolveTemplatePlaceholders('((randomint(1, 3)))', {});
        results.add(int.parse(s));
      }
      expect(results, containsAll([1, 2, 3]));
      expect(results.every((v) => v >= 1 && v <= 3), isTrue);
    });

    test('randomchoice with no args returns empty', () {
      final resolved = resolveTemplatePlaceholders('((randomchoice()))', {});
      expect(resolved, '');
    });

    test('randomint with invalid range returns empty', () {
      final resolved = resolveTemplatePlaceholders('((randomint(5, 2)))', {});
      expect(resolved, '');
    });
  });

  group('logical and variable bracket functions', () {
    test('and() evaluates conditions correctly', () {
      expect(resolveTemplatePlaceholders('((and[1==1; 2>=1]))', {}), 'true');
      expect(resolveTemplatePlaceholders('((and[1==1; 2<1]))', {}), 'false');
      expect(resolveTemplatePlaceholders('((and[]))', {}), 'false');
    });

    test('or() evaluates conditions correctly', () {
      expect(resolveTemplatePlaceholders('((or[1==2; 2>=1]))', {}), 'true');
      expect(resolveTemplatePlaceholders('((or[1==2; 2<1]))', {}), 'false');
      expect(resolveTemplatePlaceholders('((or[]))', {}), 'false');
    });

    test('listvar() lists all custom variables', () {
      final updates = {
        'variables.bc_first': '1',
        'user[123].bc_second': '2',
        'guild[456].bc_third': '3',
        'ignored_var': '4',
      };
      final resolved = resolveTemplatePlaceholders('((listvar["; "]))', updates);
      // Sort the list because map entry order is not guaranteed.
      final listed = resolved.split('; ')..sort();
      expect(listed, ['first', 'second', 'third']);
    });

    test('variablescount() counts correct types', () {
      final updates = {
        'variables.bc_a': '1',
        'variables.bc_b': '2',
        'user[123].bc_c': '3',
        'guild[456].bc_d': '4',
        'ignored_var': '5',
      };
      expect(resolveTemplatePlaceholders('((variablescount["global"]))', updates), '2');
      expect(resolveTemplatePlaceholders('((variablescount["user"]))', updates), '1');
      expect(resolveTemplatePlaceholders('((variablescount["guild"]))', updates), '1');
    });

    group('userperms function', () {
      test('resolves author permissions formatted in standard BDFD format', () {
        final updates = {
          'author.id': '111',
          'member.permissions': 'administrator,addreactions,connect',
        };
        expect(
          resolveTemplatePlaceholders('((userperms[111;-1;, ]))', updates),
          'ADMINISTRATOR, ADD_REACTIONS, CONNECT',
        );
      });

      test('resolves with defaults when arguments are empty', () {
        final updates = {
          'author.id': '111',
          'member.permissions': 'banmembers,kickmembers',
        };
        expect(
          resolveTemplatePlaceholders('((userperms[;-1;, ]))', updates),
          'BAN_MEMBERS, KICK_MEMBERS',
        );
      });

      test('respects return amount limit and custom separator', () {
        final updates = {
          'author.id': '111',
          'member.permissions': 'banmembers,kickmembers,administrator',
        };
        expect(
          resolveTemplatePlaceholders('((userperms[;2; | ]))', updates),
          'BAN_MEMBERS | KICK_MEMBERS',
        );
      });

      test('resolves other user permissions by ID', () {
        final updates = {
          'author.id': '111',
          'permissions.byId.222': 'banmembers,stream',
        };
        expect(
          resolveTemplatePlaceholders('((userperms[222;-1;, ]))', updates),
          'BAN_MEMBERS, STREAM',
        );
      });
    });

    group('BDFD dynamic runtime & boolean compliance', () {
      test('resolves day, month, year, hour, minute, second, time, date dynamically', () {
        final updates = <String, String>{};
        expect(resolveTemplatePlaceholders('((year))', updates), DateTime.now().toUtc().year.toString());
        expect(resolveTemplatePlaceholders('((month))', updates), DateTime.now().toUtc().month.toString());
        expect(resolveTemplatePlaceholders('((day))', updates), DateTime.now().toUtc().day.toString());
        expect(resolveTemplatePlaceholders('((hour))', updates), isNotEmpty);
        expect(resolveTemplatePlaceholders('((minute))', updates), isNotEmpty);
        expect(resolveTemplatePlaceholders('((second))', updates), isNotEmpty);
        expect(resolveTemplatePlaceholders('((time))', updates), isNotEmpty);
        expect(resolveTemplatePlaceholders('((date))', updates), isNotEmpty);
      });

      test('resolves formatted uptime dynamically', () {
        final updates = {
          'bot.uptime': '8952000', // 2 hours, 29 minutes, 12 seconds
        };
        expect(
          resolveTemplatePlaceholders('((uptime))', updates),
          '02:29:12',
        );
      });

      test('returns false as fallback for BDFD boolean checks', () {
        final updates = <String, String>{};
        expect(resolveTemplatePlaceholders('((isbot))', updates), 'false');
        expect(resolveTemplatePlaceholders('((author.isBot))', updates), 'false');
        expect(resolveTemplatePlaceholders('((user[123].isBot))', updates), 'false');
        expect(resolveTemplatePlaceholders('((isadmin))', updates), 'false');
        expect(resolveTemplatePlaceholders('((member.isAdmin))', updates), 'false');
        expect(resolveTemplatePlaceholders('((isnsfw))', updates), 'false');
        expect(resolveTemplatePlaceholders('((exists))', updates), 'false');
      });
    });

    group('BDFD aligning functions and fallbacks', () {
      test('resolves nickname fallbacks for current and specific users', () {
        final updates = {
          'member.nick': 'JeremyNick',
          'member.displayName': 'JeremyDisp',
          'author.displayName': 'JeremyAuthDisp',
          'author.username': 'jeremy_user',
        };
        // Current user nickname resolves directly
        expect(resolveTemplatePlaceholders('((member.nick|member.displayName|author.displayName|author.username))', updates), 'JeremyNick');

        // Missing nick falls back to displayName
        final updates2 = {
          'member.displayName': 'JeremyDisp',
          'author.displayName': 'JeremyAuthDisp',
          'author.username': 'jeremy_user',
        };
        expect(resolveTemplatePlaceholders('((member.nick|member.displayName|author.displayName|author.username))', updates2), 'JeremyDisp');

        // Parameterized nickname fallbacks
        final updates3 = {
          'member[123].nick': 'AliceNick',
        };
        expect(resolveTemplatePlaceholders('((member[123].nick|member[123].displayName|user[123].displayName|user[123].username))', updates3), 'AliceNick');

        final updates4 = {
          'member[123].displayName': 'AliceDisp',
        };
        expect(resolveTemplatePlaceholders('((member[123].nick|member[123].displayName|user[123].displayName|user[123].username))', updates4), 'AliceDisp');
      });

      test('resolves presence count fallbacks to 0 when missing', () {
        final updates = <String, String>{};
        expect(resolveTemplatePlaceholders('((guild.onlineMembers))', updates), '0');
        expect(resolveTemplatePlaceholders('((guild.offlineMembers))', updates), '0');
        expect(resolveTemplatePlaceholders('((guild.idleMembers))', updates), '0');
        expect(resolveTemplatePlaceholders('((guild.dndMembers))', updates), '0');
        expect(resolveTemplatePlaceholders('((guild.invisibleMembers))', updates), '0');
      });

      test('resolves servernames bracket function with slice and separator', () {
        final updates = {
          'bot.guildNames': 'Server A, Server B, Server C, Server D',
        };
        // Return all with custom separator
        expect(
          resolveTemplatePlaceholders('((servernames[-1; | ]))', updates),
          'Server A | Server B | Server C | Server D',
        );
        // Slice top 2 with custom separator
        expect(
          resolveTemplatePlaceholders('((servernames[2; + ]))', updates),
          'Server A + Server B',
        );
        // Default separation when missing
        expect(
          resolveTemplatePlaceholders('((servernames[3;]))', updates),
          'Server A, Server B, Server C',
        );
      });
    });
  });
}
