import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/utils/interaction_listener_registry.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/events/event_contexts.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/utils/workflow_call.dart';
import 'package:bot_creator_shared/utils/global.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/actions/handler.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';

Future<void> _safeInteractionRespond(
  Interaction interaction,
  String text,
) async {
  try {
    await (interaction as dynamic).respond(
      MessageBuilder(content: text, flags: MessageFlags.ephemeral),
    );
  } catch (_) {}
}

/// Called by the main bot event loop when a MessageComponentInteraction arrives.
/// Looks up the listener registry and if a matching workflow is found, runs it.
Future<void> handleComponentInteraction(
  NyxxGateway client,
  MessageComponentInteraction interaction,
  BotDataStore store,
  String botId,
) async {
  final customId = interaction.data.customId;
  final userId =
      interaction.user?.id.toString() ??
      interaction.member?.user?.id.toString() ??
      '';
  final fallbackChannelId = (interaction as dynamic)?.channel?.id as Snowflake?;
  final guildId = (interaction as dynamic)?.guildId as Snowflake?;
  final interactionType =
      (interaction.data.values?.isNotEmpty ?? false) ? 'select' : 'button';
  final entry = InteractionListenerRegistry.instance.getMatching(
    customId,
    ListenerMatchRequest(
      botId: botId,
      type: interactionType,
      guildId: guildId?.toString(),
      channelId: fallbackChannelId?.toString(),
      messageId: interaction.message?.id.toString(),
      userId: userId,
    ),
  );

  if (entry == null) {
    // No registered listener — let the interactionCreate event workflow handle it.
    // Do not acknowledge here; the event workflow will respond.
    return;
  }

  // Remove listener if one-shot
  if (entry.oneShot) {
    InteractionListenerRegistry.instance.removeEntry(customId, entry);
  }

  // Build variables for the workflow
  final interactionVariables = buildInteractionRuntimeVariables(interaction);
  final variables = <String, String>{
    ...await generateInteractionContextKeyValues(interaction),
    ...interactionVariables,
  };

  final values = interactionVariables['interaction.values'] ?? '';
  final clickedValue = values.isNotEmpty ? values : customId;
  variables['message.content'] = clickedValue;

  if (entry.inlineActions != null && entry.inlineActions!.isNotEmpty) {
    await runListenerInlineActions(
      client: client,
      store: store,
      botId: entry.botId,
      inlineActions: entry.inlineActions!,
      variables: variables,
      interaction: interaction,
    );
  } else {
    await runListenerWorkflow(
      client: client,
      store: store,
      botId: entry.botId,
      workflowName: entry.workflowName,
      workflowEntryPoint: entry.workflowEntryPoint,
      workflowArguments: entry.workflowArguments,
      variables: variables,
      interaction: interaction,
    );
  }
}

/// Called when a ModalSubmitInteraction arrives.
Future<void> handleModalSubmitInteraction(
  NyxxGateway client,
  ModalSubmitInteraction interaction,
  BotDataStore store,
  String botId,
) async {
  final customId = interaction.data.customId;
  final userId =
      interaction.user?.id.toString() ??
      interaction.member?.user?.id.toString() ??
      '';
  final entry = InteractionListenerRegistry.instance.getMatching(
    customId,
    ListenerMatchRequest(
      botId: botId,
      type: 'modal',
      guildId: interaction.guildId?.toString(),
      channelId: interaction.channelId?.toString(),
      messageId:
          ((interaction as dynamic).message?.id as Snowflake?)?.toString(),
      userId: userId,
    ),
  );

  if (entry == null) {
    // No registered listener — let the interactionCreate event workflow handle it.
    return;
  }

  if (entry.oneShot) {
    InteractionListenerRegistry.instance.removeEntry(customId, entry);
  }

  // Build variables: one per modal input field
  final variables = <String, String>{
    ...await generateInteractionContextKeyValues(interaction),
    ...buildInteractionRuntimeVariables(interaction),
  };

  if (entry.inlineActions != null && entry.inlineActions!.isNotEmpty) {
    await runListenerInlineActions(
      client: client,
      store: store,
      botId: entry.botId,
      inlineActions: entry.inlineActions!,
      variables: variables,
      interaction: interaction,
    );
  } else {
    await runListenerWorkflow(
      client: client,
      store: store,
      botId: entry.botId,
      workflowName: entry.workflowName,
      workflowEntryPoint: entry.workflowEntryPoint,
      workflowArguments: entry.workflowArguments,
      variables: variables,
      interaction: interaction,
    );
  }
}

