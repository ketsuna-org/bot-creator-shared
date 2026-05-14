import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/component_workflow_bindings.dart';
import 'package:bot_creator_shared/types/component.dart';
import 'package:bot_creator_shared/actions/send_component_v2.dart';
import 'package:bot_creator_shared/utils/embed_fields.dart';

/// Edit the original/deferred interaction response.
/// Can update content, and/or components.
Future<Map<String, dynamic>> editInteractionMessageAction(
  Interaction<dynamic> interaction, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
  String? botId,
}) async {
  try {
    if (interaction is! MessageResponse) {
      return {'error': 'Interaction does not support message responses'};
    }

    final msgInteraction = interaction;
    final content = resolve((payload['content'] ?? '').toString());
    final clearEmbeds = payload['clearEmbeds'] == true;
    final clearComponents = payload['clearComponents'] == true;

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

        final title = resolve((embedJson['title'] ?? '').toString());
        final description = resolve(
          (embedJson['description'] ?? '').toString(),
        );
        final url = resolve((embedJson['url'] ?? '').toString());

        if (title.isNotEmpty) embed.title = title;
        if (description.isNotEmpty) embed.description = description;
        if (url.isNotEmpty) embed.url = Uri.tryParse(url);

        final timestampRaw = resolve((embedJson['timestamp'] ?? '').toString());
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

        final colorRaw = resolve((embedJson['color'] ?? '').toString());
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
        final footerText = resolve((footerJson['text'] ?? '').toString());
        final footerIcon = resolve((footerJson['icon_url'] ?? '').toString());
        if (footerText.isNotEmpty || footerIcon.isNotEmpty) {
          embed.footer = EmbedFooterBuilder(
            text: footerText,
            iconUrl: footerIcon.isNotEmpty ? Uri.tryParse(footerIcon) : null,
          );
        }

        final authorJson = Map<String, dynamic>.from(
          (embedJson['author'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
        final authorName = resolve((authorJson['name'] ?? '').toString());
        final authorUrl = resolve((authorJson['url'] ?? '').toString());
        final authorIcon = resolve(
          (authorJson['author_icon_url'] ?? authorJson['icon_url'] ?? '')
              .toString(),
        );
        if (authorName.isNotEmpty) {
          embed.author = EmbedAuthorBuilder(
            name: authorName,
            url: authorUrl.isNotEmpty ? Uri.tryParse(authorUrl) : null,
            iconUrl: authorIcon.isNotEmpty ? Uri.tryParse(authorIcon) : null,
          );
        }

        final imageJson = Map<String, dynamic>.from(
          (embedJson['image'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
        final imageUrl = resolve((imageJson['url'] ?? '').toString());
        if (imageUrl.isNotEmpty) {
          embed.image = EmbedImageBuilder(url: Uri.parse(imageUrl));
        }

        final thumbnailJson = Map<String, dynamic>.from(
          (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ?? const {},
        );
        final thumbnailUrl = resolve((thumbnailJson['url'] ?? '').toString());
        if (thumbnailUrl.isNotEmpty) {
          embed.thumbnail = EmbedThumbnailBuilder(url: Uri.parse(thumbnailUrl));
        }

        final resolvedFields = buildResolvedEmbedFields(
          embedJson: embedJson,
          resolve: resolve,
        );
        if (resolvedFields.isNotEmpty) {
          embed.fields = resolvedFields;
        }

        embeds.add(embed);
      }
    }

    // Build components if defined
    List<ComponentBuilder>? actionRows;
    ComponentV2Definition? definition;
    final componentsDef = payload['components'];
    if (clearComponents) {
      actionRows = [];
    } else if (componentsDef is Map && componentsDef.isNotEmpty) {
      definition = ComponentV2Definition.fromJson(
        Map<String, dynamic>.from(
          componentsDef.map((k, v) => MapEntry(k.toString(), v)),
        ),
      );
      actionRows = buildComponentNodes(
        definition: definition,
        resolve: resolve,
      );
    }

    final builder = MessageUpdateBuilder(
      content: content.isNotEmpty ? content : null,
      embeds: shouldUpdateEmbeds ? embeds : null,
      components: actionRows,
    );

    final message = await msgInteraction.updateOriginalResponse(builder);
    if (definition != null && botId != null && botId.trim().isNotEmpty) {
      registerComponentWorkflowBindings(
        definition: definition,
        resolve: resolve,
        botId: botId,
        guildId: interaction.guildId?.toString(),
        channelId: interaction.channelId?.toString(),
        messageId: message.id.toString(),
      );
    }
    return {'messageId': message.id.toString()};
  } catch (e) {
    return {'error': e.toString()};
  }
}
