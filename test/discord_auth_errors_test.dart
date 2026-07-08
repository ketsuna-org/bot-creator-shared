import 'package:bot_creator_shared/utils/discord_auth_errors.dart';
import 'package:test/test.dart';

void main() {
  group('isDiscordTokenUnauthorized', () {
    test('detects DiscordTokenUnauthorizedException', () {
      expect(
        isDiscordTokenUnauthorized(
          DiscordTokenUnauthorizedException('invalid token'),
        ),
        isTrue,
      );
    });

    test('detects REST 401 on applications/@me', () {
      expect(
        isDiscordTokenUnauthorized(
          Exception(
            '401: Unauthorized (0) GET https://discord.com/api/v10/applications/@me',
          ),
        ),
        isTrue,
      );
    });

    test('detects discord_token_invalid marker', () {
      expect(
        isDiscordTokenUnauthorized(Exception('discord_token_invalid')),
        isTrue,
      );
    });

    test('detects gateway authentication failure close code', () {
      expect(
        isDiscordTokenUnauthorized(
          Exception('Gateway disconnect: Authentication failed (4004)'),
        ),
        isTrue,
      );
    });

    test('ignores transient network errors', () {
      expect(
        isDiscordTokenUnauthorized(
          Exception('SocketException: Connection refused'),
        ),
        isFalse,
      );
    });

    test('ignores generic 500 errors', () {
      expect(
        isDiscordTokenUnauthorized(
          Exception('500: Internal Server Error GET https://discord.com/api/v10/gateway'),
        ),
        isFalse,
      );
    });
  });
}
