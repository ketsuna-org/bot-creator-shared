/// Thrown when a Discord bot token is rejected (401/403) or gateway auth fails.
class DiscordTokenUnauthorizedException implements Exception {
  DiscordTokenUnauthorizedException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

/// Returns whether [error] indicates an invalid or unauthorized Discord bot token.
bool isDiscordTokenUnauthorized(Object error) {
  if (error is DiscordTokenUnauthorizedException) {
    return true;
  }

  final message = error.toString().toLowerCase();

  if (_looksLikeDiscordRestUnauthorized(message)) {
    return true;
  }

  if (_looksLikeGatewayAuthFailure(message)) {
    return true;
  }

  return false;
}

/// Wraps [error] as [DiscordTokenUnauthorizedException] when applicable.
Never throwIfDiscordTokenUnauthorized(Object error, {String? context}) {
  if (!isDiscordTokenUnauthorized(error)) {
    throw error;
  }

  final prefix = context == null || context.isEmpty ? '' : '$context: ';
  throw DiscordTokenUnauthorizedException(
    '$prefix$error',
    cause: error,
  );
}

bool _looksLikeDiscordRestUnauthorized(String message) {
  final hasUnauthorized =
      message.contains('unauthorized') || message.contains('forbidden');
  final hasAuthStatus = message.contains('401') || message.contains('403');
  final mentionsDiscordApi =
      message.contains('discord.com/api') ||
      message.contains('applications/@me') ||
      message.contains('/applications/');

  if (hasAuthStatus && hasUnauthorized) {
    return true;
  }

  if (hasAuthStatus && mentionsDiscordApi) {
    return true;
  }

  if (message.contains('discord_token_invalid')) {
    return true;
  }

  return false;
}

bool _looksLikeGatewayAuthFailure(String message) {
  const fatalCodes = <String>[
    '4004', // authentication failed
    '4010', // invalid shard
    '4011', // sharding required
    '4012', // invalid api version
    '4013', // invalid intents
    '4014', // disallowed intents
  ];

  for (final code in fatalCodes) {
    if (message.contains(code) &&
        (message.contains('disconnect') ||
            message.contains('close') ||
            message.contains('gateway') ||
            message.contains('auth'))) {
      return true;
    }
  }

  return false;
}
