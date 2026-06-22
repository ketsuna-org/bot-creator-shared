/// Service that manages a Lavalink audio connection for a bot.
///
/// Wraps [LavalinkPlugin] from nyxx_lavalink and provides
/// queue management and track info used by actions and BDFD functions.
library;

import 'dart:async';

import 'package:bot_creator_shared/bot/bot_config.dart';
import 'package:http/http.dart' as http;
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_lavalink/nyxx_lavalink.dart';

/// Holds runtime state for a single guild's Lavalink player.
class LavalinkSession {
  final LavalinkPlayer player;
  final List<Track> queue = [];
  int _queueIndex = -1;
  bool loop = false;
  int volume = 100;
  bool isPaused = false;

  LavalinkSession({required this.player});

  Track? get currentTrack {
    if (player.currentTrack != null) return player.currentTrack;
    if (_queueIndex >= 0 && _queueIndex < queue.length) {
      return queue[_queueIndex];
    }
    return null;
  }

  bool get isPlaying => player.currentTrack != null;
  bool get isConnected => player.state.isConnected;
  Duration get position => player.state.position;

  int get queueSize => queue.length;

  /// Advance to the next track in queue (or loop).
  /// Returns the next track, or null if queue is empty.
  Track? nextTrack() {
    if (queue.isEmpty) return null;
    _queueIndex++;
    if (_queueIndex >= queue.length) {
      if (loop) {
        _queueIndex = 0;
      } else {
        _queueIndex = -1;
        return null;
      }
    }
    return queue[_queueIndex];
  }

  void addToQueue(Track track) {
    queue.add(track);
  }

  void clearQueue() {
    queue.clear();
    _queueIndex = -1;
  }
}

/// Manages the Lavalink connection lifecycle and exposes player controls.
///
/// The [plugin] must be created from [BotConfig.lavalinkConfig] and passed to
/// the gateway via `GatewayClientOptions(plugins: [plugin])` before using this service.
class LavalinkService {
  final LavalinkPlugin _plugin;
  final Map<Snowflake, LavalinkSession> _sessions = {};
  final void Function(String message)? onLog;

  LavalinkService({
    required LavalinkPlugin plugin,
    required LavalinkConfig config,
    this.onLog,
  }) : _plugin = plugin; // ignore: prefer_initializing_formals

  /// Create a [LavalinkPlugin] from a config, or return null if no config is set.
  static LavalinkPlugin? createPlugin(LavalinkConfig? config) {
    if (config == null) return null;
    return LavalinkPlugin(
      base: Uri(
        scheme: config.useSsl ? 'https' : 'http',
        host: config.host,
        port: config.port,
      ),
      password: config.password,
    );
  }

