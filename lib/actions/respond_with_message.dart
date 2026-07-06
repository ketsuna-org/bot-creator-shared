import 'dart:convert';

import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/types/component.dart';
import 'package:bot_creator_shared/actions/send_component_v2.dart';
import 'package:bot_creator_shared/utils/component_workflow_bindings.dart';
import 'package:bot_creator_shared/utils/embed_fields.dart';
import 'package:bot_creator_shared/utils/allowed_mentions_parser.dart';
import 'package:bot_creator_shared/utils/embed_timestamp.dart';

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
  Map<String, String>? variables,
}) async {
  try {
    // Collect canvas attachments from variables (set by $attachImage)
    final canvasAttachments = _collectCanvasAttachments(variables);

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
        attachments: canvasAttachments,
      );
      if (result['error'] != null) {
        // When content/embeds/components are all empty (e.g. template resolved
        // to blank inside a loop iteration), skip silently instead of crashing —
        // unless there are canvas attachments to send.
        final content = resolve((payload['content'] ?? '').toString());
        if (content.trim().isEmpty &&
            canvasAttachments == null &&
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

      final timestamp = parseEmbedTimestamp(
        resolve((embedJson['timestamp'] ?? '').toString()),
      );
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
        componentNodes.isNotEmpty ||
        canvasAttachments != null;
    if (!hasResponsePayload) {
      return {'messageId': '', 'status': 'skipped_empty'};
    }


    final dynInteraction = interaction as dynamic;

    // Use the canonical Expando-based tracking instead of nyxx's private field
    // (dynInteraction.isAcknowledged throws on nyxx 6.8.1 because the field is private).
    final isAcknowledged = isInteractionAcknowledged(interaction);

    final allowedMentions = parseAllowedMentions(payload, resolve);

    // When there are canvas attachments but no content/embed/component,
    // Discord API requires at least one non-null field.
    // Use a space so MessageBuilder doesn't reject it.
    final effectiveContent = content.trim().isEmpty
        ? (canvasAttachments != null ? ' ' : null)
        : content;

    if (isAcknowledged) {
      // When the interaction is already acknowledged (deferred):
      // - Ephemeral responses must use followup (Discord doesn't allow
      //   changing ephemerality on updateOriginalResponse).
      // - Responses with canvas attachments must also use followup because
      //   updateOriginalResponse (MessageUpdateBuilder) doesn't support
      //   file attachments — Discord doesn't allow editing message attachments.
      if (isEphemeral || canvasAttachments != null) {
        final followupMsg = await dynInteraction.createFollowup(
          MessageBuilder(
            content: effectiveContent,
            embeds: embeds.isEmpty ? null : embeds,
            components: componentNodes.isEmpty ? null : componentNodes,
            allowedMentions: allowedMentions,
            attachments: canvasAttachments,
          ),
          isEphemeral: isEphemeral,
        );
        markInteractionAcknowledged(interaction);
        registerComponentWorkflowBindings(
          definition: definition,
          resolve: resolve,
          botId: botId,
          guildId: interaction.guildId?.toString(),
          channelId: interaction.channelId?.toString(),
          messageId: followupMsg.id.toString(),
        );
        return {'messageId': followupMsg.id.toString()};
      }

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
        content: effectiveContent,
        embeds: embeds.isEmpty ? null : embeds,
        components: componentNodes.isEmpty ? null : componentNodes,
        flags: flags > 0 ? MessageFlags(flags) : null,
        allowedMentions: allowedMentions,
        attachments: canvasAttachments,
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
      'messageId': ?messageId,
      'status': 'responded',
    };
  } catch (e) {
    return {'error': e.toString()};
  }
}

/// Scans [variables] for keys matching `temp._canvasAttachment_*` and returns
/// a list of [AttachmentBuilder] objects ready to be included in a message.
/// Keys with empty values are skipped.
List<AttachmentBuilder>? _collectCanvasAttachments(
  Map<String, String>? variables,
) {
  if (variables == null || variables.isEmpty) return null;

  final attachments = <AttachmentBuilder>[];
  final keysToRemove = <String>[];
  for (final entry in variables.entries) {
    // setTemporaryVariable stores under 'temp.<key>'
    if (!entry.key.startsWith('temp._canvasAttachment_')) continue;
    if (entry.value.isEmpty) continue;

    // Extract the name from the key: temp._canvasAttachment_card → card
    final name =
        entry.key.substring('temp._canvasAttachment_'.length);
    if (name.isEmpty) continue;

    try {
      final bytes = base64Decode(entry.value);
      attachments.add(AttachmentBuilder(
        data: bytes,
        fileName: '$name.png',
      ));
      keysToRemove.add(entry.key);
    } catch (_) {
      // Not valid base64 — skip
    }
  }

  for (final key in keysToRemove) {
    variables.remove(key);
  }

  return attachments.isNotEmpty ? attachments : null;
}


