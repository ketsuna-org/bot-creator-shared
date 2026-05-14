import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'permission_checks.dart';

/// Fetches current guild onboarding configuration.
///
/// Returns `{'onboardingJson': '{...}', 'enabled': 'true|false'}` or `{'error': '...'}`.
Future<Map<String, String>> getGuildOnboardingAction(
  NyxxGateway client, {
  required Snowflake? guildId,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'getGuildOnboarding requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuild],
      actionLabel: 'view guild onboarding',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    final onboarding = await guild.fetchOnboarding();

    final json = jsonEncode({
      'guildId': onboarding.guildId.toString(),
      'enabled': onboarding.isEnabled,
      'defaultChannelIds':
          onboarding.defaultChannelIds.map((id) => id.toString()).toList(),
      'mode': onboarding.mode.value,
      'prompts':
          onboarding.prompts
              .map(
                (p) => {
                  'id': p.id.toString(),
                  'title': p.title,
                  'type': p.type.value,
                  'required': p.isRequired,
                  'singleSelect': p.isSingleSelect,
                  'inOnboarding': p.isInOnboarding,
                  'options':
                      p.options
                          .map(
                            (o) => {
                              'id': o.id.toString(),
                              'title': o.title,
                              'description': o.description ?? '',
                              'channelIds':
                                  o.channelIds
                                      .map((id) => id.toString())
                                      .toList(),
                              'roleIds':
                                  o.roleIds.map((id) => id.toString()).toList(),
                            },
                          )
                          .toList(),
                },
              )
              .toList(),
    });

    return {'onboardingJson': json, 'enabled': onboarding.isEnabled.toString()};
  } catch (e) {
    return {'error': 'Failed to get guild onboarding: $e'};
  }
}

/// Updates guild onboarding configuration.
///
/// Currently limited by nyxx support in this runtime.
/// Returns `{'status': 'updated'}` on success or `{'error': '...'}`.
Future<Map<String, String>> updateGuildOnboardingAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  if (guildId == null) {
    return {'error': 'updateGuildOnboarding requires a guild context'};
  }

  final permError = await checkBotGuildPermission(
    client,
    guildId: guildId,
    requiredPermissions: [Permissions.manageGuild],
    actionLabel: 'update guild onboarding',
  );
  if (permError != null) {
    return {'error': permError};
  }

  final _ = resolve((payload['enabled'] ?? '').toString());

  return {
    'error':
        'updateGuildOnboarding is not supported by the current nyxx runtime yet',
  };
}
