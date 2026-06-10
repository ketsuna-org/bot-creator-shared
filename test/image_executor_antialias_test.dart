import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

void main() {
  group('Image Executor — Anti-aliased Circle Masking', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    String resolve(String input) => input;

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
}
