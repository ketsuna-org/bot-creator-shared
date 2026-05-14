import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/actions/permission_checks.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Duration _resolveMuteDuration(Map<String, dynamic> payload) {
  final seconds = int.tryParse((payload['durationSeconds'] ?? '').toString());
  if (seconds != null) {
    return Duration(seconds: seconds);
  }

  final minutes = int.tryParse((payload['durationMinutes'] ?? '').toString());
  if (minutes != null) {
    return Duration(minutes: minutes);
  }

  final hours = int.tryParse((payload['durationHours'] ?? '').toString());
  if (hours != null) {
    return Duration(hours: hours);
  }

  final generic = int.tryParse((payload['duration'] ?? '').toString());
  if (generic != null) {
    return Duration(seconds: generic);
  }

  final compact = RegExp(
    r'^(\d+)\s*([smhd])$',
    caseSensitive: false,
  ).firstMatch((payload['duration'] ?? '').toString().trim());
  if (compact != null) {
    final amount = int.tryParse(compact.group(1) ?? '');
    final unit = (compact.group(2) ?? '').toLowerCase();
    if (amount != null) {
      switch (unit) {
        case 's':
          return Duration(seconds: amount);
        case 'm':
          return Duration(minutes: amount);
        case 'h':
          return Duration(hours: amount);
        case 'd':
          return Duration(days: amount);
      }
    }
  }

  return const Duration(minutes: 10);
}

Future<Map<String, String>> muteUserAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'userId': ''};
    }

    final userId =
        _toSnowflake(payload['userId']) ?? _toSnowflake(payload['memberId']);
    if (userId == null) {
      return {'error': 'Missing or invalid userId/memberId', 'userId': ''};
    }

    final permError = await checkBotCanModerate(
      client,
      guildId: guildId,
      targetUserId: userId,
      requiredPermission: Permissions.moderateMembers,
      actionLabel: 'mute',
    );
    if (permError != null) {
      return {'error': permError, 'userId': ''};
    }

    final now = DateTime.now().toUtc();
    DateTime? until;

    final explicitUntilRaw = payload['until']?.toString().trim();
    if (explicitUntilRaw != null && explicitUntilRaw.isNotEmpty) {
      until = DateTime.tryParse(explicitUntilRaw)?.toUtc();
      if (until == null) {
        return {'error': 'Invalid until datetime format', 'userId': ''};
      }
    }

    until ??= now.add(_resolveMuteDuration(payload));

    final maxUntil = now.add(const Duration(days: 28));
    if (until.isAfter(maxUntil)) {
      until = maxUntil;
    }
    if (!until.isAfter(now)) {
      until = now.add(const Duration(seconds: 1));
    }

    final reason = payload['reason']?.toString().trim();
    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found', 'userId': ''};
    final member = await guild.members[userId].update(
      MemberUpdateBuilder(communicationDisabledUntil: until),
      auditLogReason:
          (reason != null && reason.isNotEmpty)
              ? reason
              : 'Timeout via BotCreator action',
    );

    return {
      'userId': member.id.toString(),
      'until': until.toIso8601String(),
      'status': 'muted',
    };
  } catch (error) {
    return {'error': 'Failed to mute user: $error', 'userId': ''};
  }
}
