import 'package:bot_creator_shared/utils/bdfd_autocomplete.dart';
import 'package:test/test.dart';

void main() {
  group('bdfdAutocompleteTemplates', () {
    test('contains supported inline placeholders and functions', () {
      expect(bdfdAutocompleteTemplates['args'], r'$args[]');
      expect(bdfdAutocompleteTemplates['authorid'], r'$authorID');
      expect(bdfdAutocompleteTemplates['sendmessage'], r'$sendMessage[]');
      expect(bdfdAutocompleteTemplates['commandname'], r'$commandName');
    });

    test('contains control flow block helpers', () {
      expect(bdfdAutocompleteTemplates['if'], r'$if[]');
      expect(bdfdAutocompleteTemplates['elseif'], r'$elseif[]');
      expect(bdfdAutocompleteTemplates['endif'], r'$endif');
    });
  });
}
