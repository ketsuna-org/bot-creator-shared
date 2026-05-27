import 'package:nyxx/nyxx.dart';

import '../../types/action.dart';
import '../../utils/interaction_listener_registry.dart';
import '../../utils/workflow_call.dart';
import '../edit_component_v2.dart';
import '../edit_interaction_response.dart';
import '../respond_modal.dart';
import '../respond_with_message.dart';
import '../send_component_v2.dart';

String? _resolveListenerMessageId({
  required Map<String, dynamic> payload,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  Interaction? interaction,
}) {
  final explicitMessageId =
      resolveValue((payload['messageId'] ?? '').toString()).trim();
  if (explicitMessageId.isNotEmpty) {
    return explicitMessageId;
  }

  final runtimeMessageId =
      variables['interaction.messageId'] ??
      variables['messageId'] ??
      variables['message.id'];
  if (runtimeMessageId != null && runtimeMessageId.trim().isNotEmpty) {
    return runtimeMessageId.trim();
  }

  final dynamic dynInteraction = interaction;
  final interactionMessageId =
      (dynInteraction?.message?.id as Snowflake?)?.toString();
  if (interactionMessageId != null && interactionMessageId.isNotEmpty) {
    return interactionMessageId;
  }

  return null;
}

String? _resolveExplicitListenerMessageId(
  Map<String, dynamic> payload,
  String Function(String input) resolveValue,
) {
  final messageId =
      resolveValue((payload['messageId'] ?? '').toString()).trim();
  return messageId.isEmpty ? null : messageId;
}

