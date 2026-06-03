import 'dart:convert';

import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

void main() {
  group('Image Executor', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    String resolve(String input) => input;

    test('creates a blank canvas and encodes to base64 PNG', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '100',
              'height': '50',
              'color': 'red',
            },
          ],
        },
        resultKey: 'img0',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img0'], isNotEmpty);
      final bytes = base64Decode(results['img0']!);
      expect(bytes.length, greaterThan(50));
      // Verify PNG magic bytes
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50);
      expect(bytes[2], 0x4E);
      expect(bytes[3], 0x47);
      expect(variables['img0.dataUrl'], startsWith('data:image/png;base64,'));
    });

    test('drawText renders text on canvas', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '200', 'height': '60', 'color': 'black'},
            {
              'op': 'drawText',
              'text': 'Hello!',
              'x': '10',
              'y': '20',
              'fontSize': '14',
              'color': 'white',
            },
          ],
        },
        resultKey: 'img1',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img1'], isNotEmpty);
      final bytes = base64Decode(results['img1']!);
      expect(bytes.length, greaterThan(100));
    });

    test('drawCircle fills a circle', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '100', 'height': '100', 'color': 'white'},
            {
              'op': 'drawCircle',
              'x': '50',
              'y': '50',
              'radius': '30',
              'color': 'blue',
              'fill': 'true',
            },
          ],
        },
        resultKey: 'img2',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img2'], isNotEmpty);
      final bytes = base64Decode(results['img2']!);
      expect(bytes.length, greaterThan(80));
    });

    test('drawRect draws a filled rectangle', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '100', 'height': '100', 'color': 'black'},
            {
              'op': 'drawRect',
              'x': '10',
              'y': '10',
              'width': '80',
              'height': '30',
              'color': 'green',
              'fill': 'true',
            },
          ],
        },
        resultKey: 'img3',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img3'], isNotEmpty);
      final bytes = base64Decode(results['img3']!);
      expect(bytes.length, greaterThan(80));
    });

    test('compositeImage overlays an image', () async {
      final overlayResults = <String, String>{};
      final overlayVars = <String, String>{};

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '10', 'height': '10', 'color': 'red'},
          ],
        },
        resultKey: 'overlay',
        results: overlayResults,
        variables: overlayVars,
        resolveValue: resolve,
      );

      final overlayBase64 = overlayResults['overlay']!;

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '50',
              'height': '50',
              'color': 'black',
            },
            {
              'op': 'compositeImage',
              'url': 'data:image/png;base64,$overlayBase64',
              'x': '20',
              'y': '20',
            },
          ],
        },
        resultKey: 'img4',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img4'], isNotEmpty);
      final bytes = base64Decode(results['img4']!);
      expect(bytes.length, greaterThan(100));
    });

    test('loadImage from data URL using url key', () async {
      final sourceResults = <String, String>{};
      final sourceVars = <String, String>{};

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '30', 'height': '30', 'color': 'green'},
          ],
        },
        resultKey: 'src',
        results: sourceResults,
        variables: sourceVars,
        resolveValue: resolve,
      );

      final srcBase64 = sourceResults['src']!;

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'loadImage',
              'url': 'data:image/png;base64,$srcBase64',
            },
          ],
        },
        resultKey: 'img5',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img5'], isNotEmpty);
    });

    test('loadImage from raw base64 using url key', () async {
      final sourceResults = <String, String>{};
      final sourceVars = <String, String>{};

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '20', 'height': '20', 'color': 'blue'},
          ],
        },
        resultKey: 'rawSrc',
        results: sourceResults,
        variables: sourceVars,
        resolveValue: resolve,
      );

      final rawBase64 = sourceResults['rawSrc']!;

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'loadImage',
              'url': rawBase64, // raw base64, not a data URL
            },
          ],
        },
        resultKey: 'img5b',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img5b'], isNotEmpty);
    });

    test('loadImage with legacy dataUrl key still works', () async {
      final sourceResults = <String, String>{};
      final sourceVars = <String, String>{};

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '20', 'height': '20', 'color': 'red'},
          ],
        },
        resultKey: 'legacySrc',
        results: sourceResults,
        variables: sourceVars,
        resolveValue: resolve,
      );

      final base64 = sourceResults['legacySrc']!;

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'loadImage',
              'dataUrl': 'data:image/png;base64,$base64',
            },
          ],
        },
        resultKey: 'img5c',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img5c'], isNotEmpty);
    });

    test('loadImage with invalid URL returns current canvas unchanged',
        () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '50', 'height': '50', 'color': 'black'},
            {
              'op': 'loadImage',
              'url': 'not-a-valid-url-or-base64!!!',
            },
          ],
        },
        resultKey: 'img5d',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      // Should still produce an image (the black canvas, unchanged)
      expect(results['img5d'], isNotEmpty);
      final bytes = base64Decode(results['img5d']!);
      expect(bytes.length, greaterThan(50));
    });

    test('empty operations returns empty', () async {
      await executeRuntimeImageBlock(
        payload: {'operations': <Map<String, dynamic>>[]},
        resultKey: 'img6',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img6'], '');
      expect(variables['img6'], '');
    });

    test('no operations returns empty', () async {
      await executeRuntimeImageBlock(
        payload: <String, dynamic>{},
        resultKey: 'img7',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img7'], '');
      expect(variables['img7'], '');
    });

    test('supports template placeholders in parameters', () async {
      variables['myText'] = 'Dynamic Text';
      variables['myColor'] = '#FF00FF';

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '100',
              'height': '40',
              'color': 'black',
            },
            {
              'op': 'drawText',
              'text': '((myText))',
              'x': '5',
              'y': '15',
              'fontSize': '14',
              'color': '((myColor))',
            },
          ],
        },
        resultKey: 'img8',
        results: results,
        variables: variables,
        resolveValue: (input) {
          if (input == '((myText))') return 'Dynamic Text';
          if (input == '((myColor))') return '#FF00FF';
          return input;
        },
      );

      expect(results['img8'], isNotEmpty);
    });
  });
}
