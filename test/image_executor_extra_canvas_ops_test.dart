import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

/// Runtime tests for the extra canvas operations:
/// progressBar, setPixel, invert, grayscale, rotate.
void main() {
  group('Image Executor — Extra Canvas Ops', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    String resolve(String input) => input;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    img.Image decode(String key) =>
        img.decodeImage(base64Decode(results[key]!))!;

    test('progressBar draws bar and track regions', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '100', 'height': '50', 'color': 'black'},
            {
              'op': 'progressBar',
              'x': '10',
              'y': '10',
              'width': '80',
              'height': '30',
              'percentage': '50',
              'barColor': 'red',
              'trackColor': 'blue',
              'textColor': 'white',
              'borderWidth': '0',
              'fontSize': '14',
            },
          ],
        },
        resultKey: 'img',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      final image = decode('img');
      // Bar fills the left half (x in [10,50)). Sample near the top edge to
      // avoid the centered percentage label.
      final barPixel = image.getPixel(20, 11);
      expect(barPixel.r, greaterThan(150)); // red dominant
      // Track fills the right half (x in [50,90)).
      final trackPixel = image.getPixel(70, 11);
      expect(trackPixel.b, greaterThan(150)); // blue dominant
    });

    test('progressBar draws rounded corners when borderRadius is specified', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '100', 'height': '50', 'color': 'black'},
            {
              'op': 'progressBar',
              'x': '10',
              'y': '10',
              'width': '80',
              'height': '30',
              'percentage': '0',
              'barColor': 'red',
              'trackColor': 'blue',
              'textColor': 'white',
              'borderWidth': '0',
              'borderRadius': '10',
              'fontSize': '14',
            },
          ],
        },
        resultKey: 'img',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      final image = decode('img');
      // Corner pixel (10, 10) is outside the rounded corner (radius 10) -> remains black
      final cornerPixel = image.getPixel(10, 10);
      expect(cornerPixel.b, 0); // Not blue
      expect(cornerPixel.r, 0); // Not red

      // Edge pixel (20, 10) is inside -> painted blue
      final insidePixel = image.getPixel(20, 10);
      expect(insidePixel.b, greaterThan(150)); // blue track
    });

    test('progressBar vertical orientation fills from the bottom', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '40', 'height': '100', 'color': 'black'},
            {
              'op': 'progressBar',
              'x': '10',
              'y': '10',
              'width': '20',
              'height': '80',
              'percentage': '50',
              'barColor': 'red',
              'trackColor': 'blue',
              'textColor': 'white',
              'borderWidth': '0',
              'orientation': 'vertical',
              'fontSize': '14',
            },
          ],
        },
        resultKey: 'img',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      final image = decode('img');
      // Vertical bar: bottom half filled with bar color.
      final bottomPixel = image.getPixel(15, 80);
      expect(bottomPixel.r, greaterThan(150)); // red
      // Top half is track.
      final topPixel = image.getPixel(15, 20);
      expect(topPixel.b, greaterThan(150)); // blue
    });

    test('setPixel writes a single pixel and leaves others untouched',
        () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '10', 'height': '10', 'color': 'black'},
            {'op': 'setPixel', 'x': '5', 'y': '5', 'color': 'white'},
          ],
        },
        resultKey: 'img',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      final image = decode('img');
      expect(image.getPixel(5, 5).r, 255);
      expect(image.getPixel(0, 0).r, 0);
    });

    test('invert inverts RGB channels (alpha preserved)', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '4', 'height': '4', 'color': 'red'},
            {'op': 'invert'},
          ],
        },
        resultKey: 'img',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      final image = decode('img');
      final p = image.getPixel(0, 0);
      // invert(255,0,0) = (0,255,255); alpha stays opaque.
      expect(p.r, lessThan(10));
      expect(p.g, greaterThan(200));
      expect(p.b, greaterThan(200));
      expect(p.a, 255);
    });

    test('grayscale equalizes RGB channels', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '4', 'height': '4', 'color': 'red'},
            {'op': 'grayscale'},
          ],
        },
        resultKey: 'img',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      final image = decode('img');
      final p = image.getPixel(0, 0);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();
      expect(r, closeTo(g, 5));
      expect(g, closeTo(b, 5));
    });

    test('rotate by 90 swaps the canvas dimensions', () async {
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '20', 'height': '10', 'color': 'blue'},
            {'op': 'rotate', 'angle': '90'},
          ],
        },
        resultKey: 'img',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      final image = decode('img');
      expect(image.width, 10);
      expect(image.height, 20);
    });
  });
}
