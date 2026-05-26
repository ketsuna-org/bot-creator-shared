import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/types/component.dart';
import 'package:bot_creator_shared/actions/send_component_v2.dart';
import 'package:bot_creator_shared/utils/component_workflow_bindings.dart';
import 'package:bot_creator_shared/utils/embed_fields.dart';
import 'package:bot_creator_shared/utils/allowed_mentions_parser.dart';

import 'package:bot_creator_shared/actions/send_message.dart';
import 'package:bot_creator_shared/utils/interaction_ack_state.dart';

Future<Map<String, dynamic>> respondWithMessageAction(
  Interaction? interaction, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
  required String botId,
  NyxxGateway? client,
  Snowflake? fallbackChannelId,
  Snowflake? fallbackMessageId,
}) async {
  try {
    if (interaction == null) {
      if (client == null) {
        return {
          'error':
              'respondWithMessage requires either an interaction or a client for fallback',
        };
      }

      final channelIdRaw = resolve((payload['channelId'] ?? '').toString());
      Snowflake? channelId;
      if (channelIdRaw.isNotEmpty) {
        final parsed = int.tryParse(channelIdRaw);
        if (parsed != null) channelId = Snowflake(parsed);
      }
      channelId ??= fallbackChannelId;

      if (channelId == null) {
        return {'error': 'No channelId available for respondWithMessage fallback'};
      }

      // Build effective payload, injecting reply context when replyToMessage is set.
      final effectivePayload = Map<String, dynamic>.from(payload);
      final shouldReply = payload['replyToMessage'] == true;
      if (shouldReply && fallbackMessageId != null) {
        effectivePayload['targetType'] = 'reply';
        effectivePayload['messageId'] = fallbackMessageId.toString();
      }

      final result = await sendMessageToChannel(
        client,
        channelId,
        content: resolve((effectivePayload['content'] ?? '').toString()),
        payload: effectivePayload,
        resolve: resolve,
        botId: botId,
      );
      if (result['error'] != null) {
        // When content/embeds/components are all empty (e.g. template resolved
        // to blank inside a loop iteration), skip silently instead of crashing.
        final content = resolve((payload['content'] ?? '').toString());
        if (content.trim().isEmpty &&
            result['error']!.contains('needs at least')) {
          return {'messageId': '', 'status': 'skipped_empty'};
        }
        return result;
      }
      return result;
    }

    if (interaction is! MessageResponse &&
        interaction is! ModalSubmitInteraction) {
      return {'error': 'Interaction does not support message responses'};
    }

    final content = resolve((payload['content'] ?? '').toString());

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

    if (embedsRaw.isEmpty) {
      final legacyEmbed = Map<String, dynamic>.from(
        (payload['embed'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final hasLegacyEmbed =
          (legacyEmbed['title']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['description']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['url']?.toString().isNotEmpty ?? false);
      if (hasLegacyEmbed) {
        embedsRaw.add(legacyEmbed);
      }
    }

    final embeds = <EmbedBuilder>[];
    for (final embedJson in embedsRaw.take(10)) {
      embedJson.remove('video');
      embedJson.remove('provider');
      final embed = EmbedBuilder();

      final title = resolve((embedJson['title'] ?? '').toString());
      final description = resolve((embedJson['description'] ?? '').toString());
      final url = resolve((embedJson['url'] ?? '').toString());

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
      if (timestamp != null) {
        embed.timestamp = timestamp;
      }

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
      final footerText = resolve((footerJson['text'] ?? '').toString());
      final footerIcon = resolve((footerJson['icon_url'] ?? '').toString());
      if (footerText.isNotEmpty || footerIcon.isNotEmpty) {
        embed.footer = EmbedFooterBuilder(
          text: footerText.isEmpty ? '\u200B' : footerText,
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

    final isEphemeral = payload['ephemeral'] == true;
    final componentsDef = payload['components'];
    final definition =
        componentsDef is Map
            ? ComponentV2Definition.fromJson(
              Map<String, dynamic>.from(componentsDef),
            )
            : ComponentV2Definition();
    if (definition.isRichV2) {
      return {
        'error':
            'respondWithMessage supports only normal components (buttons/select menus). Use respondWithComponentV2 for rich V2 components.',
      };
    }
    final componentNodes =
        definition.components.isEmpty
            ? <ComponentBuilder>[]
            : buildComponentNodes(definition: definition, resolve: resolve);

    final hasResponsePayload =
        content.trim().isNotEmpty ||
        embeds.isNotEmpty ||
        componentNodes.isNotEmpty;
    if (!hasResponsePayload) {
      return {'messageId': '', 'status': 'skipped_empty'};
    }


    final dynInteraction = interaction as dynamic;

    bool isAcknowledged = false;
    try {
      isAcknowledged = dynInteraction.isAcknowledged == true;
    } catch (_) {
      isAcknowledged = false;
    }

    final allowedMentions = parseAllowedMentions(payload, resolve);

    if (isAcknowledged) {
      final message = await dynInteraction.updateOriginalResponse(
        MessageUpdateBuilder(
          content: content.trim().isEmpty ? null : content,
          embeds: embeds,
          components: componentNodes.isEmpty ? null : componentNodes,
          allowedMentions: allowedMentions,
        ),
      );
      markInteractionAcknowledged(interaction);
      registerComponentWorkflowBindings(
        definition: definition,
        resolve: resolve,
        botId: botId,
        guildId: interaction.guildId?.toString(),
        channelId: interaction.channelId?.toString(),
        messageId: message.id.toString(),
      );
      return {'messageId': message.id.toString()};
    }

    final flags = isEphemeral ? MessageFlags.ephemeral.value : 0;

    await dynInteraction.respond(
      MessageBuilder(
        content: content.trim().isEmpty ? null : content,
        embeds: embeds.isEmpty ? null : embeds,
        components: componentNodes.isEmpty ? null : componentNodes,
        flags: flags > 0 ? MessageFlags(flags) : null,
        allowedMentions: allowedMentions,
      ),
    );
    markInteractionAcknowledged(interaction);
    String? messageId;
    try {
      final responseMessage = await dynInteraction.fetchOriginalResponse();
      messageId = responseMessage.id.toString();
    } catch (_) {}
    registerComponentWorkflowBindings(
      definition: definition,
      resolve: resolve,
      botId: botId,
      guildId: interaction.guildId?.toString(),
      channelId: interaction.channelId?.toString(),
      messageId: messageId,
    );
    return {
      if (messageId != null) 'messageId': messageId,
      'status': 'responded',
    };
  } catch (e) {
    return {'error': e.toString()};
  }
}


