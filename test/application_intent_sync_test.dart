import 'dart:convert';

import 'package:bot_creator_shared/utils/application_intent_sync.dart';
import 'package:bot_creator_shared/utils/discord_auth_errors.dart';
import 'package:bot_creator_shared/utils/intent_resolver.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const _membersLimited = 1 << 14;
const _presenceLimited = 1 << 12;
const _messageContentLimited = 1 << 18;
const _verifiedBot = 1 << 16;

void main() {
  group('portalEnabledPrivilegedIntentsFromFlags', () {
    test('returns empty set when no privileged flags are set', () {
      expect(portalEnabledPrivilegedIntentsFromFlags(0), isEmpty);
    });

    test('detects limited and full privileged flags', () {
      final enabled = portalEnabledPrivilegedIntentsFromFlags(
        _membersLimited | (1 << 13) | (1 << 19),
      );

      expect(enabled, {
        'Guild Members',
        'Guild Presence',
        'Message Content',
      });
    });
  });

  group('buildPortalIntentsMapFromPrivileged', () {
    test('enables only privileged keys present in the portal set', () {
      final map = buildPortalIntentsMapFromPrivileged({'Message Content'});

      expect(map['Message Content'], isTrue);
      expect(map['Guild Members'], isFalse);
      expect(map['Guild Messages'], isTrue);
    });
  });

  group('fetchPortalEnabledPrivilegedIntents', () {
    test('does not PATCH when all privileged intents are already enabled', () async {
      var patchCalled = false;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/applications/@me')) {
          return http.Response(
            jsonEncode({'flags': _membersLimited | _presenceLimited | _messageContentLimited}),
            200,
          );
        }
        if (request.method == 'PATCH') {
          patchCalled = true;
        }
        return http.Response('not found', 404);
      });

      final result = await fetchPortalEnabledPrivilegedIntents(
        'token',
        client: client,
      );

      expect(patchCalled, isFalse);
      expect(result.enabled, privilegedIntentKeys);
      expect(result.didAutoEnable, isFalse);
    });

    test('PATCHes only missing limited flags for unverified bots', () async {
      int? patchedFlags;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/applications/@me')) {
          return http.Response(jsonEncode({'flags': _membersLimited}), 200);
        }
        if (request.method == 'GET' && request.url.path.endsWith('/users/@me')) {
          return http.Response(jsonEncode({'flags': 0}), 200);
        }
        if (request.method == 'PATCH' &&
            request.url.path.endsWith('/applications/@me')) {
          patchedFlags = jsonDecode(request.body)['flags'] as int;
          return http.Response(jsonEncode({'flags': patchedFlags}), 200);
        }
        return http.Response('not found', 404);
      });

      final result = await fetchPortalEnabledPrivilegedIntents(
        'token',
        client: client,
      );

      expect(
        patchedFlags,
        _membersLimited | _presenceLimited | _messageContentLimited,
      );
      expect(result.enabled, privilegedIntentKeys);
      expect(result.didAutoEnable, isTrue);
    });

    test('throws PortalIntentAutoEnableError for verified bots', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/applications/@me')) {
          return http.Response(jsonEncode({'flags': 0}), 200);
        }
        if (request.method == 'GET' && request.url.path.endsWith('/users/@me')) {
          return http.Response(jsonEncode({'flags': _verifiedBot}), 200);
        }
        if (request.method == 'PATCH') {
          fail('PATCH should not be attempted for verified bots');
        }
        return http.Response('not found', 404);
      });

      expect(
        () => fetchPortalEnabledPrivilegedIntents('token', client: client),
        throwsA(isA<PortalIntentAutoEnableError>()),
      );
    });

    test('throws PortalIntentPatchFailedException when PATCH fails', () async {
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/applications/@me')) {
          return http.Response(jsonEncode({'flags': 0}), 200);
        }
        if (request.method == 'GET' && request.url.path.endsWith('/users/@me')) {
          return http.Response(jsonEncode({'flags': 0}), 200);
        }
        if (request.method == 'PATCH') {
          return http.Response('forbidden', 403);
        }
        return http.Response('not found', 404);
      });

      expect(
        () => fetchPortalEnabledPrivilegedIntents('token', client: client),
        throwsA(isA<PortalIntentPatchFailedException>()),
      );
    });

    test('throws DiscordTokenUnauthorizedException on unauthorized application fetch',
        () async {
      final client = MockClient((request) async {
        return http.Response('unauthorized', 401);
      });

      expect(
        () => fetchPortalEnabledPrivilegedIntents('token', client: client),
        throwsA(isA<DiscordTokenUnauthorizedException>()),
      );
    });
  });
}
