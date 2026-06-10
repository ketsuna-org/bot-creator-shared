import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

void main() {
  group('Image Executor — Variable Resolution', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    test('resolves ((variable)) placeholders in drawText', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '200', 'height': '60', 'color': 'black'},
            {
              'op': 'drawText',
              'text': '((user.name))',
              'x': '10',
              'y': '20',
              'fontSize': '14',
              'color': 'white',
            },
          ],
        },
        resultKey: 'resolved_text',
        results: results,
        variables: variables,
        resolveValue: (input) {
          if (input == '((user.name))') return 'Alice';
          return input;
        },
      );

      expect(results['resolved_text'], isNotEmpty);
      // Verify the image was generated (not empty)
      final bytes = base64Decode(results['resolved_text']!);
      expect(bytes.length, greaterThan(50));
    });

    test('resolves ((variable)) placeholders in loadImage URL', () async {
      // loadImage with a variable URL that resolves to a data URL
      final testDataUrl = 'data:image/png;base64,'
          '${base64Encode(img.encodePng(img.Image(width: 10, height: 10)))}';

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '100', 'height': '100', 'color': 'red'},
            {
              'op': 'loadImage',
              'url': '((image.url))',
            },
          ],
        },
        resultKey: 'resolved_url',
        results: results,
        variables: variables,
        resolveValue: (input) {
          if (input == '((image.url))') return testDataUrl;
          return input;
        },
      );

      expect(results['resolved_url'], isNotEmpty);
      final bytes = base64Decode(results['resolved_url']!);
      expect(bytes.length, greaterThan(50));
    });

    test('resolves variables in create dimensions', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '((canvas.w))',
              'height': '((canvas.h))',
              'color': 'blue',
            },
          ],
        },
        resultKey: 'resolved_dims',
        results: results,
        variables: variables,
        resolveValue: (input) {
          if (input == '((canvas.w))') return '120';
          if (input == '((canvas.h))') return '80';
          return input;
        },
      );

      expect(results['resolved_dims'], isNotEmpty);
      final bytes = base64Decode(results['resolved_dims']!);
      // 120x80 canvas with PNG header should be larger than 50 bytes
      expect(bytes.length, greaterThan(50));
    });

    test('unresolved placeholders render as literal text', () async {
      // When resolveValue returns the placeholder unchanged (no resolution),
      // the text should be rendered as-is on the canvas.
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '200', 'height': '60', 'color': 'black'},
            {
              'op': 'drawText',
              'text': '((unknown.var))',
              'x': '10',
              'y': '20',
              'fontSize': '14',
              'color': 'white',
            },
          ],
        },
        resultKey: 'unresolved',
        results: results,
        variables: variables,
        resolveValue: (input) => input, // No resolution — return as-is
      );

      expect(results['unresolved'], isNotEmpty);
      final bytes = base64Decode(results['unresolved']!);
      expect(bytes.length, greaterThan(50));
    });

    test('mixed text with variables and literals', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '200', 'height': '60', 'color': 'black'},
            {
              'op': 'drawText',
              'text': 'Hello ((user.name)), welcome!',
              'x': '10',
              'y': '20',
              'fontSize': '14',
              'color': 'white',
            },
          ],
        },
        resultKey: 'mixed',
        results: results,
        variables: variables,
        resolveValue: (input) {
          if (input == '((user.name))') return 'Alice';
          return input;
        },
      );

      expect(results['mixed'], isNotEmpty);
      final bytes = base64Decode(results['mixed']!);
      expect(bytes.length, greaterThan(50));
    });
  });
}
