import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/actions/handler.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';
import 'package:bot_creator_shared/engine/discord_entity_fetcher.dart';

/// Helper to execute visual workflows or BDFD actions for both interactions and events.
class WorkflowExecutor {
  WorkflowExecutor({
    required this.store,
    required this.callbacks,
  });

  final BotDataStore store;
  final BotEngineCallbacks callbacks;

  /// Executes a list of actions for a given context.
  Future<Map<String, String>> executeActions({
    required List<Action> actions,
    required dynamic context, // Interaction or MessageCreateEvent, etc.
    required NyxxGateway gateway,
    required String botId,
    required Map<String, String> runtimeVariables,
  }) async {
    if (actions.isEmpty) return const {};

    await hydrateActionPlaceholders(
      store: store,
      botId: botId,
      actions: actions,
      variables: runtimeVariables,
      discordFetcher: (scope, contextId, vars) =>
          DiscordEntityFetcher.hydrateEntity(gateway, scope, contextId, vars),
    );

    try {
      final results = await handleActions(
        gateway,
        context,
        actions: actions,
        store: store,
        botId: botId,
        variables: runtimeVariables,
        resolveTemplate: (input) =>
            resolveTemplatePlaceholders(input, runtimeVariables),
        onLog: (msg) => callbacks.onLog?.call(msg, botId: botId),
      );
      return results;
    } catch (e, st) {
      callbacks.onDebugLog?.call('Action execution failed: $e\n$st', botId: botId);
      rethrow;
    }
  }

  /// Executes a full visual workflow (actions + response).
  Future<void> executeVisualWorkflow(
    Map<String, dynamic> workflowData, {
    required Interaction interaction,
    required NyxxGateway gateway,
    required String botId,
    required Map<String, String> runtimeVariables,
  }) async {
    final response = Map<String, dynamic>.from(
      (workflowData["response"] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    final workflow = Map<String, dynamic>.from(
      (response['workflow'] as Map?)?.cast<String, dynamic>() ?? const {},
    );

    var actionsJson = List<Map<String, dynamic>>.from(
      (workflowData["actions"] as List?)?.whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ) ??
          const [],
    );

    // Load saved workflow if needed
    final workflowName = (workflow['name'] ?? '').toString().trim();
    if (workflowName.isNotEmpty && actionsJson.isEmpty) {
      final savedWorkflow = await store.getWorkflowByName(botId, workflowName);
      if (savedWorkflow != null) {
        actionsJson = List<Map<String, dynamic>>.from(
          (savedWorkflow['actions'] as List?)?.whereType<Map>().map(
                (e) => Map<String, dynamic>.from(e),
              ) ??
              const [],
        );
      }
    }

    final actions = actionsJson.map(Action.fromJson).toList();
    
    // Defer if needed
    final isEphemeral = workflow['visibility']?.toString().toLowerCase() == 'ephemeral';
    final shouldDefer = actions.isNotEmpty && workflow['autoDeferIfActions'] != false;
    var didDefer = false;

    if (shouldDefer) {
      try {
        await (interaction as dynamic).acknowledge(isEphemeral: isEphemeral);
      } catch (_) {}
      didDefer = true;
    }

    if (actions.isNotEmpty) {
      final results = await executeActions(
        actions: actions,
        context: interaction,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
      );
      for (final entry in results.entries) {
        runtimeVariables['action.${entry.key}'] = entry.value;
      }
    }

    await sendWorkflowResponse(
      interaction: interaction,
      response: response,
      runtimeVariables: runtimeVariables,
      botId: botId,
      didDefer: didDefer,
      isEphemeral: isEphemeral,
      onLog: (msg, {required botId}) async => callbacks.onLog?.call(msg, botId: botId),
      onDebugLog: (msg, {required botId}) async => callbacks.onDebugLog?.call(msg, botId: botId),
    );
  }

  Future<void> executeGeneralWorkflow({
    required Map<String, dynamic> workflowData,
    required NyxxGateway gateway,
    required String botId,
    required Map<String, String> runtimeVariables,
    String? replayLabel,
  }) async {
    final actionsJson = List<Map<String, dynamic>>.from(
      (workflowData["actions"] as List?)?.whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ) ??
          const [],
    );

    if (actionsJson.isEmpty) return;

    final actions = actionsJson.map(Action.fromJson).toList();

    await executeActions(
      actions: actions,
      context: null,
      gateway: gateway,
      botId: botId,
      runtimeVariables: runtimeVariables,
    );
  }
}
