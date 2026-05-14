import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Creates a thread in a channel.
///
/// Payload fields:
/// - `channelId` — parent channel (required if no fallback)
/// - `name` — thread name (required)
/// - `autoArchiveDuration` — in minutes: 60, 1440, 4320 or 10080 (default 1440)
/// - `type` — 'public' or 'private' (default 'public', ignored when messageId is set)
/// - `messageId` — if provided, creates a thread on that existing message
/// - `slowmode` — slowmode delay in seconds (0 = off)
/// - `reason` — audit log reason
///
/// Returns `{'threadId', 'name', 'parentId'}` or `{'error': '...'}`.
Future<Map<String, String>> createThreadAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  Snowflake? fallbackChannelId,
  required String Function(String) resolve,
}) async {
  try {
    final channelId =
        _toSnowflake(resolve((payload['channelId'] ?? '').toString())) ??
        fallbackChannelId;
    if (channelId == null) {
      return {'error': 'channelId is required for createThread'};
    }

    final name = resolve((payload['name'] ?? '').toString()).trim();
    if (name.isEmpty) {
      return {'error': 'name is required for createThread'};
    }

    final rawDuration =
        int.tryParse(
          resolve((payload['autoArchiveDuration'] ?? '1440').toString()),
        ) ??
        1440;
    // Clamp to valid Discord values
    final archiveMinutes = [60, 1440, 4320, 10080].reduce(
      (prev, curr) =>
          (curr - rawDuration).abs() < (prev - rawDuration).abs() ? curr : prev,
    );
    final archiveDuration = Duration(minutes: archiveMinutes);

    final slowmode =
        int.tryParse(resolve((payload['slowmode'] ?? '0').toString())) ?? 0;
    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final messageId = _toSnowflake(
      resolve((payload['messageId'] ?? '').toString()),
    );

    final channel = await fetchChannelCached(client, channelId);

    Thread thread;
    if (messageId != null && channel is GuildTextChannel) {
      // Thread on an existing message
      thread = await channel.createThreadFromMessage(
        messageId,
        ThreadFromMessageBuilder(
          name: name,
          autoArchiveDuration: archiveDuration,
          rateLimitPerUser: slowmode > 0 ? Duration(seconds: slowmode) : null,
        ),
        auditLogReason: reason.isNotEmpty ? reason : null,
      );
    } else if (channel is GuildTextChannel) {
      final typeRaw =
          resolve((payload['type'] ?? 'public').toString()).toLowerCase();
      final isPrivate = typeRaw == 'private';
      thread = await channel.createThread(
        isPrivate
            ? ThreadBuilder.privateThread(
              name: name,
              autoArchiveDuration: archiveDuration,
              rateLimitPerUser:
                  slowmode > 0 ? Duration(seconds: slowmode) : null,
            )
            : ThreadBuilder.publicThread(
              name: name,
              autoArchiveDuration: archiveDuration,
              rateLimitPerUser:
                  slowmode > 0 ? Duration(seconds: slowmode) : null,
            ),
        auditLogReason: reason.isNotEmpty ? reason : null,
      );
    } else {
      return {'error': 'Channel does not support threads'};
    }

    return {
      'threadId': thread.id.toString(),
      'name': thread.name,
      'parentId': channelId.toString(),
    };
  } catch (e) {
    return {'error': 'Failed to create thread: $e'};
  }
}

bool? _toBool(dynamic value) {
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text.isEmpty || text == '!unchanged') {
    return null;
  }
  if (text == 'true' || text == 'yes' || text == '1' || text == 'on') {
    return true;
  }
  if (text == 'false' || text == 'no' || text == '0' || text == 'off') {
    return false;
  }
  return null;
}

int? _toArchiveMinutes(dynamic value) {
  final parsed = int.tryParse(value?.toString().trim() ?? '');
  if (parsed == null) {
    return null;
  }
  const allowed = <int>[60, 1440, 4320, 10080];
  return allowed.reduce(
    (prev, curr) => (curr - parsed).abs() < (prev - parsed).abs() ? curr : prev,
  );
}

int? _toInt(dynamic value) {
  return int.tryParse(value?.toString().trim() ?? '');
}

Future<Map<String, String>> editThreadAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    final threadId = _toSnowflake(
      resolve((payload['threadId'] ?? '').toString()),
    );
    if (threadId == null) {
      return {'error': 'threadId is required for editThread'};
    }

    final channel = await fetchChannelCached(client, threadId);
    if (channel is! Thread) {
      return {'error': 'Provided channel is not a thread'};
    }

    final name = resolve((payload['name'] ?? '').toString()).trim();
    final archived = _toBool(resolve((payload['archived'] ?? '').toString()));
    final locked = _toBool(resolve((payload['locked'] ?? '').toString()));
    final archiveMinutes = _toArchiveMinutes(
      resolve((payload['autoArchiveDuration'] ?? '').toString()),
    );
    final slowmode = _toInt(resolve((payload['slowmode'] ?? '').toString()));
    final builder = ThreadUpdateBuilder(
      name: name.isEmpty || name == '!unchanged' ? null : name,
      isArchived: archived,
      autoArchiveDuration:
          archiveMinutes == null ? null : Duration(minutes: archiveMinutes),
      isLocked: locked,
    );
    if (slowmode != null && slowmode >= 0) {
      builder.rateLimitPerUser = Duration(seconds: slowmode);
    }

    await channel.update(builder);

    return {'threadId': threadId.toString(), 'status': 'updated'};
  } catch (e) {
    return {'error': 'Failed to edit thread: $e'};
  }
}

Future<Map<String, String>> addThreadMemberAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    final threadId = _toSnowflake(
      resolve((payload['threadId'] ?? '').toString()),
    );
    final userId = _toSnowflake(resolve((payload['userId'] ?? '').toString()));
    if (threadId == null || userId == null) {
      return {'error': 'threadId and userId are required for threadAddMember'};
    }

    final channel = await fetchChannelCached(client, threadId);
    if (channel is! Thread) {
      return {'error': 'Provided channel is not a thread'};
    }

    await channel.addThreadMember(userId);
    return {'threadId': threadId.toString(), 'userId': userId.toString()};
  } catch (e) {
    return {'error': 'Failed to add thread member: $e'};
  }
}

Future<Map<String, String>> removeThreadMemberAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    final threadId = _toSnowflake(
      resolve((payload['threadId'] ?? '').toString()),
    );
    final userId = _toSnowflake(resolve((payload['userId'] ?? '').toString()));
    if (threadId == null || userId == null) {
      return {
        'error': 'threadId and userId are required for threadRemoveMember',
      };
    }

    final channel = await fetchChannelCached(client, threadId);
    if (channel is! Thread) {
      return {'error': 'Provided channel is not a thread'};
    }

    await channel.removeThreadMember(userId);
    return {'threadId': threadId.toString(), 'userId': userId.toString()};
  } catch (e) {
    return {'error': 'Failed to remove thread member: $e'};
  }
}
