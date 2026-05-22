import 'dart:async';
import 'package:nyxx/nyxx.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/actions/handler.dart';
import 'package:bot_creator_shared/actions/interaction_response.dart';
import 'package:bot_creator_shared/types/action.dart';
import 'package:bot_creator_shared/utils/template_resolver.dart';
import 'package:bot_creator_shared/utils/bdfd_compiler.dart';
import 'package:bot_creator_shared/engine/bot_engine_callbacks.dart';

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
    String? replayLabel,
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

    try {
      final isCapturing = callbacks.isDebugReplayCapturing?.call(botId) ?? false;

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
        onReplayCaptured: isCapturing
            ? (frames, totalMs) {
                String label = replayLabel ?? '';
                if (label.isEmpty) {
                  // Fix 2: Restrict to ApplicationCommandInteraction to avoid NoSuchMethodError
                  if (context is ApplicationCommandInteraction) {
                    label = '/${context.data.name}';
                  } else if (runtimeVariables.containsKey('0')) {
                    label = '!${runtimeVariables['0']}';
                  } else {
                    label = 'Workflow';
                  }
                }
                callbacks.onReplayCaptured?.call(botId, label, frames, totalMs);
              }
            : null,
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
    
    // Fix 1: Safe cast for response (avoid TypeError if not a Map)
    final rawResponse = workflowData["response"];
    final response = rawResponse is Map
        ? Map<String, dynamic>.from(rawResponse.cast<String, dynamic>())
        : <String, dynamic>{};
    callbacks.onDebugLog?.call(
      'Response data in executeVisualWorkflow: $response',
      botId: botId,
    );
    
    // Fix 1: Safe cast for workflow sub-map
    final rawWorkflow = response['workflow'];
    final workflow = rawWorkflow is Map
        ? Map<String, dynamic>.from(rawWorkflow.cast<String, dynamic>())
        : <String, dynamic>{};

    // Fix 1: Safe cast for actions list
    final rawActions = workflowData["actions"];
    var actionsJson = rawActions is List
        ? List<Map<String, dynamic>>.from(
            rawActions.whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ),
          )
        : const <Map<String, dynamic>>[];

    // Load saved workflow if needed
    final workflowName = (workflow['name'] ?? '').toString().trim();
    if (workflowName.isNotEmpty && actionsJson.isEmpty) {
      final savedWorkflow = await store.getWorkflowByName(botId, workflowName);
      if (savedWorkflow != null) {
        // Fix 1: Safe cast for saved workflow actions
        final savedRawActions = savedWorkflow['actions'];
        actionsJson = savedRawActions is List
            ? List<Map<String, dynamic>>.from(
                savedRawActions.whereType<Map>().map(
                      (e) => Map<String, dynamic>.from(e),
                    ),
              )
            : const <Map<String, dynamic>>[];
      }
    }

    var actions = actionsJson.map(Action.fromJson).toList();
    actions = _transpileVisualActions(actions);
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
        // Fix 3: only set didDefer on success
        didDefer = true;
        callbacks.onDebugLog?.call(
          'Interaction acknowledged successfully',
          botId: botId,
        );
      } catch (e) {
        callbacks.onDebugLog?.call(
          'Failed to acknowledge interaction: $e',
          botId: botId,
        );
        // didDefer remains false, correct fallback in sendWorkflowResponse
      }
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
        replayLabel: workflowName.isNotEmpty
            ? workflowName
            : (interaction is ApplicationCommandInteraction
                ? '/${interaction.data.name}'
                : 'Slash Command'),
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
    
    // Fix 5: Safe cast for actions list
    final rawActions = workflowData["actions"];
    final actionsJson = rawActions is List
        ? List<Map<String, dynamic>>.from(
            rawActions.whereType<Map>().map(
                  (e) => Map<String, dynamic>.from(e),
                ),
          )
        : const <Map<String, dynamic>>[];

    if (actionsJson.isEmpty) {
      callbacks.onDebugLog?.call(
        'No actions in general workflow, returning early',
        botId: botId,
      );
      return;
    }

    var actions = actionsJson.map(Action.fromJson).toList();
    actions = _transpileVisualActions(actions);
    
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
      replayLabel: replayLabel ?? (workflowData['name'] ?? '').toString(),
    );
    
    callbacks.onDebugLog?.call(
      'executeGeneralWorkflow completed',
      botId: botId,
    );
  }

  /// Helper to transpile any inline BDFD syntax found in visual workflow action payloads.
  List<Action> _transpileVisualActions(List<Action> actions) {
    dynamic processValue(dynamic value) {
      if (value is String) {
        if (value.contains(r'$')) {
          // It might contain BDFD inline functions
          final compileResult = BdfdCompiler().compile(value);
          // If the compilation produced a single action that is just appending text,
          // we can replace the value with the transpiled text (which now has placeholders).
          // Action type 'sendMessage' with 'content' is the default for raw text in our compiler.
          if (!compileResult.hasErrors && compileResult.actions.isNotEmpty) {
             final firstAction = compileResult.actions.first;
             if ((firstAction.type == BotCreatorActionType.sendMessage ||
                  firstAction.type == BotCreatorActionType.respondWithMessage) && 
                 firstAction.payload.containsKey('content') &&
                 compileResult.actions.length == 1) {
                // Fix 4: guard against null content
                final compiledContent = firstAction.payload['content'];
                if (compiledContent != null) {
                  return compiledContent;
                }
             }
          }
        }
        return value;
      } else if (value is Map) {
        return Map<String, dynamic>.from(
          value.map((k, v) => MapEntry(k.toString(), processValue(v))),
        );
      } else if (value is List) {
        return value.map((item) => processValue(item)).toList();
      }
      return value;
    }

    return actions.map((action) {
      final newPayload = processValue(action.payload);
      return Action(
        type: action.type,
        payload: Map<String, dynamic>.from(newPayload as Map),
      );
    }).toList();
  }
}
