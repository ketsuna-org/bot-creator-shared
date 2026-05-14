import 'package:nyxx/nyxx.dart';
import 'permission_checks.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> updateGuildAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  String Function(String)? resolve,
}) async {
  resolve ??= (s) => s;
  try {
    if (guildId == null) {
      return {'error': 'Missing guildId', 'guildId': ''};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuild],
      actionLabel: 'update server settings',
    );
    if (permError != null) {
      return {'error': permError, 'guildId': ''};
    }

    final builder = GuildUpdateBuilder();

    if (payload.containsKey('name')) {
      final name = resolve((payload['name'] ?? '').toString()).trim();
      builder.name = name.isNotEmpty ? name : null;
    }

    if (payload.containsKey('description')) {
      final description = resolve((payload['description'] ?? '').toString());
      builder.description = description.isNotEmpty ? description : null;
    }

    if (payload.containsKey('preferredLocale')) {
      final localeRaw =
          resolve((payload['preferredLocale'] ?? '').toString()).trim();
      if (localeRaw.isNotEmpty) {
        builder.preferredLocale = Locale.parse(localeRaw);
      }
    }

    if (payload.containsKey('premiumProgressBarEnabled')) {
      final raw =
          resolve(
            (payload['premiumProgressBarEnabled'] ?? '').toString(),
          ).toLowerCase();
      builder.premiumProgressBarEnabled = raw == 'true';
    }

    if (payload.containsKey('afkTimeoutSeconds')) {
      final seconds = int.tryParse(
        resolve((payload['afkTimeoutSeconds'] ?? '').toString()),
      );
      if (seconds != null && seconds >= 0) {
        builder.afkTimeout = Duration(seconds: seconds);
      }
    }

    if (payload.containsKey('afkChannelId')) {
      builder.afkChannelId = _toSnowflake(
        resolve((payload['afkChannelId'] ?? '').toString()),
      );
    }
    if (payload.containsKey('systemChannelId')) {
      builder.systemChannelId = _toSnowflake(
        resolve((payload['systemChannelId'] ?? '').toString()),
      );
    }
    if (payload.containsKey('rulesChannelId')) {
      builder.rulesChannelId = _toSnowflake(
        resolve((payload['rulesChannelId'] ?? '').toString()),
      );
    }
    if (payload.containsKey('publicUpdatesChannelId')) {
      builder.publicUpdatesChannelId = _toSnowflake(
        resolve((payload['publicUpdatesChannelId'] ?? '').toString()),
      );
    }
    if (payload.containsKey('safetyAlertsChannelId')) {
      builder.safetyAlertsChannelId = _toSnowflake(
        resolve((payload['safetyAlertsChannelId'] ?? '').toString()),
      );
    }

    if (payload.containsKey('verificationLevel')) {
      final raw = int.tryParse(
        resolve((payload['verificationLevel'] ?? '').toString()),
      );
      if (raw != null) {
        builder.verificationLevel = VerificationLevel(raw);
      }
    }
    if (payload.containsKey('defaultMessageNotificationLevel')) {
      final raw = int.tryParse(
        resolve((payload['defaultMessageNotificationLevel'] ?? '').toString()),
      );
      if (raw != null) {
        builder.defaultMessageNotificationLevel = MessageNotificationLevel(raw);
      }
    }
    if (payload.containsKey('explicitContentFilterLevel')) {
      final raw = int.tryParse(
        resolve((payload['explicitContentFilterLevel'] ?? '').toString()),
      );
      if (raw != null) {
        builder.explicitContentFilterLevel = ExplicitContentFilterLevel(raw);
      }
    }

    final reason = resolve((payload['reason'] ?? '').toString()).trim();
    final updated = await client.guilds.update(
      guildId,
      builder,
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {
      'guildId': updated.id.toString(),
      'name': updated.name,
      'description': updated.description ?? '',
    };
  } catch (error) {
    return {'error': 'Failed to update guild: $error', 'guildId': ''};
  }
}
