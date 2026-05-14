import 'package:nyxx/nyxx.dart';
import '../types/component.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart'; // for updateString
import 'package:bot_creator_shared/utils/embed_fields.dart';
import '../utils/component_workflow_bindings.dart';
import '../utils/interaction_listener_registry.dart';
import '../utils/interaction_ack_state.dart';
import '../utils/workflow_call.dart';
import 'send_component_v2.dart';

/// Shared logic to determine and send the final response of a workflow execution.
/// Handles text, embeds, components, modals, and conditional logic.
bool requiresV2Flag(Map<String, dynamic> response) {
  final activeResponseType = (response['type'] ?? 'normal').toString();
  if (activeResponseType == 'componentV2') return true;

  // Check if components map itself indicates V2 necessity by having rich nodes
  final componentsJson = response['components'];
  if (componentsJson is Map) {
    try {
      final def = ComponentV2Definition.fromJson(
        Map<String, dynamic>.from(componentsJson),
      );
      if (def.isRichV2) return true;
    } catch (_) {}
  }

  final workflowConditional = Map<String, dynamic>.from(
    (response['workflow']?['conditional'] as Map?)?.cast<String, dynamic>() ??
        const {},
  );
  final useCondition = workflowConditional['enabled'] == true;

  if (useCondition) {
    if ((workflowConditional['whenTrueType'] ?? 'normal').toString() ==
        'componentV2') {
      return true;
    }
    if ((workflowConditional['whenFalseType'] ?? 'normal').toString() ==
        'componentV2') {
      return true;
    }

    // Check conditional component definitions too
    final trueComps = workflowConditional['whenTrueComponents'];
    if (trueComps is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(trueComps),
        );
        if (def.isRichV2) return true;
      } catch (_) {}
    }
    final falseComps = workflowConditional['whenFalseComponents'];
    if (falseComps is Map) {
      try {
        final def = ComponentV2Definition.fromJson(
          Map<String, dynamic>.from(falseComps),
        );
        if (def.isRichV2) return true;
      } catch (_) {}
    }
  }

  return false;
}