  /// Wait for the Lavalink connection to be established, with a timeout.
  /// Throws [TimeoutException] if the server doesn't respond within 30 seconds.
  Future<void> waitForReady() async {
    await _plugin.onReady.first.timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw TimeoutException(
        'Lavalink server did not respond within 30s',
      ),
    );
  }

  /// Monitor Lavalink connection health — logs WS closures.
  void monitorHealth() {
    _plugin.onWebsocketClosed.listen((event) {
      onLog?.call(
        'Lavalink WebSocket closed: code=${event.code} reason=${event.reason}',
      );
    });
    _plugin.onTrackStuck.listen((event) {
      onLog?.call('Lavalink: track stuck — ${event.track.info.title}');
    });
    _plugin.onTrackException.listen((event) {
      onLog?.call('Lavalink: track exception — ${event.exception.message ?? event.exception.cause}');
    });
  }

  /// Connect to a voice channel and return the session.
  Future<LavalinkSession> connect(
    NyxxGateway client,
    Snowflake guildId,
    Snowflake channelId,
  ) async {
    final botVoiceState = client.guilds.cache[guildId]?.voiceStates[client.user.id];
    final botChannelId = botVoiceState?.channelId;

    // Reuse existing session if already connected to the same channel
    if (_sessions.containsKey(guildId) && botChannelId == channelId) {
      return _sessions[guildId]!;
    }

    onLog?.call('Lavalink: connecting to voice channel $channelId in guild $guildId...');
    final LavalinkPlayer player;
    try {
      player = await _plugin.connect(client, channelId, guildId).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Lavalink voice connection timed out'),
      );
    } catch (e) {
      onLog?.call('Lavalink: connect failed — $e');
      throw Exception(
        'Failed to connect to voice channel via Lavalink. '
        'Make sure the Lavalink server is running and accessible.',
      );
    }
    final session = LavalinkSession(player: player);

    // Auto-advance queue on track end
    player.onTrackEnd.listen((event) async {
      if (event.reason == 'finished' || event.reason == 'stopped') {
        final next = session.nextTrack();
        if (next != null) {
          await player.play(next);
        }
      }
    });

    final oldSession = _sessions[guildId];
    if (oldSession != null) {
      // Transfer queue and settings to the new session
      session.queue.addAll(oldSession.queue);
      session._queueIndex = oldSession._queueIndex;
      session.loop = oldSession.loop;
    }

    _sessions[guildId] = session;
    return session;
  }

  /// Disconnect from a guild's voice channel.
  Future<void> disconnect(Snowflake guildId) async {
    final session = _sessions.remove(guildId);
    if (session != null) {
      session.clearQueue();
      await session.player.disconnect();
    }
  }

  /// Get or create a session for a guild. Returns null if not connected.
  LavalinkSession? session(Snowflake guildId) => _sessions[guildId];

  // ─── Player controls ────────────────────────────────────────────────────

  /// Play a track by search query. Loads via Lavalink REST API.
  Future<Track?> play(
    NyxxGateway client,
    Snowflake guildId,
    Snowflake channelId,
    String query,
  ) async {
    final s = await _ensureSession(client, guildId, channelId);
    if (s == null) return null;

    final trimmedQuery = query.trim();
    final String identifier;
    if (trimmedQuery.startsWith('http://') || trimmedQuery.startsWith('https://')) {
      identifier = trimmedQuery;
    } else {
      identifier = 'ytsearch:$trimmedQuery';
    }

    onLog?.call('Lavalink: searching/loading "$identifier"...');
    final result;
    try {
      result = await _plugin.loadTrack(identifier).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Lavalink search timed out'),
      );
    } catch (e) {
      onLog?.call('Lavalink: loadTrack failed — $e');
      throw Exception(
        'The Lavalink server did not respond correctly. '
        'Make sure it is running and accessible.',
      );
    }

    if (result is TrackLoadResult) {
      onLog?.call('Lavalink: found single track: ${result.data.info.title}');
      final track = result.data;
      s.addToQueue(track);
      if (!s.isPlaying) {
        s._queueIndex = s.queue.length - 1;
        await s.player.play(track);
      }
      return track;
    } else if (result is PlaylistLoadResult) {
      for (final track in result.data.tracks) {
        s.addToQueue(track);
      }
      if (!s.isPlaying && s.queue.isNotEmpty) {
        s._queueIndex = s.queue.length - result.data.tracks.length;
        await s.player.play(s.queue[s._queueIndex]);
      }
      return s.currentTrack;
    } else if (result is SearchLoadResult) {
      onLog?.call('Lavalink: search results: ${result.data.length} tracks');
      final track = result.data.firstOrNull;
      if (track != null) {
        s.addToQueue(track);
        if (!s.isPlaying) {
          s._queueIndex = s.queue.length - 1;
          await s.player.play(track);
        }
        return track;
      }
    } else if (result is ErrorLoadResult) {
      onLog?.call('Lavalink: load failed — ${result.data.message ?? result.data.cause}');
      return null;
    } else if (result is EmptyLoadResult) {
      onLog?.call('Lavalink: no matches found for "$trimmedQuery"');
      return null;
    }

    onLog?.call('Lavalink: no tracks found for "$trimmedQuery" (loadType: ${result.loadType})');
    return null;
  }

  Future<void> pause(Snowflake guildId) async {
    final s = _sessions[guildId];
    if (s != null) {
      await s.player.pause();
      s.isPaused = true;
    }
  }

  Future<void> resume(Snowflake guildId) async {
    final s = _sessions[guildId];
    if (s != null) {
      await s.player.resume();
      s.isPaused = false;
    }
  }

  Future<void> skip(Snowflake guildId) async {
    final s = _sessions[guildId];
    if (s == null) return;
    final next = s.nextTrack();
    if (next != null) {
      await s.player.play(next);
    } else {
      await s.player.stopPlaying();
    }
  }

  Future<void> stop(Snowflake guildId) async {
    final s = _sessions[guildId];
    if (s != null) {
      s.clearQueue();
      await s.player.stopPlaying();
    }
  }

  Future<void> setVolume(Snowflake guildId, int volume) async {
    final s = _sessions[guildId];
    if (s != null) {
      final clamped = volume.clamp(0, 200);
      await s.player.setVolume(clamped);
      s.volume = clamped;
    }
  }

  Future<void> setLoop(Snowflake guildId, bool loop) async {
    final s = _sessions[guildId];
    if (s != null) s.loop = loop;
  }

  Future<void> seekTo(Snowflake guildId, Duration position) async {
    final s = _sessions[guildId];
    if (s != null) await s.player.seekTo(position);
  }

  /// Dispose all sessions. The plugin lifecycle is managed by the nyxx client.
  Future<void> dispose() async {
    for (final entry in _sessions.entries) {
      entry.value.clearQueue();
      try {
        await entry.value.player.disconnect();
      } catch (_) {}
    }
    _sessions.clear();
  }

  /// Test connectivity to the configured Lavalink server.
  /// Returns null on success, or an error message string on failure.
  static Future<String?> testConnection({
    required String host,
    required int port,
    required String password,
    required bool useSsl,
  }) async {
    final uri = Uri(
      scheme: useSsl ? 'https' : 'http',
      host: host,
      port: port,
      path: '/v4/info',
    );

    final maskedPassword = password.isEmpty 
        ? '[VIDE]' 
        : (password.length > 4 ? '${password.substring(0, 2)}***${password.substring(password.length - 2)}' : '***');

    print('Lavalink Connection Test: Starting...');
    print('Lavalink Connection Test: URL = $uri');
    print('Lavalink Connection Test: Password = $maskedPassword (length: ${password.length})');

    try {
      final response = await http
          .get(uri, headers: {'Authorization': password})
          .timeout(const Duration(seconds: 5));

      print('Lavalink Connection Test: Response received. Status Code = ${response.statusCode}');
      print('Lavalink Connection Test: Response Headers = ${response.headers}');
      print('Lavalink Connection Test: Response Body = ${response.body.length > 200 ? "${response.body.substring(0, 200)}..." : response.body}');

      if (response.statusCode == 200) {
        print('Lavalink Connection Test: SUCCESS');
        return null; // Success
      }
      print('Lavalink Connection Test: FAILED with status code ${response.statusCode}');
      return 'Erreur ${response.statusCode}';
    } on http.ClientException catch (e) {
      print('Lavalink Connection Test: ClientException (Connection Refused): ${e.message}');
      return 'Connexion refusée : ${e.message}';
    } on TimeoutException {
      print('Lavalink Connection Test: TimeoutException (5s exceeded)');
      return 'Délai dépassé (5s)';
    } catch (e) {
      print('Lavalink Connection Test: Unknown Error: $e');
      return e.toString();
    }
  }

  Future<LavalinkSession?> _ensureSession(
    NyxxGateway client,
    Snowflake guildId,
    Snowflake channelId,
  ) async {
    final botVoiceState = client.guilds.cache[guildId]?.voiceStates[client.user.id];
    final botChannelId = botVoiceState?.channelId;

    if (_sessions.containsKey(guildId) && botChannelId == channelId) {
      return _sessions[guildId]!;
    }
    return await connect(client, guildId, channelId);
  }
}
