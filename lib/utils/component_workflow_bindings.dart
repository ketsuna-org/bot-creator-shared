import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/types/component.dart';
import 'package:bot_creator_shared/utils/interaction_listener_registry.dart';

/// Extracts inline-action listeners from component definitions.
/// Each button/select with inline actions produces a ListenerEntry
/// registered under its customId.
void registerComponentWorkflowBindings({
  required ComponentV2Definition definition,
  required String Function(String) resolve,
  required String botId,
  String? guildId,
  String? channelId,
  String? messageId,
  Duration ttl = const Duration(hours: 24),
}) {
  final expiresAt = DateTime.now().add(ttl);

  void collectAndRegister(ComponentNode node) {
    if (node is ButtonNode) {
      if (node.style != BcButtonStyle.link &&
          node.customId.trim().isNotEmpty &&
          node.actions.isNotEmpty) {
        final resolvedId = resolve(node.customId).trim();
        InteractionListenerRegistry.instance.register(
          resolvedId,
          ListenerEntry(
            botId: botId,
            customId: resolvedId,
            inlineActions: node.actions.map((a) => Action.fromJson(a)).toList(),
            expiresAt: expiresAt,
            type: 'button',
            oneShot: false,
            guildId: guildId,
            channelId: channelId,
            messageId: messageId,
          ),
        );
        print(
          '[registerComponentWorkflowBindings] Registered button listener: '
          'customId="$resolvedId" botId=$botId guildId=$guildId '
          'channelId=$channelId messageId=$messageId '
          'actions=${node.actions.length}',
        );
      }
      return;
    }

    if (node is SelectMenuNode) {
      if (node.customId.trim().isNotEmpty && node.actions.isNotEmpty) {
        final resolvedId = resolve(node.customId).trim();
        InteractionListenerRegistry.instance.register(
          resolvedId,
          ListenerEntry(
            botId: botId,
            customId: resolvedId,
            inlineActions: node.actions.map((a) => Action.fromJson(a)).toList(),
            expiresAt: expiresAt,
            type: 'select',
            oneShot: false,
            guildId: guildId,
            channelId: channelId,
            messageId: messageId,
          ),
        );
        print(
          '[registerComponentWorkflowBindings] Registered select listener: '
          'customId="$resolvedId" botId=$botId guildId=$guildId '
          'channelId=$channelId messageId=$messageId '
          'actions=${node.actions.length}',
        );
      }
      return;
    }

    if (node is ActionRowNode) {
      for (final child in node.components) {
        collectAndRegister(child);
      }
      return;
    }

    if (node is ContainerNode) {
      for (final child in node.components) {
        collectAndRegister(child);
      }
      return;
    }

    if (node is SectionNode) {
      for (final child in node.components) {
        collectAndRegister(child);
      }
      if (node.accessory != null) {
        collectAndRegister(node.accessory!);
      }
      return;
    }

    if (node is LabelNode && node.component != null) {
      collectAndRegister(node.component!);
    }
  }

  for (final node in definition.components) {
    collectAndRegister(node);
  }
}
