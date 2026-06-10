import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdParser - user/profile functions', () {
    for (final entry
        in <String, String>{
          r'$authorAvatar': 'authoravatar',
          r'$authorID': 'authorid',
          r'$authorOfMessage': 'authorofmessage',
          r'$creationDate': 'creationdate',
          r'$discriminator': 'discriminator',
          r'$getUserStatus': 'getuserstatus',
          r'$getCustomStatus': 'getcustomstatus',
          r'$isAdmin': 'isadmin',
          r'$isBooster': 'isbooster',
          r'$isBot': 'isbot',
          r'$isUserDMEnabled': 'isuserdmenabled',
          r'$userAvatar': 'useravatar',
          r'$userBadges': 'userbadges',
          r'$userBanner': 'userbanner',
          r'$userBannerColor': 'userbannercolor',
          r'$userExists': 'userexists',
          r'$userID': 'userid',
          r'$userInfo': 'userinfo',
          r'$userJoined': 'userjoined',
          r'$userJoinedDiscord': 'userjoineddiscord',
          r'$userPerms': 'userperms',
          r'$userServerAvatar': 'userserveravatar',
          r'$findUser': 'finduser',
        }.entries) {
      test('parses ${entry.key} without arguments', () {
        final lexerResult = BdfdLexer().tokenize(entry.key);
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, entry.value);
        expect(fn.arguments, isEmpty);
      });
    }

    test(r'parses $displayName without arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$displayName');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'displayname');
      expect(fn.arguments, isEmpty);
    });

    test(r'parses $displayName[] with user ID', () {
      final lexerResult = BdfdLexer().tokenize(r'$displayName[123456]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'displayname');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $nickname without arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$nickname');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'nickname');
      expect(fn.arguments, isEmpty);
    });

    test(r'parses $nickname[] with user ID', () {
      final lexerResult = BdfdLexer().tokenize(r'$nickname[123456]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'nickname');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $username without arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$username');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'username');
      expect(fn.arguments, isEmpty);
    });

    test(r'parses $username[] with user ID', () {
      final lexerResult = BdfdLexer().tokenize(r'$username[123456]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'username');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $changeUsername with arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$changeUsername[NewName]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'changeusername');
      expect(fn.arguments, hasLength(1));
    });

    test(r'parses $changeUsernameWithID with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$changeUsernameWithID[123456;NewName]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final fn = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(fn.normalizedName, 'changeusernamewithid');
      expect(fn.arguments, hasLength(2));
    });
  });
}