Future<bool> executeComponentsInteractionsAction({
  required BotCreatorActionType type,
  required NyxxGateway? client,
  required Interaction? interaction,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String botId,
  required Snowflake? guildId,
  required Snowflake? fallbackChannelId,
  Snowflake? fallbackMessageId,
  required String Function(String input) resolveValue,
}) async {
  switch (type) {
    case BotCreatorActionType.sendComponentV2:
      final result = await respondWithComponentV2Action(
        interaction,
        payload: payload,
        client: client,
        fallbackChannelId: fallbackChannelId,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.editComponentV2:
      final result = await editComponentV2Action(
        client!,
        payload: payload,
        fallbackChannelId: fallbackChannelId,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (result['error'] != null) {
        throw Exception(result['error']);
      }
      results[resultKey] = result['messageId'] ?? '';
      return true;

    case BotCreatorActionType.respondWithComponentV2:
      final respResult = await respondWithComponentV2Action(
        interaction,
        payload: payload,
        client: client,
        fallbackChannelId: fallbackChannelId,
        resolve: resolveValue,
        botId: botId,
        guildId: guildId?.toString(),
      );
      if (respResult['error'] != null) {
        throw Exception(respResult['error']);
      }
      results[resultKey] = respResult['messageId'] ?? 'responded';
      return true;

    case BotCreatorActionType.respondWithMessage:
      final messageResult = await respondWithMessageAction(
        interaction,
        payload: payload,
        resolve: resolveValue,
        botId: botId,
        client: client,
        fallbackChannelId: fallbackChannelId,
        fallbackMessageId: fallbackMessageId,
      );
      if (messageResult['error'] != null) {
        throw Exception(messageResult['error']);
      }
      results[resultKey] = messageResult['messageId'] ?? 'responded';
      return true;

    case BotCreatorActionType.respondWithModal:
      if (interaction == null) {
        results[resultKey] =
            'Error: respondWithModal requires an active interaction context';
        return true;
      }
      final modalResult = await respondWithModalAction(
        interaction,
        payload: payload,
        resolve: resolveValue,
      );
      if (modalResult['error'] != null) {
        throw Exception(modalResult['error']);
      }
      final customId = modalResult['customId'] ?? 'modal_sent';
      results[resultKey] = customId;

      final onSubmitWorkflow =
          resolveValue(
            (modalResult['onSubmitWorkflow'] ?? '').toString(),
          ).trim();
      if (onSubmitWorkflow.isNotEmpty) {
        final onSubmitEntryPoint =
            resolveValue(
              (modalResult['onSubmitEntryPoint'] ?? '').toString(),
            ).trim();
        final onSubmitArguments = resolveWorkflowCallArguments(
          modalResult['onSubmitArguments'],
          resolveValue,
        );
        InteractionListenerRegistry.instance.register(
          customId,
          ListenerEntry(
            botId: botId,
            workflowName: onSubmitWorkflow,
            workflowEntryPoint: onSubmitEntryPoint,
            workflowArguments: onSubmitArguments,
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            type: 'modal',
            oneShot: true,
            guildId: guildId?.toString(),
            channelId: fallbackChannelId?.toString(),
            messageId: _resolveExplicitListenerMessageId(
              modalResult,
              resolveValue,
            ),
          ),
        );
      }
      return true;

    case BotCreatorActionType.editInteractionMessage:
      if (interaction == null) {
        results[resultKey] =
            'Error: editInteractionMessage requires an interaction context';
        return true;
      }
      final editResult = await editInteractionMessageAction(
        interaction,
        payload: payload,
        resolve: resolveValue,
        botId: botId,
      );
      if (editResult['error'] != null) {
        throw Exception(editResult['error']);
      }
      results[resultKey] = editResult['messageId'] ?? '';
      return true;

    case BotCreatorActionType.listenForButtonClick:
    case BotCreatorActionType.listenForSelectMenu:
    case BotCreatorActionType.listenForModalSubmit:
      final customId = resolveValue((payload['customId'] ?? '').toString());
      if (customId.isEmpty) {
        throw Exception('customId is required for ${type.name}');
      }
      final workflowName = resolveValue(
        (payload['workflowName'] ?? '').toString(),
      );
      if (workflowName.isEmpty) {
        throw Exception('workflowName is required for ${type.name}');
      }

      // Guard: in an event workflow, listenForButtonClick/listenForSelectMenu
      // without an explicit messageId should NOT derive a messageId from the
      // triggering event context (that would cause mismatches on subsequent
      // clicks). Instead, pass null so the listener matches any message with
      // the given customId.

      final ttlRaw = payload['ttlMinutes'];
      final ttlMinutes = (ttlRaw is num
              ? ttlRaw.toInt()
              : int.tryParse(ttlRaw?.toString() ?? '') ?? 60)
          .clamp(1, 60);
      // Modals are always one-shot; buttons/selects repeat on every click until TTL.
      final oneShot = type == BotCreatorActionType.listenForModalSubmit;
      final workflowEntryPoint =
          resolveValue((payload['entryPoint'] ?? '').toString()).trim();
      final workflowArguments = resolveWorkflowCallArguments(
        payload['arguments'],
        resolveValue,
      );

      InteractionListenerRegistry.instance.register(
        customId,
        ListenerEntry(
          botId: botId,
          workflowName: workflowName,
          workflowEntryPoint: workflowEntryPoint,
          workflowArguments: workflowArguments,
          expiresAt: DateTime.now().add(Duration(minutes: ttlMinutes)),
          type:
              type == BotCreatorActionType.listenForButtonClick
                  ? 'button'
                  : type == BotCreatorActionType.listenForSelectMenu
                  ? 'select'
                  : 'modal',
          oneShot: oneShot,
          guildId: guildId?.toString(),
          channelId: fallbackChannelId?.toString(),
          messageId:
              type == BotCreatorActionType.listenForModalSubmit
                  ? _resolveExplicitListenerMessageId(payload, resolveValue)
                  : variables['workflow.type'] == workflowTypeEvent
                  ? _resolveExplicitListenerMessageId(payload, resolveValue)
                  : _resolveListenerMessageId(
                    payload: payload,
                    variables: variables,
                    resolveValue: resolveValue,
                    interaction: interaction,
                  ),
        ),
      );
      results[resultKey] = 'listening:$customId';
      return true;

    default:
      return false;
  }
}
