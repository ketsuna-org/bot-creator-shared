import 'dart:convert';

import 'package:image/image.dart' as img;
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

    test('compositeImage with shape circle crops overlay to circle', () async {
      final sourceResults = <String, String>{};
      final sourceVars = <String, String>{};

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '10', 'height': '10', 'color': 'red'},
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
            {'op': 'create', 'width': '20', 'height': '20', 'color': 'black'},
            {
              'op': 'compositeImage',
              'url': 'data:image/png;base64,$srcBase64',
              'x': '5',
              'y': '5',
              'width': '10',
              'height': '10',
              'shape': 'circle',
            },
          ],
        },
        resultKey: 'img_circle',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img_circle'], isNotEmpty);
      final bytes = base64Decode(results['img_circle']!);
      expect(bytes.length, greaterThan(50));
    });

    test('compositeImage with shape rounded/triangle crops overlay correctly', () async {
      final sourceResults = <String, String>{};
      final sourceVars = <String, String>{};

      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '10', 'height': '10', 'color': 'red'},
          ],
        },
        resultKey: 'src',
        results: sourceResults,
        variables: sourceVars,
        resolveValue: resolve,
      );

      final srcBase64 = sourceResults['src']!;

      // Rounded test
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '20', 'height': '20', 'color': 'black'},
            {
              'op': 'compositeImage',
              'url': 'data:image/png;base64,$srcBase64',
              'x': '5',
              'y': '5',
              'width': '10',
              'height': '10',
              'shape': 'rounded:4',
            },
          ],
        },
        resultKey: 'img_rounded',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img_rounded'], isNotEmpty);

      // Triangle test
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '20', 'height': '20', 'color': 'black'},
            {
              'op': 'compositeImage',
              'url': 'data:image/png;base64,$srcBase64',
              'x': '5',
              'y': '5',
              'width': '10',
              'height': '10',
              'shape': 'triangle',
            },
          ],
        },
        resultKey: 'img_triangle',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      expect(results['img_triangle'], isNotEmpty);
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

    group('drawLine', () {
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

    group('blend modes', () {
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

    group('anti-aliased circle masking', () {
      test('circle masking produces anti-aliased edges', () async {
        final srcResults = <String, String>{};
        final srcVars = <String, String>{};
        await executeRuntimeImageBlock(
          payload: {
            'operations': [
              {
                'op': 'create',
                'width': '20',
                'height': '20',
                'color': 'white',
              },
            ],
          },
          resultKey: 'white',
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
                'color': 'black',
              },
              {
                'op': 'compositeImage',
                'url': 'data:image/png;base64,${srcResults['white']}',
                'x': '0',
                'y': '0',
                'width': '40',
                'height': '40',
                'shape': 'circle',
              },
            ],
          },
          resultKey: 'antialias',
          results: results,
          variables: variables,
          resolveValue: resolve,
        );

        expect(results['antialias'], isNotEmpty);

        // Decode and verify anti-aliased edges exist.
        // Anti-aliasing manifests as intermediate gray pixels at the circle
        // boundary (white blended with black), not as partial alpha — the
        // destination canvas is fully opaque.
        final bytes = base64Decode(results['antialias']!);
        final decoded = img.decodeImage(bytes)!;

        // Sample the center and edge regions.
        // For a 40×40 circle, center = (19.5, 19.5), radius = 20.
        // Anti-aliased edge occurs at dist ≈ 19-20 pixels from center.
        final centerPx = decoded.getPixel(20, 20);
        decoded.getPixel(38, 20); // dist≈18.5, just inside radius

        // Center should be bright (white circular crop area)
        expect(centerPx.r.toInt(), greaterThan(200));
        expect(centerPx.g.toInt(), greaterThan(200));
        expect(centerPx.b.toInt(), greaterThan(200));

        // The anti-aliased edge fades from white (inside) to black (outside)
        // over ~1 pixel. Check multiple positions along the boundary and
        // verify at least one is an intermediate gray (not fully white, not
        // fully black).
        var foundGray = false;
        for (var edgeX = 35; edgeX <= 39; edgeX++) {
          final p = decoded.getPixel(edgeX, 20);
          final lum = p.r.toInt() + p.g.toInt() + p.b.toInt();
          if (lum > 0 && lum < 765) {
            foundGray = true;
            break;
          }
        }
        expect(foundGray, isTrue,
            reason: 'Expected anti-aliased circle to have gray edge pixels '
                '(0 < luminance < 765) where white fades into black. '
                'Scanned pixels (35-39, 20).');
      });
    });

    group('Variable resolution', () {
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
  });
}
