import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import '../types/component.dart';
import '../utils/component_workflow_bindings.dart';
import '../utils/embed_fields.dart';
import 'send_component_v2.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return Snowflake(parsed);
}

/// Sends a message to a channel or directly to a user (DM).
///
/// Set `payload['targetType'] = 'user'` and provide `payload['userId']` to send
/// a DM rather than a channel message. In that case [channelId] is ignored.
Future<Map<String, String>> sendMessageToChannel(
  NyxxGateway client,
  Snowflake? channelId, {
  required String content,
  Map<String, dynamic>? payload,
  String Function(String)? resolve,
  String? botId,
  String? guildId,
}) async {
  try {
    // Determine actual channel to send to
    Snowflake? targetChannelId = channelId;

    final targetType =
        (payload?['targetType'] ?? 'channel').toString().trim().toLowerCase();
    if (targetType == 'user') {
      final userId = _toSnowflake(payload?['userId']);
      if (userId == null) {
        return {
          'error': 'userId is required when targetType is "user"',
          'messageId': '',
        };
      }
      final dmChannel = await client.users.createDm(userId);
      targetChannelId = dmChannel.id;
    }

    if (targetChannelId == null) {
      return {
        'error':
            'channelId is required for sendMessage (or use targetType=user with userId)',
        'messageId': '',
      };
    }

    final channel = await fetchChannelCached(client, targetChannelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    final resolvedContent = resolve != null ? resolve(content) : content;
    final messageMode =
        (payload?['messageMode'] ?? 'normal').toString().toLowerCase();

    List<ComponentBuilder>? components;
    bool isRichV2 = false;
    ComponentV2Definition? definition;
    List<EmbedBuilder>? embeds;

    if (messageMode == 'componentv2') {
      // ── Component V2 mode ─────────────────────────────────────────────
      if (payload != null &&
          payload.containsKey('componentV2') &&
          payload['componentV2'] is Map) {
        try {
          final def = ComponentV2Definition.fromJson(
            Map<String, dynamic>.from(payload['componentV2']),
          );
          definition = def;
          isRichV2 = def.isRichV2;
          components = buildComponentNodes(
            definition: def,
            resolve: resolve ?? (s) => s,
          );
        } catch (_) {}
      }
    } else {
      // ── Normal mode (embeds + V1 components) ──────────────────────────
      if (payload != null) {
        final r = resolve ?? (s) => s;

        // Embeds
        final embedsRaw =
            (payload['embeds'] is List)
                ? List<Map<String, dynamic>>.from(
                  (payload['embeds'] as List).whereType<Map>().map(
                    (e) => Map<String, dynamic>.from(
                      e.map((k, v) => MapEntry(k.toString(), v)),
                    ),
                  ),
                )
                : <Map<String, dynamic>>[];

        final parsedEmbeds = <EmbedBuilder>[];
        for (final embedJson in embedsRaw.take(10)) {
          embedJson.remove('video');
          embedJson.remove('provider');
          final embed = EmbedBuilder();

          final title = r((embedJson['title'] ?? '').toString());
          final description = r((embedJson['description'] ?? '').toString());
          final url = r((embedJson['url'] ?? '').toString());
          if (title.isNotEmpty) embed.title = title;
          if (description.isNotEmpty) embed.description = description;
          if (url.isNotEmpty) embed.url = Uri.tryParse(url);

          final timestampRaw = (embedJson['timestamp'] ?? '').toString();
          DateTime? timestamp;
          if (timestampRaw == 'now') {
            timestamp = DateTime.now().toUtc();
          } else {
            timestamp = DateTime.tryParse(timestampRaw);
            if (timestamp == null) {
              final ms = int.tryParse(timestampRaw);
              if (ms != null) {
                timestamp = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
              }
            }
          }
          if (timestamp != null) embed.timestamp = timestamp;

          final colorRaw = (embedJson['color'] ?? '').toString();
          if (colorRaw.isNotEmpty) {
            int? colorInt;
            if (colorRaw.startsWith('#')) {
              colorInt = int.tryParse(colorRaw.substring(1), radix: 16);
            } else {
              colorInt = int.tryParse(colorRaw);
            }
            if (colorInt != null) {
              embed.color = DiscordColor.fromRgb(
                (colorInt >> 16) & 0xFF,
                (colorInt >> 8) & 0xFF,
                colorInt & 0xFF,
              );
            }
          }

          final footerJson = Map<String, dynamic>.from(
            (embedJson['footer'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          final footerText = r((footerJson['text'] ?? '').toString());
          final footerIcon = r((footerJson['icon_url'] ?? '').toString());
          if (footerText.isNotEmpty || footerIcon.isNotEmpty) {
            embed.footer = EmbedFooterBuilder(
              text: footerText.isEmpty ? '\u200B' : footerText,
              iconUrl: footerIcon.isNotEmpty ? Uri.tryParse(footerIcon) : null,
            );
          }

          final authorJson = Map<String, dynamic>.from(
            (embedJson['author'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          final authorName = r((authorJson['name'] ?? '').toString());
          final authorUrl = r((authorJson['url'] ?? '').toString());
          final authorIcon = r(
            (authorJson['author_icon_url'] ?? authorJson['icon_url'] ?? '')
                .toString(),
          );
          if (authorName.isNotEmpty || authorUrl.isNotEmpty || authorIcon.isNotEmpty) {
            embed.author = EmbedAuthorBuilder(
              name: authorName.isEmpty ? '\u200B' : authorName,
              url: authorUrl.isNotEmpty ? Uri.tryParse(authorUrl) : null,
              iconUrl: authorIcon.isNotEmpty ? Uri.tryParse(authorIcon) : null,
            );
          }

          final imageJson = Map<String, dynamic>.from(
            (embedJson['image'] as Map?)?.cast<String, dynamic>() ?? const {},
          );
          final imageUrl = r((imageJson['url'] ?? '').toString());
          if (imageUrl.isNotEmpty) {
            embed.image = EmbedImageBuilder(url: Uri.parse(imageUrl));
          }

          final thumbnailJson = Map<String, dynamic>.from(
            (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ??
                const {},
          );
          final thumbnailUrl = r((thumbnailJson['url'] ?? '').toString());
          if (thumbnailUrl.isNotEmpty) {
            embed.thumbnail = EmbedThumbnailBuilder(
              url: Uri.parse(thumbnailUrl),
            );
          }

          final resolvedFields = buildResolvedEmbedFields(
            embedJson: embedJson,
            resolve: r,
          );
          if (resolvedFields.isNotEmpty) embed.fields = resolvedFields;

          parsedEmbeds.add(embed);
        }
        if (parsedEmbeds.isNotEmpty) embeds = parsedEmbeds;

        // Normal components (V1 only: ActionRow + buttons/selects)
        final componentsDef = payload['components'];
        if (componentsDef is Map) {
          final def = ComponentV2Definition.fromJson(
            Map<String, dynamic>.from(componentsDef),
          );
          if (!def.isRichV2 && def.components.isNotEmpty) {
            components = buildComponentNodes(definition: def, resolve: r);
          }
        }
      }
    }

    final hasPayload =
        resolvedContent.trim().isNotEmpty ||
        (embeds != null && embeds.isNotEmpty) ||
        (components != null && components.isNotEmpty);
    if (!hasPayload && !isRichV2) {
      return {
        'error': 'sendMessage needs at least content, embeds, or components',
        'messageId': '',
      };
    }

    final replyId = targetType == 'reply' ? _toSnowflake(payload?['messageId']) : null;

    final message = await channel.sendMessage(
      MessageBuilder(
        content:
            isRichV2
                ? null
                : (resolvedContent.isNotEmpty ? resolvedContent : null),
        embeds: embeds,
        components: components,
        referencedMessage: replyId != null ? MessageReferenceBuilder.reply(messageId: replyId) : null,
        flags: isRichV2 ? MessageFlags(32768) : null,
      ),
    );
    if (definition != null && botId != null && botId.trim().isNotEmpty) {
      registerComponentWorkflowBindings(
        definition: definition,
        resolve: resolve ?? (s) => s,
        botId: botId,
        guildId: guildId,
        channelId: targetChannelId.toString(),
        messageId: message.id.toString(),
      );
    }
    return {'messageId': message.id.toString()};
  } catch (e) {
    return {'error': 'Failed to send message: $e', 'messageId': ''};
  }
}
