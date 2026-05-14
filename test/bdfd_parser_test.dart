import 'package:bot_creator_shared/utils/bdfd_ast.dart';
import 'package:bot_creator_shared/utils/bdfd_lexer.dart';
import 'package:bot_creator_shared/utils/bdfd_parser.dart';
import 'package:test/test.dart';

void main() {
  group('BdfdParser', () {
    test('parses plain text into text nodes', () {
      final lexerResult = BdfdLexer().tokenize('Hello world');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      expect(result.ast.nodes, hasLength(1));
      expect(result.ast.nodes.single, isA<BdfdTextAst>());
      expect((result.ast.nodes.single as BdfdTextAst).value, 'Hello world');
    });

    test('parses nested functions with arguments', () {
      final lexerResult = BdfdLexer().tokenize(
        r'$description[Hello $username in $if[((score))>10;gold;silver]]',
      );
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      expect(result.ast.nodes, hasLength(1));

      final root = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(root.normalizedName, 'description');
      expect(root.arguments, hasLength(1));
      expect(root.arguments.single, hasLength(4));
      expect(root.arguments.single[0], isA<BdfdTextAst>());
      expect(root.arguments.single[1], isA<BdfdFunctionCallAst>());
      expect(root.arguments.single[2], isA<BdfdTextAst>());
      expect(root.arguments.single[3], isA<BdfdFunctionCallAst>());

      final nestedIf = root.arguments.single[3] as BdfdFunctionCallAst;
      expect(nestedIf.normalizedName, 'if');
      expect(nestedIf.arguments, hasLength(3));
    });

    test('keeps trailing empty arguments', () {
      final lexerResult = BdfdLexer().tokenize(r'$addField[Name;Value;]');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isEmpty);
      final function = result.ast.nodes.single as BdfdFunctionCallAst;
      expect(function.arguments, hasLength(3));
      expect(function.arguments[2], isEmpty);
    });

    test('reports missing closing brackets as parser diagnostics', () {
      final lexerResult = BdfdLexer().tokenize(r'$if[cond;yes');
      final result = BdfdParser().parseTokens(lexerResult.tokens);

      expect(result.diagnostics, isNotEmpty);
      expect(
        result.diagnostics.single.message,
        contains('Expected closing bracket'),
      );
    });

    group('component/interaction functions', () {
      test(r'parses $addButton with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$addButton[Click me;primary;btn1;no;]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addbutton');
        expect(fn.arguments, hasLength(5));
      });

      test(r'parses $addSelectMenuOption with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$addSelectMenuOption[Option 1;opt1;Description;no]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addselectmenuoption');
        expect(fn.arguments, hasLength(4));
      });

      test(r'parses $addSeparator without arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$addSeparator');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addseparator');
        expect(fn.arguments, isEmpty);
      });

      test(r'parses $addTextDisplay with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$addTextDisplay[Hello world]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addtextdisplay');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $addTextInput with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$addTextInput[Name;short;name;Enter name;no]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addtextinput');
        expect(fn.arguments, hasLength(5));
      });

      test(r'parses $editButton with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$editButton[btn1;New label;secondary]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'editbutton');
        expect(fn.arguments, hasLength(3));
      });

      test(r'parses $editSelectMenu with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$editSelectMenu[menu1;Choose;1;3]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'editselectmenu');
        expect(fn.arguments, hasLength(4));
      });

      test(r'parses $editSelectMenuOption with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$editSelectMenuOption[opt1;New label;New desc;no]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'editselectmenuoption');
        expect(fn.arguments, hasLength(4));
      });

      test(r'parses $newModal with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$newModal[My Modal;modal1]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'newmodal');
        expect(fn.arguments, hasLength(2));
      });

      test(r'parses $newSelectMenu with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$newSelectMenu[menu1;string;Choose;1;3]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'newselectmenu');
        expect(fn.arguments, hasLength(5));
      });

      test(r'parses $removeAllComponents and $removeAllComponents[]', () {
        for (final code in [
          r'$removeAllComponents',
          r'$removeAllComponents[]',
        ]) {
          final lexerResult = BdfdLexer().tokenize(code);
          final result = BdfdParser().parseTokens(lexerResult.tokens);

          expect(result.diagnostics, isEmpty);
          final fn = result.ast.nodes.single as BdfdFunctionCallAst;
          expect(fn.normalizedName, 'removeallcomponents');
        }
      });

      test(r'parses $removeButtons and $removeButtons[]', () {
        for (final code in [r'$removeButtons', r'$removeButtons[]']) {
          final lexerResult = BdfdLexer().tokenize(code);
          final result = BdfdParser().parseTokens(lexerResult.tokens);

          expect(result.diagnostics, isEmpty);
          final fn = result.ast.nodes.single as BdfdFunctionCallAst;
          expect(fn.normalizedName, 'removebuttons');
        }
      });

      test(r'parses $removeComponent with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$removeComponent[btn1]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'removecomponent');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $defer with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$defer');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'defer');
        expect(fn.arguments, isEmpty);
      });

      test(r'parses $input with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$input[name]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'input');
        expect(fn.arguments, hasLength(1));
      });
    });

    group('embed functions', () {
      test(r'parses $title with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$title[Server Info]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'title');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $description with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$description[Welcome]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'description');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $color with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$color[#ffcc00]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'color');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $footer with text and icon', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$footer[My footer;https://example.com/icon.png]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'footer');
        expect(fn.arguments, hasLength(2));
      });

      test(r'parses $footerIcon with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$footerIcon[https://example.com/icon.png]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'footericon');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $image with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$image[https://example.com/img.png]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'image');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $thumbnail with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$thumbnail[https://example.com/thumb.png]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'thumbnail');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $author with name, icon, and url', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$author[Jeremy;https://example.com/icon.png;https://example.com]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'author');
        expect(fn.arguments, hasLength(3));
      });

      test(r'parses $authorIcon with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$authorIcon[https://example.com/icon.png]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'authoricon');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $authorURL with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$authorURL[https://example.com]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'authorurl');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $addField with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$addField[Name;Value;yes]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addfield');
        expect(fn.arguments, hasLength(3));
      });

      test(r'parses $addTimestamp and $addTimestamp[]', () {
        for (final code in [r'$addTimestamp', r'$addTimestamp[]']) {
          final lexerResult = BdfdLexer().tokenize(code);
          final result = BdfdParser().parseTokens(lexerResult.tokens);

          expect(result.diagnostics, isEmpty);
          final fn = result.ast.nodes.single as BdfdFunctionCallAst;
          expect(fn.normalizedName, 'addtimestamp');
        }
      });

      test(r'parses $embeddedURL with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$embeddedURL[https://example.com]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'embeddedurl');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $addContainer with arguments', () {
        final lexerResult = BdfdLexer().tokenize(r'$addContainer[#ff0000]');
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addcontainer');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $addSection with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$addSection[Section content]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addsection');
        expect(fn.arguments, hasLength(1));
      });

      test(r'parses $addThumbnail with arguments', () {
        final lexerResult = BdfdLexer().tokenize(
          r'$addThumbnail[https://example.com/thumb.png]',
        );
        final result = BdfdParser().parseTokens(lexerResult.tokens);

        expect(result.diagnostics, isEmpty);
        final fn = result.ast.nodes.single as BdfdFunctionCallAst;
        expect(fn.normalizedName, 'addthumbnail');
        expect(fn.arguments, hasLength(1));
      });
    });

    group('user/profile functions', () {
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
  });
}
