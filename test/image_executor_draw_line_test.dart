import 'dart:convert';

import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

void main() {
  group('Image Executor — drawLine', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    String resolve(String input) => input;

    test('draws a single-pixel line', () async {
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
              'op': 'drawLine',
              'x1': '5',
              'y1': '5',
              'x2': '40',
              'y2': '40',
              'color': 'white',
              'thickness': '1',
            },
          ],
        },
        resultKey: 'line1',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['line1'], isNotEmpty);
      final bytes = base64Decode(results['line1']!);
      expect(bytes.length, greaterThan(100));
    });

    test('draws a thick line (thickness > 1)', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '100',
              'height': '50',
              'color': 'black',
            },
            {
              'op': 'drawLine',
              'x1': '10',
              'y1': '25',
              'x2': '90',
              'y2': '25',
              'color': 'red',
              'thickness': '5',
            },
          ],
        },
        resultKey: 'line2',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['line2'], isNotEmpty);
      final bytes = base64Decode(results['line2']!);
      expect(bytes.length, greaterThan(100));
    });

    test('line with off-canvas coordinates clips gracefully', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '30',
              'height': '30',
              'color': 'black',
            },
            {
              'op': 'drawLine',
              'x1': '-5',
              'y1': '-5',
              'x2': '35',
              'y2': '35',
              'color': 'white',
              'thickness': '2',
            },
          ],
        },
        resultKey: 'line3',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['line3'], isNotEmpty);
    });
  });
}
