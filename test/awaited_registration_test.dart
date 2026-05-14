import 'package:bot_creator_shared/utils/awaited_registration.dart';
import 'package:test/test.dart';

void main() {
  group('awaitedRegistrationSnapshot', () {
    test('normalizes equivalent map and json string payloads', () {
      final mapSnapshot = awaitedRegistrationSnapshot(<String, dynamic>{
        'name': 'say',
        'userId': '123',
        'channelId': '456',
        'createdAt': '2026-04-08T12:00:00.000Z',
      });
      final jsonSnapshot = awaitedRegistrationSnapshot(
        '{"channelId":"456","createdAt":"2026-04-08T12:00:00.000Z","userId":"123","name":"say"}',
      );

      expect(mapSnapshot, jsonSnapshot);
    });

    test('changes when awaited callback is re-armed', () {
      final original = awaitedRegistrationSnapshot(<String, dynamic>{
        'name': 'say',
        'userId': '123',
        'channelId': '456',
        'createdAt': '2026-04-08T12:00:00.000Z',
      });
      final rearmed = awaitedRegistrationSnapshot(<String, dynamic>{
        'name': 'say',
        'userId': '123',
        'channelId': '456',
        'createdAt': '2026-04-08T12:00:01.000Z',
      });

      expect(rearmed, isNot(original));
    });
  });
}
