import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/types/component.dart' as bc;
import 'package:bot_creator_shared/utils/interaction_ack_state.dart';
import 'send_component_v2.dart';

/// Respond to an interaction with a Modal dialog.
/// NOTE: Modals can only be sent as the FIRST response (not after defer).
///
/// Supports two modal definition formats:
///   1. **New (components):** A `List<LabelNode>` wrapping modal-eligible
///      components — TextInput, SelectMenuNode, FileUploadNode,
///      RadioGroupNode, CheckboxGroupNode, CheckboxNode.
///   2. **Legacy (inputs):** A `List<ModalTextInputDefinition>` — plain text
///      inputs wrapped in ActionRows (deprecated by Discord but still
///      functional).
Future<Map<String, dynamic>> respondWithModalAction(
  Interaction interaction, {
  required Map<String, dynamic> payload,
  required String Function(String) resolve,
}) async {
  try {
    // Accept both wrapped payload['modal'] (from command_migration) and
    // top-level payload (from the BDFD transpiler).
    final modalJson = payload['modal'] ?? payload;
    if (modalJson == null || modalJson is! Map) {
      return {'error': 'modal definition is required'};
    }

    final definition = bc.ModalDefinition.fromJson(
      Map<String, dynamic>.from(modalJson),
    );

    if (definition.title.isEmpty) {
      return {'error': 'Modal title is required'};
    }
    if (definition.customId.isEmpty) {
      return {'error': 'Modal customId is required'};
    }

    final resolvedCustomId = resolve(definition.customId);

    // ── Build modal component builders ────────────────────────────
    final modalComponents = <ComponentBuilder>[];

    if (definition.hasComponentsV2) {
      // New format: each entry is a LabelNode wrapping a child component.
      for (final label in definition.components) {
        if (label is! bc.LabelNode) continue;
        final child = label.component;
        if (child == null) continue;

        final childBuilder = buildComponentNode(child, resolve);
        modalComponents.add(
          LabelComponentBuilder(
            label: resolve(label.label),
            description:
                label.description.isNotEmpty
                    ? resolve(label.description)
                    : null,
            component: childBuilder,
          ),
        );
      }
    }

    // Legacy format: wrap each ModalTextInputDefinition in an ActionRow
    // (only used when no new-style components were parsed).
    if (modalComponents.isEmpty && definition.inputs.isNotEmpty) {
      for (final input in definition.inputs) {
        modalComponents.add(
          ActionRowBuilder(
            components: [
              TextInputBuilder(
                customId: resolve(input.customId),
                // ignore: deprecated_member_use
                label: resolve(input.label),
                style:
                    input.style == bc.BcTextInputStyle.paragraph
                        ? TextInputStyle.paragraph
                        : TextInputStyle.short,
                placeholder:
                    input.placeholder.isNotEmpty
                        ? resolve(input.placeholder)
                        : null,
                value:
                    input.defaultValue.isNotEmpty
                        ? resolve(input.defaultValue)
                        : null,
                isRequired: input.required,
                minLength: input.minLength,
                maxLength: input.maxLength,
              ),
            ],
          ),
        );
      }
    }

    if (modalComponents.isEmpty) {
      return {
        'error': 'Modal must have at least one component (text input, select, '
            'file upload, radio group, checkbox group, or checkbox).',
      };
    }

    final modalBuilder = ModalBuilder(
      title: resolve(definition.title),
      customId: resolvedCustomId,
      components: modalComponents,
    );

    if (interaction is ApplicationCommandInteraction) {
      await interaction.respondModal(modalBuilder);
      markInteractionAcknowledged(interaction);
    } else if (interaction is MessageComponentInteraction) {
      await interaction.respondModal(modalBuilder);
      markInteractionAcknowledged(interaction);
    } else {
      return {'error': 'This interaction type does not support modals'};
    }
    return {
      'status': 'modal_sent',
      'customId': resolvedCustomId,
      'actions': definition.actions,
    };
  } catch (e) {
    return {'error': e.toString()};
  }
}