Future<void> sendWorkflowResponse({
  Interaction? interaction,
  NyxxGateway? gateway,
  Snowflake? fallbackChannelId,
  required Map<String, dynamic> response,
  required Map<String, String> runtimeVariables,
  required String botId,
  bool didDefer = false,
  bool isEphemeral = false,
  Future<void> Function(String, {required String botId})? onLog,
  Future<void> Function(String, {required String botId})? onDebugLog,
}) async {
  final workflowConditional = Map<String, dynamic>.from(
    (response['workflow']?['conditional'] as Map?)?.cast<String, dynamic>() ??
        const {},
  );

  final useCondition = workflowConditional['enabled'] == true;
  final conditionVariable =
      (workflowConditional['variable'] ?? '').toString().trim();
  final whenTrueType =
      (workflowConditional['whenTrueType'] ?? 'normal').toString();
  final whenFalseType =
      (workflowConditional['whenFalseType'] ?? 'normal').toString();
  final whenTrueText = (workflowConditional['whenTrueText'] ?? '').toString();
  final whenFalseText = (workflowConditional['whenFalseText'] ?? '').toString();
  final whenTrueEmbeds = List<Map<String, dynamic>>.from(
    (workflowConditional['whenTrueEmbeds'] as List?)?.whereType<Map>() ??
        const [],
  );
  final whenFalseEmbeds = List<Map<String, dynamic>>.from(
    (workflowConditional['whenFalseEmbeds'] as List?)?.whereType<Map>() ??
        const [],
  );

  var activeResponseType = (response['type'] ?? 'normal').toString();

  void autoUpgradeType(Map<String, dynamic>? comps) {
    if (activeResponseType != 'normal') return;
    if (comps == null || comps.isEmpty) return;
    try {
      final def = ComponentV2Definition.fromJson(
        Map<String, dynamic>.from(comps),
      );
      if (def.isRichV2) {
        activeResponseType = 'componentV2';
      }
    } catch (_) {}
  }

  autoUpgradeType(
    (response['components'] as Map?)?.cast<String, dynamic>(),
  );
  var activeModalJson = Map<String, dynamic>.from(
    (response['modal'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  var activeComponentsJson = Map<String, dynamic>.from(
    (response['components'] as Map?)?.cast<String, dynamic>() ?? const {},
  );
  String responseText = (response["text"] ?? "").toString();
  var embedsRaw =
      (response['embeds'] is List)
          ? List<Map<String, dynamic>>.from(
            (response['embeds'] as List).whereType<Map>().map(
              (embed) => Map<String, dynamic>.from(embed),
            ),
          )
          : <Map<String, dynamic>>[];

  if (useCondition && conditionVariable.isNotEmpty) {
    final variableValue =
        conditionVariable.contains('((')
            ? resolveTemplatePlaceholders(
              conditionVariable,
              runtimeVariables,
            ).trim()
            : (runtimeVariables[conditionVariable] ?? '').trim();
    final conditionMatched = variableValue.isNotEmpty;
    onDebugLog?.call(
      'Condition variable=$conditionVariable matched=$conditionMatched',
      botId: botId,
    );

    if (conditionMatched) {
      activeResponseType = whenTrueType;
      if (whenTrueText.trim().isNotEmpty) responseText = whenTrueText;
      if (whenTrueEmbeds.isNotEmpty) {
        embedsRaw = List<Map<String, dynamic>>.from(whenTrueEmbeds);
      }
      activeModalJson = Map<String, dynamic>.from(
        (workflowConditional['whenTrueModal'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
      activeComponentsJson = Map<String, dynamic>.from(
        ((activeResponseType == 'normal'
                        ? workflowConditional['whenTrueNormalComponents']
                        : workflowConditional['whenTrueComponents'])
                    as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
    } else {
      activeResponseType = whenFalseType;
      if (whenFalseText.trim().isNotEmpty) responseText = whenFalseText;
      if (whenFalseEmbeds.isNotEmpty) {
        embedsRaw = List<Map<String, dynamic>>.from(whenFalseEmbeds);
      }
      activeModalJson = Map<String, dynamic>.from(
        (workflowConditional['whenFalseModal'] as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
      activeComponentsJson = Map<String, dynamic>.from(
        ((activeResponseType == 'normal'
                        ? workflowConditional['whenFalseNormalComponents']
                        : workflowConditional['whenFalseComponents'])
                    as Map?)
                ?.cast<String, dynamic>() ??
            const {},
      );
    }

    autoUpgradeType(activeComponentsJson);
  }

  responseText = resolveTemplatePlaceholders(responseText, runtimeVariables);
  final isModal = activeResponseType == 'modal';

  if (isModal) {
    if (activeModalJson.isNotEmpty) {
      if (interaction == null) {
        onLog?.call(
          'Error: Modal response is not supported in this context (no interaction)',
          botId: botId,
        );
        return;
      }
      try {
        final definition = ModalDefinition.fromJson(activeModalJson);
        final modalBuilder = ModalBuilder(
          title: resolveTemplatePlaceholders(
            definition.title,
            runtimeVariables,
          ),
          customId: resolveTemplatePlaceholders(
            definition.customId,
            runtimeVariables,
          ),
          components:
              definition.inputs.map((input) {
                return ActionRowBuilder(
                  components: [
                    TextInputBuilder(
                      customId: resolveTemplatePlaceholders(
                        input.customId,
                        runtimeVariables,
                      ),
                      label: resolveTemplatePlaceholders(
                        input.label,
                        runtimeVariables,
                      ),
                      style:
                          input.style == BcTextInputStyle.paragraph
                              ? TextInputStyle.paragraph
                              : TextInputStyle.short,
                      placeholder:
                          input.placeholder.isNotEmpty
                              ? resolveTemplatePlaceholders(
                                input.placeholder,
                                runtimeVariables,
                              )
                              : null,
                      value:
                          input.defaultValue.isNotEmpty
                              ? resolveTemplatePlaceholders(
                                input.defaultValue,
                                runtimeVariables,
                              )
                              : null,
                      isRequired: input.required,
                      minLength: input.minLength,
                      maxLength: input.maxLength,
                    ),
                  ],
                );
              }).toList(),
        );

        if (interaction is ApplicationCommandInteraction) {
          await interaction.respondModal(modalBuilder);
          markInteractionAcknowledged(interaction);
        } else if (interaction is MessageComponentInteraction) {
          await interaction.respondModal(modalBuilder);
          markInteractionAcknowledged(interaction);
        } else {
          onLog?.call(
            'Error: This interaction type does not support modals',
            botId: botId,
          );
          return;
        }

        // Auto-register listener if onSubmitWorkflow is provided
        if (definition.onSubmitWorkflow != null &&
            definition.onSubmitWorkflow!.isNotEmpty) {
          final onSubmitWorkflow =
              resolveTemplatePlaceholders(
                definition.onSubmitWorkflow!,
                runtimeVariables,
              ).trim();
          if (onSubmitWorkflow.isNotEmpty) {
            final onSubmitArguments = resolveWorkflowCallArguments(
              definition.onSubmitArguments,
              (value) => resolveTemplatePlaceholders(value, runtimeVariables),
            );
            InteractionListenerRegistry.instance.register(
              resolveTemplatePlaceholders(
                definition.customId,
                runtimeVariables,
              ),
              ListenerEntry(
                botId: botId,
                workflowName: onSubmitWorkflow,
                workflowEntryPoint:
                    resolveTemplatePlaceholders(
                      definition.onSubmitEntryPoint,
                      runtimeVariables,
                    ).trim(),
                workflowArguments: onSubmitArguments,
                expiresAt: DateTime.now().add(const Duration(hours: 1)),
                type: 'modal',
                oneShot: true,
                guildId: interaction.guildId?.toString(),
                channelId: interaction.channelId?.toString(),
              ),
            );
          }
        }

        onLog?.call('Modal sent', botId: botId);
      } catch (e) {
        if (e.toString().contains('40060')) {
          onDebugLog?.call(
            'Modal response suppressed (already acknowledged)',
            botId: botId,
          );
        } else {
          onLog?.call('Modal build error: $e', botId: botId);
        }
      }
    }
  } else {
    // Standard text/embed/components reply
    if (embedsRaw.isEmpty) {
      final legacyEmbed = Map<String, dynamic>.from(
        (response['embed'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final hasLegacyEmbed =
          (legacyEmbed['title']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['description']?.toString().isNotEmpty ?? false) ||
          (legacyEmbed['url']?.toString().isNotEmpty ?? false);
      if (hasLegacyEmbed) {
        embedsRaw.add(legacyEmbed);
      }
    }

    Uri? resolveEmbedUri(dynamic raw) {
      final resolved =
          resolveTemplatePlaceholders(
            (raw ?? '').toString(),
            runtimeVariables,
          ).trim();
      if (resolved.isEmpty) {
        return null;
      }
      final uri = Uri.tryParse(resolved);
      if (uri == null || !uri.hasScheme) {
        return null;
      }
      return uri;
    }

    final embeds = <EmbedBuilder>[];
    for (final embedJson in embedsRaw.take(10)) {
      embedJson.remove('video');
      embedJson.remove('provider');
      final embed = EmbedBuilder();
      final title = resolveTemplatePlaceholders(
        (embedJson['title'] ?? '').toString(),
        runtimeVariables,
      );
      final description = resolveTemplatePlaceholders(
        (embedJson['description'] ?? '').toString(),
        runtimeVariables,
      );
      final embedUrl = resolveEmbedUri(embedJson['url']);

      if (title.isNotEmpty) embed.title = title;
      if (description.isNotEmpty) embed.description = description;
      if (embedUrl != null) embed.url = embedUrl;

      final timestamp = DateTime.tryParse(
        resolveTemplatePlaceholders(
          (embedJson['timestamp'] ?? '').toString(),
          runtimeVariables,
        ).trim(),
      );
      if (timestamp != null) embed.timestamp = timestamp;

      final colorRaw =
          resolveTemplatePlaceholders(
            (embedJson['color'] ?? '').toString(),
            runtimeVariables,
          ).trim();
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
      final footerText = resolveTemplatePlaceholders(
        (footerJson['text'] ?? '').toString(),
        runtimeVariables,
      );
      final footerIconUri = resolveEmbedUri(footerJson['icon_url']);
      if (footerText.isNotEmpty || footerIconUri != null) {
        embed.footer = EmbedFooterBuilder(
          text: footerText.isEmpty ? '\u200B' : footerText,
          iconUrl: footerIconUri,
        );
      }

      final authorJson = Map<String, dynamic>.from(
        (embedJson['author'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final authorName = resolveTemplatePlaceholders(
        (authorJson['name'] ?? '').toString(),
        runtimeVariables,
      );
      final authorUrlUri = resolveEmbedUri(authorJson['url']);
      final authorIconUri = resolveEmbedUri(
        authorJson['author_icon_url'] ?? authorJson['icon_url'],
      );
      if (authorName.isNotEmpty ||
          authorUrlUri != null ||
          authorIconUri != null) {
        embed.author = EmbedAuthorBuilder(
          name: authorName.isEmpty ? '\u200B' : authorName,
          url: authorUrlUri,
          iconUrl: authorIconUri,
        );
      }

      final imageJson = Map<String, dynamic>.from(
        (embedJson['image'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final imageUri = resolveEmbedUri(imageJson['url']);
      if (imageUri != null) {
        embed.image = EmbedImageBuilder(url: imageUri);
      }

      final thumbnailJson = Map<String, dynamic>.from(
        (embedJson['thumbnail'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
      final thumbnailUri = resolveEmbedUri(thumbnailJson['url']);
      if (thumbnailUri != null) {
        embed.thumbnail = EmbedThumbnailBuilder(url: thumbnailUri);
      }

      final resolvedFields = buildResolvedEmbedFields(
        embedJson: embedJson,
        resolve:
            (input) => resolveTemplatePlaceholders(input, runtimeVariables),
      );
      if (resolvedFields.isNotEmpty) {
        embed.fields = resolvedFields;
      }

      embeds.add(embed);
    }

    List<ComponentBuilder>? componentNodes;
    ComponentV2Definition? activeComponentDefinition;
    if (activeResponseType == 'componentV2' || activeResponseType == 'normal') {
      if (activeComponentsJson.isNotEmpty) {
        try {
          activeComponentDefinition = ComponentV2Definition.fromJson(
            activeComponentsJson,
          );
          final built = buildComponentNodes(
            definition: activeComponentDefinition,
            resolve: (s) => resolveTemplatePlaceholders(s, runtimeVariables),
          );
          if (built.isNotEmpty) {
            if (activeResponseType == 'normal') {
              // In 'normal' mode, we strictly ignore V2-only components
              // (containers, sections, etc.) to ensure legacy compatibility.
              componentNodes = built.whereType<ActionRowBuilder>().toList();
            } else {
              componentNodes = built;
            }
          }
        } catch (e) {
          onLog?.call('Components build error: $e', botId: botId);
        }
      }
    }

    final isResponded = interaction != null && isInteractionAcknowledged(interaction);

    final hasCustomResponse =
        responseText.isNotEmpty ||
        embeds.isNotEmpty ||
        (componentNodes?.isNotEmpty ?? false);

    // If no custom response and interaction already responded, just return
    if (isResponded && !hasCustomResponse) {
      onLog?.call('Actions already handled, no default response', botId: botId);
      return;
    }

    final useV2Flag = activeResponseType == 'componentV2';

    String? responseMessageId;

    final finalText =
        responseText.isEmpty &&
                embeds.isEmpty &&
                (componentNodes?.isEmpty ?? true) &&
                !useV2Flag // Don't add default text if in V2 mode
            ? 'No response outputted.'
            : responseText;

    if (interaction == null) {
      if (gateway == null || fallbackChannelId == null) {
        onLog?.call(
          'Error: Cannot send response without interaction, gateway and fallbackChannelId',
          botId: botId,
        );
        return;
      }
      try {
        final channel = await gateway.channels.get(fallbackChannelId).catchError((e) => gateway.channels.fetch(fallbackChannelId));
        if (channel is! TextChannel) {
          onLog?.call('Error: Fallback channel is not a text channel', botId: botId);
          return;
        }

        if (useV2Flag) {
          if (activeComponentDefinition != null) {
             final builder = buildComponentMessage(
               definition: activeComponentDefinition,
               resolve: (s) => resolveTemplatePlaceholders(s, runtimeVariables),
             );
             final message = await channel.sendMessage(builder);
             responseMessageId = message.id.toString();
          }
        } else {
          final builder = MessageBuilder(
            content: finalText.isEmpty ? null : finalText,
            embeds: embeds.isEmpty ? null : embeds,
            components: componentNodes,
          );
          final message = await channel.sendMessage(builder);
          responseMessageId = message.id.toString();
        }
        onLog?.call('Response sent to fallback channel', botId: botId);
      } catch (e) {
        onLog?.call('Error sending response to fallback channel: $e', botId: botId);
      }
    } else if (didDefer) {
      final updateBuilder = MessageUpdateBuilder(
        content: useV2Flag ? null : (finalText.isEmpty ? null : finalText),
        components: componentNodes,
      );
      if (useV2Flag) {
        updateBuilder.embeds = [];
      } else {
        updateBuilder.embeds = embeds;
      }

      if (interaction is MessageResponse ||
          interaction is ModalSubmitInteraction) {
        final updatedMessage = await (interaction as dynamic)
            .updateOriginalResponse(updateBuilder);
        markInteractionAcknowledged(interaction);
        responseMessageId = updatedMessage.id.toString();
        onLog?.call('Response edited after defer', botId: botId);
      } else {
        try {
          final updatedMessage = await (interaction as dynamic)
              .updateOriginalResponse(updateBuilder);
          responseMessageId = (updatedMessage as dynamic)?.id?.toString();
          onLog?.call(
            'Response edited after defer (dynamic fallback)',
            botId: botId,
          );
        } catch (e) {
          onLog?.call(
            'Failed to edit deferred response for ${interaction.runtimeType}: $e',
            botId: botId,
          );
        }
      }
    } else {
      int flagValue = isEphemeral ? MessageFlags.ephemeral.value : 0;

      if (useV2Flag) flagValue |= 32768; // IS_COMPONENTS_V2

      if (interaction is MessageResponse ||
          interaction is ModalSubmitInteraction) {
        await (interaction as dynamic).respond(
          MessageBuilder(
            content: useV2Flag ? null : (finalText.isEmpty ? null : finalText),
            embeds: useV2Flag ? null : (embeds.isEmpty ? null : embeds),
            components: componentNodes,
            flags: flagValue > 0 ? MessageFlags(flagValue) : null,
          ),
        );
        markInteractionAcknowledged(interaction);
        try {
          final responseMessage =
              await (interaction as dynamic).fetchOriginalResponse();
          responseMessageId = responseMessage.id.toString();
        } catch (_) {}
        onLog?.call('Response sent', botId: botId);
      } else {
        try {
          await (interaction as dynamic).respond(
            MessageBuilder(
              content:
                  useV2Flag ? null : (finalText.isEmpty ? null : finalText),
              embeds: useV2Flag ? null : (embeds.isEmpty ? null : embeds),
              components: componentNodes,
              flags: flagValue > 0 ? MessageFlags(flagValue) : null,
            ),
          );
          markInteractionAcknowledged(interaction);
          onLog?.call(
            'Response sent (dynamic fallback) for ${interaction.runtimeType}',
            botId: botId,
          );
        } catch (e) {
          onLog?.call(
            'Failed to send response for ${interaction.runtimeType}: $e',
            botId: botId,
          );
          if (e.toString().contains('40060')) {
            markInteractionAcknowledged(interaction);
          }
        }
      }
    }

    if (activeComponentDefinition != null) {
      registerComponentWorkflowBindings(
        definition: activeComponentDefinition,
        resolve: (s) => resolveTemplatePlaceholders(s, runtimeVariables),
        botId: botId,
        guildId: (interaction?.guildId ?? fallbackChannelId)?.toString(),
        channelId: (interaction?.channelId ?? fallbackChannelId)?.toString(),
        messageId: responseMessageId,
      );
    }

    // Auto-delete if requested
    final shouldDelete = runtimeVariables.entries.any(
      (e) =>
          (e.key.toLowerCase().endsWith('deleteitself') ||
              e.key.toLowerCase().endsWith('deleteresponse')) &&
          e.value.toLowerCase() == 'true',
    );

    if (shouldDelete) {
      try {
        if (interaction is MessageResponse ||
            interaction is ModalSubmitInteraction) {
          await (interaction as dynamic).deleteOriginalResponse();
          onLog?.call('Response auto-deleted', botId: botId);
        }
      } catch (_) {}
    }
  }
}
