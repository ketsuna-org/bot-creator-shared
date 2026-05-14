import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'permission_checks.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

List<Snowflake> _toSnowflakeList(dynamic value) {
  if (value == null) return [];
  List<String> raw;
  if (value is List) {
    raw = value.map((e) => e.toString().trim()).toList();
  } else {
    final s = value.toString().trim();
    if (s.isEmpty) return [];
    try {
      final decoded = jsonDecode(s);
      if (decoded is List) {
        raw = decoded.map((e) => e.toString().trim()).toList();
      } else {
        raw = s.split(',').map((e) => e.trim()).toList();
      }
    } catch (_) {
      raw = s.split(',').map((e) => e.trim()).toList();
    }
  }
  return raw.map(_toSnowflake).whereType<Snowflake>().toList();
}

List<String> _toStringList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  final s = value.toString().trim();
  if (s.isEmpty) return [];
  try {
    final decoded = jsonDecode(s);
    if (decoded is List) {
      return decoded
          .map((e) => e.toString().trim())
          .where((v) => v.isNotEmpty)
          .toList();
    }
  } catch (_) {}
  return s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}

/// Creates a new AutoMod rule.
///
/// Payload fields:
/// - `name` — rule name (required)
/// - `triggerType` — one of: keyword, spam, keywordPreset, mentionSpam (required)
/// - `eventType` — message_send (default)
/// - `keywords` — list of keywords to filter (for keyword trigger)
/// - `keywordPresets` — list of presets: profanity, sexualContent, slurs
/// - `regexPatterns` — list of regex patterns
/// - `allowedWords` — words exempt from filtering
/// - `mentionTotalLimit` — max mentions for mentionSpam trigger
/// - `actionType` — block_message (default), send_alert_message, timeout
/// - `alertChannelId` — channel for alert messages
/// - `timeoutDuration` — timeout in seconds (for timeout action)
/// - `exemptRoles` — role IDs exempt from the rule
/// - `exemptChannels` — channel IDs exempt from the rule
/// - `enabled` — whether rule is enabled (default true)
/// - `reason` — audit log reason
///
/// Returns `{'ruleId', 'name', 'status': 'created'}` or `{'error': '...'}`.
Future<Map<String, String>> createAutoModRuleAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'createAutoModRule requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuild],
      actionLabel: 'manage automod rules',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final name = resolve((payload['name'] ?? '').toString()).trim();
    if (name.isEmpty) {
      return {'error': 'name is required for createAutoModRule'};
    }

    final triggerTypeRaw =
        resolve(
          (payload['triggerType'] ?? 'keyword').toString(),
        ).trim().toLowerCase();

    TriggerType triggerType;
    switch (triggerTypeRaw) {
      case 'spam':
        triggerType = TriggerType.spam;
      case 'keywordpreset':
      case 'keyword_preset':
        triggerType = TriggerType.keywordPreset;
      case 'mentionspam':
      case 'mention_spam':
        triggerType = TriggerType.mentionSpam;
      default:
        triggerType = TriggerType.keyword;
    }

    final keywords = _toStringList(payload['keywords']);
    final regexPatterns = _toStringList(payload['regexPatterns']);
    final allowedWords = _toStringList(payload['allowedWords']);
    final exemptRoles = _toSnowflakeList(payload['exemptRoles']);
    final exemptChannels = _toSnowflakeList(payload['exemptChannels']);

    final mentionTotalLimit =
        int.tryParse(
          resolve((payload['mentionTotalLimit'] ?? '5').toString()),
        ) ??
        5;

    final enabledRaw =
        resolve((payload['enabled'] ?? 'true').toString()).toLowerCase();
    final enabled = enabledRaw != 'false' && enabledRaw != '0';

    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    // Build action
    final actionTypeRaw =
        resolve(
          (payload['actionType'] ?? 'block_message').toString(),
        ).trim().toLowerCase();

    final List<AutoModerationActionBuilder> actions = [];
    switch (actionTypeRaw) {
      case 'send_alert_message':
      case 'sendalertmessage':
        final alertChannelId = _toSnowflake(
          resolve((payload['alertChannelId'] ?? '').toString()),
        );
        if (alertChannelId != null) {
          actions.add(
            AutoModerationActionBuilder.sendAlertMessage(
              channelId: alertChannelId,
            ),
          );
        }
      case 'timeout':
        final timeoutDuration =
            int.tryParse(
              resolve((payload['timeoutDuration'] ?? '60').toString()),
            ) ??
            60;
        actions.add(
          AutoModerationActionBuilder.timeout(
            duration: Duration(seconds: timeoutDuration),
          ),
        );
      default:
        actions.add(AutoModerationActionBuilder.blockMessage());
    }

    // Build trigger metadata
    TriggerMetadataBuilder? triggerMetadata;
    if (triggerType == TriggerType.keyword) {
      triggerMetadata = TriggerMetadataBuilder(
        keywordFilter: keywords,
        regexPatterns: regexPatterns,
        allowList: allowedWords,
      );
    } else if (triggerType == TriggerType.keywordPreset) {
      final presetRaw = _toStringList(payload['keywordPresets']);
      final presets = <KeywordPresetType>[];
      for (final p in presetRaw) {
        switch (p.toLowerCase()) {
          case 'profanity':
            presets.add(KeywordPresetType.profanity);
          case 'sexualcontent':
          case 'sexual_content':
            presets.add(KeywordPresetType.sexualContent);
          case 'slurs':
            presets.add(KeywordPresetType.slurs);
        }
      }
      triggerMetadata = TriggerMetadataBuilder(
        presets: presets,
        allowList: allowedWords,
      );
    } else if (triggerType == TriggerType.mentionSpam) {
      triggerMetadata = TriggerMetadataBuilder(
        mentionTotalLimit: mentionTotalLimit,
      );
    }

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    final rule = await guild.autoModerationRules.create(
      AutoModerationRuleBuilder(
        name: name,
        eventType: AutoModerationEventType.messageSend,
        triggerType: triggerType,
        metadata: triggerMetadata,
        actions: actions,
        isEnabled: enabled,
        exemptRoleIds: exemptRoles,
        exemptChannelIds: exemptChannels,
      ),
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {
      'ruleId': rule.id.toString(),
      'name': rule.name,
      'status': 'created',
    };
  } catch (e) {
    return {'error': 'Failed to create AutoMod rule: $e'};
  }
}

