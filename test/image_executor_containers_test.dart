import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

void main() {
  group('Image Executor — Containers Scope', () {
    String resolve(String input) => input;

    test('does not leak container positions between executions', () async {
      // First execution defines a container and uses it to position a rect
      final results1 = <String, String>{};
      final variables1 = <String, String>{};
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '100', 'height': '100', 'color': 'black'},
            {
              'op': 'container',
              'name': 'c1',
              'x': '10',
              'y': '10',
              'width': '50',
              'height': '50',
            },
            {
              'op': 'drawRect',
              'container': 'c1',
              'x': '0',
              'y': '0',
              'width': '10',
              'height': '10',
              'color': 'white',
              'fill': 'true',
            },
          ],
        },
        resultKey: 'r1',
        results: results1,
        variables: variables1,
        resolveValue: resolve,
      );

      // Second execution does NOT define the container, but tries to use it.
      // It should NOT find the container 'c1' and therefore not apply the offset (10, 10).
      final results2 = <String, String>{};
      final variables2 = <String, String>{};
      await executeRuntimeImageBlock(
        payload: {
          'operations': [
            {'op': 'create', 'width': '100', 'height': '100', 'color': 'black'},
            {
              'op': 'drawRect',
              'container': 'c1',
              'x': '0',
              'y': '0',
              'width': '10',
              'height': '10',
              'color': 'white',
              'fill': 'true',
            },
          ],
        },
        resultKey: 'r2',
        results: results2,
        variables: variables2,
        resolveValue: resolve,
      );

      final img1 = img.decodeImage(base64Decode(results1['r1']!))!;
      final img2 = img.decodeImage(base64Decode(results2['r2']!))!;

      // Pixel at (0, 0) should be black in img1 (due to container offset (10,10))
      // and white in img2 (no offset applied)
      final p1 = img1.getPixel(0, 0);
      final p2 = img2.getPixel(0, 0);

      expect(p1.r.toInt(), equals(0));
      expect(p2.r.toInt(), equals(255));
    });
  });
}
