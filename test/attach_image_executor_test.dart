import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

void main() {
  group('executeAttachImage', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    String resolve(String input) => input;

    /// Generates a small test PNG as a base64 data URL.
    String generateTestDataUrl(int width, int height) {
      final canvas = img.Image(width: width, height: height);
      img.fill(canvas, color: img.ColorRgba8(255, 0, 0, 255));
      final bytes = img.encodePng(canvas);
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }

    test('stores image as canvas attachment with correct variable key',
        () async {
      final dataUrl = generateTestDataUrl(10, 10);

      await executeAttachImage(
        payload: {
          'imageName': 'photo',
          'imageSource': dataUrl,
        },
        resultKey: 'attach0',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['attach0'], equals('attached'));
      expect(variables.containsKey('temp._canvasAttachment_photo'), isTrue);
      expect(variables['temp._canvasAttachment_photo'], isNotEmpty);
    });

    test('handles raw base64 imageSource (not data URL)', () async {
      final canvas = img.Image(width: 10, height: 10);
      img.fill(canvas, color: img.ColorRgba8(0, 255, 0, 255));
      final rawBase64 = base64Encode(img.encodePng(canvas));

      await executeAttachImage(
        payload: {
          'imageName': 'green',
          'imageSource': rawBase64,
        },
        resultKey: 'attach1',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['attach1'], equals('attached'));
      expect(variables.containsKey('temp._canvasAttachment_green'), isTrue);
      final stored = variables['temp._canvasAttachment_green']!;
      // Verify it's valid base64
      expect(base64Decode(stored).length, greaterThan(10));
    });

    test('throws when imageName is empty', () async {
      expect(
        () => executeAttachImage(
          payload: {
            'imageName': '',
            'imageSource': generateTestDataUrl(10, 10),
          },
          resultKey: 'attach2',
          results: results,
          variables: variables,
          resolveValue: resolve,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('imageName is required'),
          ),
        ),
      );
    });

    test('throws when imageSource is empty', () async {
      expect(
        () => executeAttachImage(
          payload: {
            'imageName': 'test',
            'imageSource': '',
          },
          resultKey: 'attach3',
          results: results,
          variables: variables,
          resolveValue: resolve,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('imageSource is required'),
          ),
        ),
      );
    });

    test('throws when imageSource is invalid (cannot be resolved)', () async {
      expect(
        () => executeAttachImage(
          payload: {
            'imageName': 'bad',
            'imageSource': '!!!not-valid-base64-or-url!!!',
          },
          resultKey: 'attach4',
          results: results,
          variables: variables,
          resolveValue: resolve,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('failed to load image from source'),
          ),
        ),
      );
    });

    test('resolves template placeholders in imageName and imageSource',
        () async {
      variables['myName'] = 'dynamic_photo';
      final dataUrl = generateTestDataUrl(10, 10);
      variables['mySource'] = dataUrl;

      await executeAttachImage(
        payload: {
          'imageName': '((myName))',
          'imageSource': '((mySource))',
        },
        resultKey: 'attach5',
        results: results,
        variables: variables,
        resolveValue: (input) {
          if (input == '((myName))') return 'dynamic_photo';
          if (input == '((mySource))') return dataUrl;
          return input;
        },
      );

      expect(results['attach5'], equals('attached'));
      expect(
        variables.containsKey('temp._canvasAttachment_dynamic_photo'),
        isTrue,
      );
    });

    test('trims whitespace from resolved imageName', () async {
      final dataUrl = generateTestDataUrl(10, 10);

      await executeAttachImage(
        payload: {
          'imageName': '  spaces  ',
          'imageSource': dataUrl,
        },
        resultKey: 'attach6',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(
        variables.containsKey('temp._canvasAttachment_spaces'),
        isTrue,
      );
    });

    test('preserves imageName special characters', () async {
      final dataUrl = generateTestDataUrl(10, 10);

      await executeAttachImage(
        payload: {
          'imageName': 'my-image_v2',
          'imageSource': dataUrl,
        },
        resultKey: 'attach7',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(
        variables.containsKey('temp._canvasAttachment_my-image_v2'),
        isTrue,
      );
    });
  });

  group('resolveImageSource', () {
    test('resolves data URL to bytes', () async {
      final canvas = img.Image(width: 5, height: 5);
      img.fill(canvas, color: img.ColorRgba8(255, 0, 0, 255));
      final dataUrl =
          'data:image/png;base64,${base64Encode(img.encodePng(canvas))}';

      final bytes = await resolveImageSource(dataUrl);
      expect(bytes, isNotNull);
      expect(bytes!.length, greaterThan(10));
    });

    test('resolves raw base64 to bytes', () async {
      final rawBase64 = base64Encode([1, 2, 3, 4, 5]);

      final bytes = await resolveImageSource(rawBase64);
      expect(bytes, isNotNull);
      expect(bytes, equals([1, 2, 3, 4, 5]));
    });

    test('returns null for empty source', () async {
      final bytes = await resolveImageSource('');
      expect(bytes, isNull);
    });

    test('returns null for invalid source', () async {
      // '!!!' is not valid base64 (length not multiple of 4 + invalid chars)
      final bytes = await resolveImageSource('!!!');
      expect(bytes, isNull);
    });

    test('uses urlCache when provided', () async {
      final cache = LruCache<Uint8List>(1024);

      cache['http://example.com/img.png'] = Uint8List.fromList([1, 2, 3]);
      final bytes = await resolveImageSource(
        'http://example.com/img.png',
        urlCache: cache,
      );
      expect(bytes, equals([1, 2, 3]));
    });
  });
}
