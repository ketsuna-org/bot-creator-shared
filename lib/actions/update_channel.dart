import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

bool? _toBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true') {
    return true;
  }
  if (text == 'false') {
    return false;
  }
  return null;
}

Duration? _parseDuration(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return Duration(seconds: value.toInt());
  }

  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  final asInt = int.tryParse(text);
  if (asInt != null) {
    return Duration(seconds: asInt);
  }

  final match = RegExp(r'^(\d+)\s*([smhd])$').firstMatch(text.toLowerCase());
  if (match == null) {
    return null;
  }

  final amount = int.parse(match.group(1)!);
  final unit = match.group(2)!;
  switch (unit) {
    case 's':
      return Duration(seconds: amount);
    case 'm':
      return Duration(minutes: amount);
    case 'h':
      return Duration(hours: amount);
    case 'd':
      return Duration(days: amount);
    default:
      return null;
  }
}

int? _parseArchiveMinutes(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == '!unchanged') {
    return null;
  }
  final parsed = int.tryParse(text);
  if (parsed == null) {
    return null;
  }
  const allowed = <int>[60, 1440, 4320, 10080];
  return allowed.reduce(
    (prev, curr) => (curr - parsed).abs() < (prev - parsed).abs() ? curr : prev,
  );
}

Future<Map<String, String>> updateChannelAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  String Function(String)? resolve,
}) async {
  resolve ??= (s) => s;
  try {
    final channelId = _toSnowflake(
      resolve((payload['channelId'] ?? '').toString()),
    );
    if (channelId == null) {
      return {'error': 'Missing or invalid channelId', 'channelId': ''};
    }

    final channel = await fetchChannelCached(client, channelId);

    final name = resolve((payload['name'] ?? '').toString()).trim();
    final topic = resolve((payload['topic'] ?? '').toString());
    final nsfw = _toBool(resolve((payload['nsfw'] ?? '').toString()));
    final slowmode = _parseDuration(
      resolve((payload['slowmode'] ?? '').toString()),
    );
    final archived = _toBool(resolve((payload['archived'] ?? '').toString()));
    final locked = _toBool(resolve((payload['locked'] ?? '').toString()));
    final archiveMinutes = _parseArchiveMinutes(
      resolve((payload['autoArchiveDuration'] ?? '').toString()),
    );

    if (channel is Thread) {
      final builder = ThreadUpdateBuilder(
        name: name.isNotEmpty ? name : null,
        isArchived: archived,
        isLocked: locked,
        autoArchiveDuration:
            archiveMinutes == null ? null : Duration(minutes: archiveMinutes),
      );
      if (slowmode != null) {
        builder.rateLimitPerUser = slowmode;
      }
      await channel.update(builder);
    } else if (channel is GuildTextChannel) {
      await channel.update(
        GuildTextChannelUpdateBuilder(
          name: name.isNotEmpty ? name : null,
          topic: topic.isNotEmpty ? topic : null,
          isNsfw: nsfw,
          rateLimitPerUser: slowmode,
        ),
      );
    } else if (channel is GuildAnnouncementChannel) {
      await channel.update(
        GuildAnnouncementChannelUpdateBuilder(
          name: name.isNotEmpty ? name : null,
          topic: topic.isNotEmpty ? topic : null,
          isNsfw: nsfw,
        ),
      );
    } else if (channel is ForumChannel) {
      await channel.update(
        ForumChannelUpdateBuilder(
          name: name.isNotEmpty ? name : null,
          topic: topic.isNotEmpty ? topic : null,
          isNsfw: nsfw,
          rateLimitPerUser: slowmode,
        ),
      );
    } else if (channel is GuildVoiceChannel) {
      await channel.update(
        GuildVoiceChannelUpdateBuilder(
          name: name.isNotEmpty ? name : null,
          isNsfw: nsfw,
        ),
      );
    } else if (channel is GuildStageChannel) {
      await channel.update(
        GuildStageChannelUpdateBuilder(
          name: name.isNotEmpty ? name : null,
          isNsfw: nsfw,
        ),
      );
    } else if (channel is GuildCategory) {
      await channel.update(
        GuildCategoryUpdateBuilder(name: name.isNotEmpty ? name : null),
      );
    } else if (channel is GuildChannel) {
      await channel.update(
        GuildChannelUpdateBuilder<GuildChannel>(
          name: name.isNotEmpty ? name : null,
        ),
      );
    } else {
      return {
        'error': 'Unsupported channel type for update: ${channel.runtimeType}',
        'channelId': '',
      };
    }

    return {'channelId': channelId.toString(), 'status': 'updated'};
  } catch (error) {
    return {'error': 'Failed to update channel: $error', 'channelId': ''};
  }
}
