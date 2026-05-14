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
    Snowflake? fallbackChannelId,
    Snowflake? fallbackGuildId,
  }) async {
    callbacks.onDebugLog?.call(
      'executeActions started with ${actions.length} actions',
      botId: botId,
    );
    
    if (actions.isEmpty) {
      callbacks.onDebugLog?.call(
        'No actions to execute, returning empty results',
        botId: botId,
      );
      return const {};
    }

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
        context is Interaction ? context : null,
        actions: actions,
        store: store,
        botId: botId,
        variables: runtimeVariables,
        resolveTemplate: (input) =>
            resolveTemplatePlaceholders(input, runtimeVariables),
        onLog: (msg) => callbacks.onLog?.call(msg, botId: botId),
        fallbackChannelId: fallbackChannelId,
        fallbackGuildId: fallbackGuildId,
      );
      
      callbacks.onDebugLog?.call(
        'handleActions completed with ${results.length} results: $results',
        botId: botId,
      );
      
      return results;
    } catch (e, st) {
      callbacks.onDebugLog?.call('Action execution failed: $e\n$st', botId: botId);
      callbacks.onLog?.call(
        'ERROR: Action execution failed: $e',
        botId: botId,
      );
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
    callbacks.onDebugLog?.call(
      'executeVisualWorkflow started',
      botId: botId,
    );
    
    final response = Map<String, dynamic>.from(
      (workflowData["response"] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    callbacks.onDebugLog?.call(
      'Response data in executeVisualWorkflow: $response',
      botId: botId,
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
    callbacks.onDebugLog?.call(
      'Parsed ${actions.length} actions for visual workflow',
      botId: botId,
    );
    
    // Defer if needed
    final isEphemeral = workflow['visibility']?.toString().toLowerCase() == 'ephemeral';
    final shouldDefer = actions.isNotEmpty && workflow['autoDeferIfActions'] != false;
    var didDefer = false;

    if (shouldDefer) {
      callbacks.onDebugLog?.call(
        'Attempting to defer interaction',
        botId: botId,
      );
      try {
        await (interaction as dynamic).acknowledge(isEphemeral: isEphemeral);
        callbacks.onDebugLog?.call(
          'Interaction acknowledged successfully',
          botId: botId,
        );
      } catch (e) {
        callbacks.onDebugLog?.call(
          'Failed to acknowledge interaction: $e',
          botId: botId,
        );
      }
      didDefer = true;
    }

    if (actions.isNotEmpty) {
      callbacks.onDebugLog?.call(
        'Executing ${actions.length} actions in visual workflow',
        botId: botId,
      );
      final results = await executeActions(
        actions: actions,
        context: interaction,
        gateway: gateway,
        botId: botId,
        runtimeVariables: runtimeVariables,
      );
      callbacks.onDebugLog?.call(
        'Action execution results: $results',
        botId: botId,
      );
      for (final entry in results.entries) {
        runtimeVariables['action.${entry.key}'] = entry.value;
      }
    }

    await sendWorkflowResponse(
      interaction: interaction,
      gateway: gateway,
      response: response,
      runtimeVariables: runtimeVariables,
      botId: botId,
      didDefer: didDefer,
      isEphemeral: isEphemeral,
      onLog: (msg, {required botId}) async => callbacks.onLog?.call(msg, botId: botId),
      onDebugLog: (msg, {required botId}) async => callbacks.onDebugLog?.call(msg, botId: botId),
    );
    
    callbacks.onDebugLog?.call(
      'executeVisualWorkflow completed',
      botId: botId,
    );
  }

  Future<void> executeGeneralWorkflow({
    required Map<String, dynamic> workflowData,
    required NyxxGateway gateway,
    required String botId,
    required Map<String, String> runtimeVariables,
    String? replayLabel,
  }) async {
    callbacks.onDebugLog?.call(
      'executeGeneralWorkflow started',
      botId: botId,
    );
    
    final actionsJson = List<Map<String, dynamic>>.from(
      (workflowData["actions"] as List?)?.whereType<Map>().map(
            (e) => Map<String, dynamic>.from(e),
          ) ??
          const [],
    );

    if (actionsJson.isEmpty) {
      callbacks.onDebugLog?.call(
        'No actions in general workflow, returning early',
        botId: botId,
      );
      return;
    }

    final actions = actionsJson.map(Action.fromJson).toList();
    callbacks.onDebugLog?.call(
      'Executing ${actions.length} actions in general workflow',
      botId: botId,
    );

    await executeActions(
      actions: actions,
      context: null,
      gateway: gateway,
      botId: botId,
      runtimeVariables: runtimeVariables,
    );
    
    callbacks.onDebugLog?.call(
      'executeGeneralWorkflow completed',
      botId: botId,
    );
  }
}