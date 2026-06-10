import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
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

      test('resolves dataUrl property dynamically from base variable', () {
        final updates = {
          'rtImage_0': 'Zm9vYmFy',
        };
        expect(
          resolveTemplatePlaceholders('((rtImage_0.dataUrl))', updates),
          'data:image/png;base64,Zm9vYmFy',
        );
        expect(
          resolveTemplatePlaceholders('((rtImage_0.dataurl))', updates),
          'data:image/png;base64,Zm9vYmFy',
        );
      });
    });
  });
}
