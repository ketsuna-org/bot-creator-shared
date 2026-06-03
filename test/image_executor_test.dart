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

    test('creates a blank canvas and encodes to base64 PNG', () {
      executeRuntimeImageBlock(
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
      // Verify it's valid base64
      final bytes = base64Decode(results['img0']!);
      expect(bytes.length, greaterThan(50));
      // Verify PNG magic bytes
      expect(bytes[0], 0x89);
      expect(bytes[1], 0x50); // 'P'
      expect(bytes[2], 0x4E); // 'N'
      expect(bytes[3], 0x47); // 'G'

      // Check dataUrl was generated
      expect(variables['img0.dataUrl'], startsWith('data:image/png;base64,'));
    });

    test('drawText renders text on canvas', () {
      executeRuntimeImageBlock(
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

    test('drawCircle fills a circle', () {
      executeRuntimeImageBlock(
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

    test('drawRect draws a filled rectangle', () {
      executeRuntimeImageBlock(
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

    test('compositeImage overlays an image', () {
      // Create a small 10x10 red PNG as overlay
      final overlayPayload = {
        'operations': [
          {'op': 'create', 'width': '10', 'height': '10', 'color': 'red'},
        ],
      };
      final overlayResults = <String, String>{};
      final overlayVars = <String, String>{};

      executeRuntimeImageBlock(
        payload: overlayPayload,
        resultKey: 'overlay',
        results: overlayResults,
        variables: overlayVars,
        resolveValue: resolve,
      );

      final overlayBase64 = overlayResults['overlay']!;

      executeRuntimeImageBlock(
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
              'dataUrl': 'data:image/png;base64,$overlayBase64',
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

    test('loadImage from data URL', () {
      // First create an image to use as source
      final sourcePayload = {
        'operations': [
          {'op': 'create', 'width': '30', 'height': '30', 'color': 'green'},
        ],
      };
      final sourceResults = <String, String>{};
      final sourceVars = <String, String>{};

      executeRuntimeImageBlock(
        payload: sourcePayload,
        resultKey: 'src',
        results: sourceResults,
        variables: sourceVars,
        resolveValue: resolve,
      );

      final srcBase64 = sourceResults['src']!;

      executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'loadImage',
              'dataUrl': 'data:image/png;base64,$srcBase64',
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

    test('empty operations returns empty', () {
      executeRuntimeImageBlock(
        payload: {'operations': <Map<String, dynamic>>[]},
        resultKey: 'img6',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img6'], '');
      expect(variables['img6'], '');
    });

    test('no operations returns empty', () {
      executeRuntimeImageBlock(
        payload: <String, dynamic>{},
        resultKey: 'img7',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img7'], '');
      expect(variables['img7'], '');
    });

    test('supports template placeholders in parameters', () {
      variables['myText'] = 'Dynamic Text';
      variables['myColor'] = '#FF00FF';

      executeRuntimeImageBlock(
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