/// Shared helper that executes inline callback actions.
Future<void> runListenerInlineActions({
  required NyxxGateway client,
  required BotDataStore store,
  required String botId,
  required List<Action> inlineActions,
  required Map<String, String> variables,
  Interaction? interaction,
}) async {
  try {
    variables.addAll(extractBotRuntimeDetails(client));

    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: variables,
      guildContextId: variables['interaction.guildId'],
      channelContextId: variables['interaction.channelId'],
      userContextId: variables['interaction.userId'],
      messageContextId:
          variables['messageId'] ??
          variables['message.id'] ??
          variables['interaction.messageId'],
    );

    String resolveTemplate(String input) =>
        resolveTemplatePlaceholders(input, variables);

    await handleListenerWorkflowActions(
      client,
      actions: inlineActions,
      store: store,
      botId: botId,
      variables: variables,
      resolveTemplate: resolveTemplate,
      interaction: interaction,
    );
  } catch (e) {
    if (interaction != null) {
      await _safeInteractionRespond(
        interaction,
        'An internal error prevented this interaction from completing.',
      );
    }
  }
}

/// Shared helper that loads and executes a saved workflow with injected variables.
Future<void> runListenerWorkflow({
  required NyxxGateway client,
  required BotDataStore store,
  required String botId,
  required String workflowName,
  required String workflowEntryPoint,
  required Map<String, String> workflowArguments,
  required Map<String, String> variables,
  Interaction? interaction,
}) async {
  try {
    final workflow = await store.getWorkflowByName(botId, workflowName);
    if (workflow == null) {
      if (interaction != null) {
        await _safeInteractionRespond(
          interaction,
          'Workflow not found for this interaction. Please try again later.',
        );
      }
      return;
    }

    variables.addAll(extractBotRuntimeDetails(client));

    await hydrateRuntimeVariables(
      store: store,
      botId: botId,
      runtimeVariables: variables,
      guildContextId: variables['interaction.guildId'],
      channelContextId: variables['interaction.channelId'],
      userContextId: variables['interaction.userId'],
      messageContextId:
          variables['messageId'] ??
          variables['message.id'] ??
          variables['interaction.messageId'],
    );

    final effectiveEntryPoint = normalizeWorkflowEntryPoint(
      workflowEntryPoint,
      fallback: normalizeWorkflowEntryPoint(workflow['entryPoint']),
    );
    final argDefinitions = parseWorkflowArgumentDefinitions(
      workflow['arguments'],
    );
    applyWorkflowInvocationContext(
      variables: variables,
      workflowName: workflowName,
      entryPoint: effectiveEntryPoint,
      definitions: argDefinitions,
      providedArguments: workflowArguments,
    );

    final actions = List<Action>.from(
      ((workflow['actions'] as List?) ?? const <dynamic>[])
          .whereType<Map>()
          .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
    );

    String resolveTemplate(String input) =>
        resolveTemplatePlaceholders(input, variables);

    await handleListenerWorkflowActions(
      client,
      actions: actions,
      store: store,
      botId: botId,
      variables: variables,
      resolveTemplate: resolveTemplate,
      interaction: interaction,
    );

    // 3. Send final response (text, embeds, components, modal)
    // Configure response details from workflow JSON
    final response = Map<String, dynamic>.from(
      (workflow['response'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    if (interaction != null) {
      final isEphemeral =
          workflow['visibility']?.toString().toLowerCase() == 'ephemeral';

      await sendWorkflowResponse(
        interaction: interaction,
        response: response,
        runtimeVariables: variables,
        botId: botId,
        isEphemeral: isEphemeral,
        // didDefer is false here because we removed the blind acknowledge()
        didDefer: false,
      );
    }
  } catch (e) {
    if (interaction != null) {
      await _safeInteractionRespond(
        interaction,
        'An internal error prevented this interaction from completing.',
      );
    }
  }
}
