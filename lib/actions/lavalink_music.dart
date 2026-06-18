library;

import 'dart:async';

import 'package:bot_creator_shared/services/lavalink_service.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_lavalink/nyxx_lavalink.dart';

/// Resolves the voice channel the user is currently in.
/// Returns null if the user is not in a voice channel or not found.
Snowflake? _findUserVoiceChannel(NyxxGateway client, Snowflake guildId, Snowflake userId) {
  try {
    final guild = client.guilds.cache[guildId];
    if (guild == null) return null;
    final voiceState = guild.voiceStates[userId];
    // Debug: log cache state
    client.logger.fine(
      'Lavalink voice lookup: userId=$userId, guildFound=true, '
      'voiceStateFound=${voiceState != null}, '
      'totalVoiceStates=${guild.voiceStates.length}',
    );
    return voiceState?.channelId;
  } catch (e) {
    client.logger.warning('Lavalink voice lookup error: $e');
    return null;
  }
}

/// Play a track by search query or URL.
///
/// Automatically joins the voice channel of [userId] if [channelId] is not provided.
/// Payload: query (String), userId? (Snowflake), channelId? (Snowflake).
Future<Map<String, String>> playMusicAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    final query = (payload['query'] ?? '').toString().trim();
    if (query.isEmpty) {
      return {'error': 'Query cannot be empty'};
    }

    // Resolve voice channel: explicit > user's current channel
    Snowflake? voiceChannelId;
    if (channelId != null && channelId.value != 0) {
      voiceChannelId = channelId;
    } else if (payload['channelId'] != null && payload['channelId'].toString().isNotEmpty) {
      voiceChannelId = Snowflake.parse(payload['channelId'].toString());
    } else if (payload['userId'] != null && payload['userId'].toString().isNotEmpty) {
      final userId = Snowflake.parse(payload['userId'].toString());
      voiceChannelId = _findUserVoiceChannel(client, guildId, userId);
      if (voiceChannelId == null) {
        return {'error': "Vous devez etre dans un salon vocal"};
      }
    }

    if (voiceChannelId == null) {
      return {'error': 'No voice channel specified and user is not in a voice channel'};
    }

    final track = await lavalinkService.play(
      client,
      guildId,
      voiceChannelId,
      query,
    );

    if (track == null) {
      return {'error': 'No track found for query: $query'};
    }

    return {
      'title': track.info.title,
      'author': track.info.author,
      'duration': track.info.length.inMilliseconds.toString(),
      'uri': track.info.uri?.toString() ?? '',
      'thumbnail': _getTrackThumbnail(track),
    };
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Join a voice channel without playing anything.
/// Automatically resolves the user's voice channel if [userId] is in the payload.
Future<Map<String, String>> joinVoiceAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    Snowflake? voiceChannelId;
    if (channelId != null && channelId.value != 0) {
      voiceChannelId = channelId;
    } else if (payload['channelId'] != null && payload['channelId'].toString().isNotEmpty) {
      voiceChannelId = Snowflake.parse(payload['channelId'].toString());
    } else if (payload['userId'] != null && payload['userId'].toString().isNotEmpty) {
      final userId = Snowflake.parse(payload['userId'].toString());
      voiceChannelId = _findUserVoiceChannel(client, guildId, userId);
      if (voiceChannelId == null) {
        return {'error': 'Vous devez etre dans un salon vocal'};
      }
    }
    if (voiceChannelId == null) {
      return {'error': 'No voice channel specified'};
    }
    await lavalinkService.connect(client, guildId, voiceChannelId);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Leave the voice channel and destroy the player.
Future<Map<String, String>> leaveVoiceAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    await lavalinkService.disconnect(guildId);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Pause the current track.
/// Payload: none.
Future<Map<String, String>> pauseMusicAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    await lavalinkService.pause(guildId);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Resume a paused track.
/// Payload: none.
Future<Map<String, String>> resumeMusicAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    await lavalinkService.resume(guildId);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Skip to the next track in the queue.
/// Payload: none.
Future<Map<String, String>> skipMusicAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    await lavalinkService.skip(guildId);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Stop playback and clear the queue.
/// Payload: none.
Future<Map<String, String>> stopMusicAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    await lavalinkService.stop(guildId);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Set the player volume (0–200).
/// Payload: volume (int).
Future<Map<String, String>> setMusicVolumeAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    final rawVolume = payload['volume'];
    final int? volume;
    if (rawVolume is num) {
      volume = rawVolume.toInt();
    } else {
      volume = int.tryParse(rawVolume?.toString() ?? '');
    }
    if (volume == null) {
      return {'error': 'Missing volume parameter'};
    }
    await lavalinkService.setVolume(guildId, volume);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Enable or disable looping of the queue.
/// Payload: loop (bool).
Future<Map<String, String>> setMusicLoopAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    final loop = payload['loop'] == true || payload['loop']?.toString() == 'true';
    await lavalinkService.setLoop(guildId, loop);
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Seek to a position in the current track.
/// Payload: position (int) — milliseconds.
Future<Map<String, String>> seekMusicAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    final rawPosition = payload['position'];
    final int? positionMs;
    if (rawPosition is num) {
      positionMs = rawPosition.toInt();
    } else {
      positionMs = int.tryParse(rawPosition?.toString() ?? '');
    }
    if (positionMs == null) {
      return {'error': 'Missing position parameter'};
    }
    await lavalinkService.seekTo(guildId, Duration(milliseconds: positionMs));
    return {};
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Retrieve info about the currently playing track.
/// Payload: none.
Future<Map<String, String>> getMusicInfoAction({
  required NyxxGateway client,
  required Snowflake guildId,
  Snowflake? channelId,
  required Map<String, dynamic> payload,
  required LavalinkService lavalinkService,
}) async {
  try {
    final session = lavalinkService.session(guildId);
    if (session == null || !session.isPlaying) {
      return {'isPlaying': 'false'};
    }

    final track = session.currentTrack;
    final player = await session.player.fetchPlayer();
    return {
      'isPlaying': 'true',
      'title': track?.info.title ?? '',
      'author': track?.info.author ?? '',
      'duration': track?.info.length.inMilliseconds.toString() ?? '0',
      'position': session.position.inMilliseconds.toString(),
      'queueSize': session.queueSize.toString(),
      'volume': player.volume.toString(),
      'isPaused': player.isPaused.toString(),
      'isLooping': session.loop.toString(),
      'thumbnail': _getTrackThumbnail(track),
    };
  } catch (e) {
    return {'error': e.toString()};
  }
}

String _getTrackThumbnail(Track? track) {
  if (track == null) return '';
  final info = track.info;

  // 1. Try artworkUrl if populated by Lavalink
  final artwork = info.artworkUrl?.toString() ?? '';
  if (artwork.isNotEmpty) {
    return artwork;
  }

  // 2. YouTube fallback using video identifier
  final source = info.sourceName?.toLowerCase() ?? '';
  final uriStr = info.uri?.toString() ?? '';
  final isYoutube = source == 'youtube' ||
      uriStr.contains('youtube.com') ||
      uriStr.contains('youtu.be');

  if (isYoutube && info.identifier.isNotEmpty) {
    return 'https://img.youtube.com/vi/${info.identifier}/hqdefault.jpg';
  }

  return '';
}
