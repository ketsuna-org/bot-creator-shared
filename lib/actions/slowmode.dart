import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/bdfd_duration_parser.dart';
import 'handler_utils.dart';
import 'permission_checks.dart';

Future<Map<String, String>> slowmodeAction(
  NyxxGateway client, {
  required Snowflake guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  final channelId = parseSnowflake(resolve(payload['channelId']?.toString() ?? ''));
  if (channelId == null) {
    return {'error': 'Invalid channelId'};
  }

  final permError = await checkBotGuildPermission(
    client,
    guildId: guildId,
    requiredPermissions: [Permissions.manageChannels],
    actionLabel: 'set slowmode',
  );
  if (permError != null) {
    return {'error': permError};
  }

  final durationStr = resolve(payload['duration']?.toString() ?? '0s');
  final duration = parseBdfdDuration(durationStr) ?? Duration.zero;
  resolve(payload['reason']?.toString() ?? '');

  try {
    final channel = await client.channels.fetch(channelId);
    if (channel is GuildTextChannel) {
      await channel.update(GuildTextChannelUpdateBuilder(rateLimitPerUser: duration));
    } else if (channel is ForumChannel) {
      await channel.update(ForumChannelUpdateBuilder(rateLimitPerUser: duration));
    } else if (channel is Thread) {
      await channel.update(ThreadUpdateBuilder(rateLimitPerUser: duration));
    } else {
      return {'error': 'Slowmode is not supported for this channel type'};
    }
    return {'channelId': channelId.toString(), 'duration': duration.inSeconds.toString()};
  } catch (e) {
    return {'error': 'Failed to set slowmode: $e'};
  }
}
