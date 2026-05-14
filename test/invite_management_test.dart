import 'package:bot_creator_shared/actions/invite_management.dart';
import 'package:nyxx/nyxx.dart';
import 'package:test/test.dart';

void main() {
  group('invite management helpers', () {
    test('resolveInviteChannelId prefers explicit channelId when valid', () {
      final fallback = Snowflake(999);
      final resolved = resolveInviteChannelId(
        payload: <String, dynamic>{'channelId': '123456'},
        resolve: (input) => input,
        fallbackChannelId: fallback,
      );
      expect(resolved?.toString(), '123456');
    });

    test(
      'resolveInviteChannelId falls back when payload channelId is empty',
      () {
        final fallback = Snowflake(888);
        final resolved = resolveInviteChannelId(
          payload: <String, dynamic>{'channelId': ''},
          resolve: (input) => input,
          fallbackChannelId: fallback,
        );
        expect(resolved, fallback);
      },
    );

    test('buildInviteUrl returns canonical discord invite URL', () {
      expect(buildInviteUrl('abc123'), 'https://discord.gg/abc123');
    });
  });
}
