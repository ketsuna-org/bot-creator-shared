import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'permission_checks.dart';

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
  if (text == 'true' || text == '1' || text == 'yes' || text == 'y') {
    return true;
  }
  if (text == 'false' || text == '0' || text == 'no' || text == 'n') {
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

ChannelType _channelTypeFromRaw(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'voice':
      return ChannelType.guildVoice;
    case 'announcement':
      return ChannelType.guildAnnouncement;
    case 'stage':
      return ChannelType.guildStageVoice;
    case 'forum':
      return ChannelType.guildForum;
    case 'category':
      return ChannelType.guildCategory;
    case 'text':
    default:
      return ChannelType.guildText;
  }
}

Future<Map<String, String>> createChannel(
  NyxxGateway client,
  String name, {
  required Snowflake guildId,
  ChannelType type = ChannelType.guildText,
}) async {
  try {
    if (name.trim().isEmpty) {
      return {'error': 'Channel name is required', 'channelId': ''};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageChannels],
      actionLabel: 'create channels',
    );
    if (permError != null) {
      return {'error': permError, 'channelId': ''};
    }

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found', 'channelId': ''};

    GuildChannelBuilder channelBuilder = GuildChannelBuilder(
      name: name,
      type: type,
    );
    final channel = await guild.createChannel(channelBuilder);

    return {"channelId": channel.id.toString()};
  } catch (e) {
    return {"error": "Failed to create channel: $e", "channelId": ""};
  }
}

Future<Map<String, String>> createChannelAction(
  NyxxGateway client, {
  required Snowflake guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  final resolvedName = resolve((payload['name'] ?? '').toString()).trim();
  final resolvedType = resolve((payload['type'] ?? 'text').toString());
  final resolvedCategory = resolve((payload['categoryId'] ?? '').toString());
  final resolvedTopic = resolve((payload['topic'] ?? '').toString()).trim();
  final resolvedSlowmode = resolve((payload['slowmode'] ?? '').toString());
  final resolvedNsfw = resolve((payload['nsfw'] ?? '').toString());

  final categoryId = _toSnowflake(resolvedCategory);
  final topic = resolvedTopic.isEmpty ? null : resolvedTopic;
  final isNsfw = _toBool(resolvedNsfw);
  final slowmode = _parseDuration(resolvedSlowmode);

  final created = await createChannel(
    client,
    resolvedName,
    guildId: guildId,
    type: _channelTypeFromRaw(resolvedType),
  );
  if (created['error'] != null) {
    return created;
  }

  final channelId = _toSnowflake(created['channelId']);
  if (channelId == null) {
    return {'error': 'Failed to resolve created channel ID', 'channelId': ''};
  }

  if (categoryId == null &&
      topic == null &&
      isNsfw == null &&
      slowmode == null) {
    return created;
  }

  try {
    final channel = await fetchChannelCached(client, channelId);
    if (channel is GuildTextChannel) {
      await channel.update(
        GuildTextChannelUpdateBuilder(
          topic: topic,
          isNsfw: isNsfw,
          rateLimitPerUser: slowmode,
          parentId: categoryId,
        ),
      );
    } else if (channel is GuildAnnouncementChannel) {
      await channel.update(
        GuildAnnouncementChannelUpdateBuilder(
          topic: topic,
          isNsfw: isNsfw,
          parentId: categoryId,
        ),
      );
    } else if (channel is ForumChannel) {
      await channel.update(
        ForumChannelUpdateBuilder(
          topic: topic,
          isNsfw: isNsfw,
          rateLimitPerUser: slowmode,
          parentId: categoryId,
        ),
      );
    } else if (channel is GuildVoiceChannel) {
      await channel.update(
        GuildVoiceChannelUpdateBuilder(isNsfw: isNsfw, parentId: categoryId),
      );
    } else if (channel is GuildStageChannel) {
      await channel.update(
        GuildStageChannelUpdateBuilder(isNsfw: isNsfw, parentId: categoryId),
      );
    } else if (channel is GuildCategory) {
      // No extra fields supported for category after creation.
    }
  } catch (e) {
    return {
      'error': 'Channel created but failed to apply options: $e',
      'channelId': created['channelId'] ?? '',
    };
  }

  return created;
}
