import 'dart:convert';

import 'package:image/image.dart' as img;
import 'package:test/test.dart';

import 'package:bot_creator_shared/actions/executors/image_executor.dart';

/// Manual equivalent of _collectCanvasAttachments for testing purposes.
/// The real function is private in respond_with_message.dart, so we replicate
/// the logic here for integration testing.

void main() {
  group('attachImage integration with canvas attachment flow', () {
    late Map<String, String> results;
    late Map<String, String> variables;

    setUp(() {
      results = <String, String>{};
      variables = <String, String>{};
    });

    String resolve(String input) => input;

    /// Generates a small test PNG as a base64 data URL.
    String _generateTestDataUrl(int width, int height) {
      final canvas = img.Image(width: width, height: height);
      img.fill(canvas, color: img.ColorRgba8(255, 0, 0, 255));
      final bytes = img.encodePng(canvas);
      return 'data:image/png;base64,${base64Encode(bytes)}';
    }

    test(
        'executeAttachImage stores variable in format recognized by canvas attachment collector',
        () async {
      final dataUrl = _generateTestDataUrl(10, 10);

      // Step 1: Execute attachImage
      await executeAttachImage(
        payload: {
          'imageName': 'test_card',
          'imageSource': dataUrl,
        },
        resultKey: 'attach_integration',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      // Step 2: Verify the variable key format
      expect(results['attach_integration'], equals('attached'));
      expect(
        variables.containsKey('temp._canvasAttachment_test_card'),
        isTrue,
      );

      // Step 3: Simulate what respondWithMessage does — collect canvas attachments
      final attachmentEntries = variables.entries
          .where((e) =>
              e.key.startsWith('temp._canvasAttachment_') && e.value.isNotEmpty)
          .toList();

      expect(attachmentEntries.length, equals(1));
      expect(attachmentEntries.first.key,
          equals('temp._canvasAttachment_test_card'));

      // Step 4: Verify the stored value is valid base64
      final storedBase64 = variables['temp._canvasAttachment_test_card']!;
      final decoded = base64Decode(storedBase64);
      expect(decoded.length, greaterThan(10));

      // Step 5: Extract filename from key (matching _collectCanvasAttachments logic)
      final name = attachmentEntries.first.key
          .substring('temp._canvasAttachment_'.length);
      expect(name, equals('test_card'));
    });

    test('multiple attachImage calls create separate variables', () async {
      final dataUrl1 = _generateTestDataUrl(5, 5);
      final dataUrl2 = _generateTestDataUrl(8, 8);
      final dataUrl3 = _generateTestDataUrl(3, 3);

      // Execute 3 attachImage calls with different names
      await executeAttachImage(
        payload: {'imageName': 'card_a', 'imageSource': dataUrl1},
        resultKey: 'att1',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      await executeAttachImage(
        payload: {'imageName': 'card_b', 'imageSource': dataUrl2},
        resultKey: 'att2',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      await executeAttachImage(
        payload: {'imageName': 'card_c', 'imageSource': dataUrl3},
        resultKey: 'att3',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      // Verify all 3 are present
      final attachmentEntries = variables.entries
          .where((e) =>
              e.key.startsWith('temp._canvasAttachment_') && e.value.isNotEmpty)
          .toList();

      expect(attachmentEntries.length, equals(3));

      // Verify each has distinct base64 content
      final values = attachmentEntries.map((e) => e.value).toSet();
      expect(values.length, equals(3),
          reason: 'Each attachment should have unique content');

      // Verify result keys
      expect(results['att1'], equals('attached'));
      expect(results['att2'], equals('attached'));
      expect(results['att3'], equals('attached'));
    });

    test('empty canvas attachments are skipped by collector', () async {
      // Simulate: no attachments created
      final attachmentEntries = variables.entries
          .where((e) =>
              e.key.startsWith('temp._canvasAttachment_') && e.value.isNotEmpty)
          .toList();

      expect(attachmentEntries, isEmpty);

      // Simulate: empty value attachment (should be skipped)
      variables['temp._canvasAttachment_empty'] = '';

      final afterEmpty = variables.entries
          .where((e) =>
              e.key.startsWith('temp._canvasAttachment_') && e.value.isNotEmpty)
          .toList();

      expect(afterEmpty, isEmpty,
          reason: 'Attachments with empty values should be skipped');
    });

    test('non-base64 canvas attachment values are skipped by collector',
        () async {
      // Simulate an invalid attachment stored directly
      variables['temp._canvasAttachment_bad'] = '!!!not-valid-base64!!!';

      // Try to decode it like the collector would
      bool decodeSucceeded = true;
      try {
        base64Decode(variables['temp._canvasAttachment_bad']!);
      } catch (_) {
        decodeSucceeded = false;
      }

      expect(decodeSucceeded, isFalse,
          reason: 'Invalid base64 should fail decoding');
    });

    test('respond_with_message_attachments roundtrip', () async {
      // This test validates that the variable key format matches what
      // respondWithMessage expects. The respond_with_message_attachments_test.dart
      // already covers this with mock interaction tests.

      final dataUrl = _generateTestDataUrl(10, 10);

      await executeAttachImage(
        payload: {
          'imageName': 'roundtrip',
          'imageSource': dataUrl,
        },
        resultKey: 'rt',
        results: results,
        variables: variables,
        resolveValue: resolve,
      );

      // The keys used by respond_with_message's _collectCanvasAttachments:
      // - prefix: 'temp._canvasAttachment_'
      // - filename: '<name>.png'

      final storedKey = 'temp._canvasAttachment_roundtrip';
      expect(variables.containsKey(storedKey), isTrue);

      // The base64 value should start with 'iVBOR' (PNG header in base64)
      expect(variables[storedKey]!.startsWith('iVBOR'), isTrue,
          reason: 'PNG images start with iVBOR in base64');
    });
  });
}
