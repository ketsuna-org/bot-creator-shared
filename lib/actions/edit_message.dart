import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/global.dart';
import '../types/component.dart';
import '../utils/component_workflow_bindings.dart';
import '../utils/embed_fields.dart';
import '../utils/allowed_mentions_parser.dart';
import 'send_component_v2.dart';

Snowflake? _toSnowflake(dynamic value) {
  final parsed = int.tryParse(value?.toString() ?? '');
  if (parsed == null) {
    return null;
  }
  return Snowflake(parsed);
}

Future<Map<String, String>> editMessageAction(
  NyxxGateway client, {
  required Map<String, dynamic> payload,
  required Snowflake? fallbackChannelId,
  required String content,
  String Function(String)? resolve,
  String? botId,
  String? guildId,
}) async {
  try {
    final channelId = _toSnowflake(payload['channelId']) ?? fallbackChannelId;
    final messageId = _toSnowflake(payload['messageId']);
    if (channelId == null || messageId == null) {
      return {'error': 'Missing channelId/messageId', 'messageId': ''};
    }

    final channel = await fetchChannelCached(client, channelId);
    if (channel is! TextChannel) {
      return {'error': 'Channel is not a text channel', 'messageId': ''};
    }

    final message = await channel.messages.fetch(messageId);
    final clearEmbeds = payload['clearEmbeds'] == true;
    final embedsRaw =
        (payload['embeds'] is List)
            ? List<Map<String, dynamic>>.from(
              (payload['embeds'] as List).whereType<Map>().map(
                (embed) => Map<String, dynamic>.from(
                  embed.map((key, value) => MapEntry(key.toString(), value)),
                ),
              ),
            )
            : <Map<String, dynamic>>[];

    final shouldUpdateEmbeds = clearEmbeds || payload['embeds'] is List;
    final embeds = <EmbedBuilder>[];
    if (!clearEmbeds) {
      for (final embedJson in embedsRaw.take(10)) {
        embedJson.remove('video');
        embedJson.remove('provider');
        final embed = EmbedBuilder();

        final title =
            resolve?.call((embedJson['title'] ?? '').toString()) ??
            (embedJson['title'] ?? '').toString();
        final description =
            resolve?.call((embedJson['description'] ?? '').toString()) ??
            (embedJson['description'] ?? '').toString();
        final url =
            resolve?.call((embedJson['url'] ?? '').toString()) ??
            (embedJson['url'] ?? '').toString();

        if (title.isNotEmpty) embed.title = title;
        if (description.isNotEmpty) embed.description = description;
        if (url.isNotEmpty) embed.url = Uri.tryParse(url);

        final timestampRaw =
            resolve?.call((embedJson['timestamp'] ?? '').toString()) ??
            (embedJson['timestamp'] ?? '').toString();
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
        if (timestamp != null) {
          embed.timestamp = timestamp;
        }

        final colorRaw =
            resolve?.call((embedJson['color'] ?? '').toString()) ??
            (embedJson['color'] ?? '').toString();
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
        final footerText =
            resolve?.call((footerJson['text'] ?? '').toString()) ??
            (footerJson['text'] ?? '').toString();
        final footerIcon =
            resolve?.call((footerJson['icon_url'] ?? '').toString()) ??
            (footerJson['icon_url'] ?? '').toString();
        if (footerText.isNotEmpty || footerIcon.isNotEmpty) {
          embed.footer = EmbedFooterBuilder(
            text: footerText.isEmpty ? '\u200B' : footerText,
            iconUrl: footerIcon.isNotEmpty ? Uri.tryParse(footerIcon) : null,
          );
        }

        final authorJson = Map<String, dynamic>.from(
          (embedJson['author'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
        final authorName =
            resolve?.call((authorJson['name'] ?? '').toString()) ??
            (authorJson['name'] ?? '').toString();
        final authorUrl =
            resolve?.call((authorJson['url'] ?? '').toString()) ??
            (authorJson['url'] ?? '').toString();
        final authorIcon =
            resolve?.call(
              (authorJson['author_icon_url'] ?? authorJson['icon_url'] ?? '')
                  .toString(),
            ) ??
            (authorJson['author_icon_url'] ?? authorJson['icon_url'] ?? '')
                .toString();
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
        final imageUrl =
            resolve?.call((imageJson['url'] ?? '').toString()) ??
            (imageJson['url'] ?? '').toString();
        if (imageUrl.isNotEmpty) {
          embed.image = EmbedImageBuilder(url: Uri.parse(imageUrl));
        }

        final thumbnailJson = Map<String, dynamic>.from(
          (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
        final thumbnailUrl =
            resolve?.call((thumbnailJson['url'] ?? '').toString()) ??
            (thumbnailJson['url'] ?? '').toString();
        if (thumbnailUrl.isNotEmpty) {
          embed.thumbnail = EmbedThumbnailBuilder(url: Uri.parse(thumbnailUrl));
        }

        final resolvedFields = buildResolvedEmbedFields(
          embedJson: embedJson,
          resolve: resolve ?? (value) => value,
        );
        if (resolvedFields.isNotEmpty) {
          embed.fields = resolvedFields;
        }

        embeds.add(embed);
      }
    }

    final clearComponents = payload['clearComponents'] == true;
    List<ComponentBuilder>? components;
    ComponentV2Definition? definition;
    final componentsDef = payload['components'] ?? payload['componentV2'];
    if (clearComponents) {
      components = [];
    } else if (componentsDef is Map && componentsDef.isNotEmpty) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(
            componentsDef.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
        definition = def;
        components = buildComponentNodes(
          definition: def,
          resolve: resolve ?? (s) => s,
        );
      } catch (_) {}
    }

    final allowedMentions = parseAllowedMentions(payload, resolve ?? (s) => s);

    final builder = MessageUpdateBuilder(
      allowedMentions: allowedMentions,
    );
    if (content.isNotEmpty) {
      builder.content = content;
    }
    if (shouldUpdateEmbeds) {
      builder.embeds = embeds;
    }
    if (clearComponents || (componentsDef is Map && componentsDef.isNotEmpty)) {
      builder.components = components;
    }

    await message.edit(builder);
    if (definition != null && botId != null && botId.trim().isNotEmpty) {
      registerComponentWorkflowBindings(
        definition: definition,
        resolve: resolve ?? (s) => s,
        botId: botId,
        guildId: guildId,
        channelId: channelId.toString(),
        messageId: message.id.toString(),
      );
    }
    return {'messageId': message.id.toString()};
  } catch (error) {
    return {'error': 'Failed to edit message: $error', 'messageId': ''};
  }
}