/// Deletes an AutoMod rule.
///
/// Payload fields:
/// - `ruleId` — rule ID to delete (required)
/// - `reason` — audit log reason
///
/// Returns `{'ruleId', 'status': 'deleted'}` or `{'error': '...'}`.
Future<Map<String, String>> deleteAutoModRuleAction(
  NyxxGateway client, {
  required Snowflake? guildId,
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'deleteAutoModRule requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuild],
      actionLabel: 'delete automod rules',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final ruleId = _toSnowflake(resolve((payload['ruleId'] ?? '').toString()));
    if (ruleId == null) {
      return {'error': 'ruleId is required for deleteAutoModRule'};
    }

    final reason = resolve((payload['reason'] ?? '').toString()).trim();

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    await guild.autoModerationRules.delete(
      ruleId,
      auditLogReason: reason.isNotEmpty ? reason : null,
    );

    return {'ruleId': ruleId.toString(), 'status': 'deleted'};
  } catch (e) {
    return {'error': 'Failed to delete AutoMod rule: $e'};
  }
}

/// Lists all AutoMod rules in a guild.
///
/// Returns `{'rulesJson': '[{...}]', 'count': 'N'}` or `{'error': '...'}`.
Future<Map<String, String>> listAutoModRulesAction(
  NyxxGateway client, {
  required Snowflake? guildId,
}) async {
  try {
    if (guildId == null) {
      return {'error': 'listAutoModRules requires a guild context'};
    }

    final permError = await checkBotGuildPermission(
      client,
      guildId: guildId,
      requiredPermissions: [Permissions.manageGuild],
      actionLabel: 'list automod rules',
    );
    if (permError != null) {
      return {'error': permError};
    }

    final guild = await fetchGuildCached(client, guildId);
    if (guild == null) return {'error': 'Guild not found'};
    final rules = await guild.autoModerationRules.list();

    final rulesJson = jsonEncode(
      rules
          .map(
            (r) => {
              'id': r.id.toString(),
              'name': r.name,
              'enabled': r.isEnabled,
              'triggerType': r.triggerType.value,
            },
          )
          .toList(),
    );

    return {'rulesJson': rulesJson, 'count': rules.length.toString()};
  } catch (e) {
    return {'error': 'Failed to list AutoMod rules: $e'};
  }
}
