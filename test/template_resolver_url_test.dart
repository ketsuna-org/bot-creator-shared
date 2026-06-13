import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:test/test.dart';

void main() {
  group('template_resolver — url function', () {
    test('resolves url[encode;...] bracket expression', () {
      expect(
        resolveTemplatePlaceholders('((url[encode;Hello world!!]))', {}),
        'Hello+world%21%21',
      );
    });

    test('resolves url[decode;...] bracket expression', () {
      expect(
        resolveTemplatePlaceholders('((url[decode;Hello+world%21%21]))', {}),
        'Hello world!!',
      );
    });

    test('resolves nested placeholders in url bracket expression', () {
      expect(
        resolveTemplatePlaceholders(
          '((url[encode;((var))]))',
          {'var': 'a b'},
        ),
        'a+b',
      );
    });

    test('resolves url function in standard expression', () {
      expect(
        resolveTemplatePlaceholders('((url("encode", "a b")))', {}),
        'a+b',
      );
    });
    
    test('handles invalid decode gracefully', () {
      // %zz is invalid hex
      expect(
        resolveTemplatePlaceholders('((url[decode;%zz]))', {}),
        '%zz',
      );
    });
  });
}
