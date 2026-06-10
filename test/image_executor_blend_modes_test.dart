import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

void main() {
  group('Image Executor — Blend Modes', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    String resolve(String input) => input;

    test('multiply blend darkens the overlay', () async {
      // Create a red overlay
      final redResults = <String, String>{};
      final redVars = <String, String>{};
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '20',
              'height': '20',
              'color': 'red',
            },
          ],
        },
        resultKey: 'red',
        results: redResults,
        variables: redVars,
        resolveValue: resolve,
      );

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '40',
              'height': '40',
              'color': '#808080',
            },
            {
              'op': 'compositeImage',
              'url': 'data:image/png;base64,${redResults['red']}',
              'x': '0',
              'y': '0',
              'blend': 'multiply',
            },
          ],
        },
        resultKey: 'multiply',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['multiply'], isNotEmpty);
    });

    test('screen blend lightens the overlay', () async {
      final whiteResults = <String, String>{};
      final whiteVars = <String, String>{};
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '10',
              'height': '10',
              'color': 'blue',
            },
          ],
        },
        resultKey: 'blue',
        results: whiteResults,
        variables: whiteVars,
        resolveValue: resolve,
      );

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '30',
              'height': '30',
              'color': '#404040',
            },
            {
              'op': 'compositeImage',
              'url': 'data:image/png;base64,${whiteResults['blue']}',
              'x': '0',
              'y': '0',
              'blend': 'screen',
            },
          ],
        },
        resultKey: 'screen',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['screen'], isNotEmpty);
    });

    test('overlay blend adds contrast', () async {
      final srcResults = <String, String>{};
      final srcVars = <String, String>{};
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '20',
              'height': '20',
              'color': '#808080',
            },
          ],
        },
        resultKey: 'src',
        results: srcResults,
        variables: srcVars,
        resolveValue: resolve,
      );

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '40',
              'height': '40',
              'color': '#606060',
            },
            {
              'op': 'compositeImage',
              'url': 'data:image/png;base64,${srcResults['src']}',
              'x': '0',
              'y': '0',
              'blend': 'overlay',
            },
          ],
        },
        resultKey: 'overlay',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['overlay'], isNotEmpty);
    });

    test('unknown blend mode falls back to normal (srcOver)', () async {
      final srcResults = <String, String>{};
      final srcVars = <String, String>{};
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {
              'op': 'create',
              'width': '10',
              'height': '10',
              'color': 'red',
            },
          ],
        },
        resultKey: 'red',
        results: srcResults,
        variables: srcVars,
        resolveValue: resolve,
      );

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
              'op': 'compositeImage',
              'url': 'data:image/png;base64,${srcResults['red']}',
              'x': '0',
              'y': '0',
              'blend': 'nonexistentBlendMode',
            },
          ],
        },
        resultKey: 'fallback',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['fallback'], isNotEmpty);
    });
  });
}
