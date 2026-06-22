import 'dart:convert';

import 'package:bot_creator_shared/actions/pin_message.dart';
import 'package:bot_creator_shared/actions/update_automod.dart';
import 'package:bot_creator_shared/actions/update_guild.dart';
import 'package:bot_creator_shared/actions/list_members.dart';
import 'package:bot_creator_shared/actions/get_member.dart';
import 'package:bot_creator_shared/actions/unpin_message.dart';
import 'package:bot_creator_shared/actions/poll_management.dart';
import 'package:bot_creator_shared/actions/invite_management.dart';
import 'package:bot_creator_shared/actions/voice_management.dart';
import 'package:bot_creator_shared/actions/emoji_management.dart';
import 'package:bot_creator_shared/actions/automod_management.dart';
import 'package:bot_creator_shared/actions/guild_onboarding.dart';
import 'package:bot_creator_shared/actions/update_self_user.dart';
import 'package:bot_creator_shared/actions/thread_management.dart';
import 'package:bot_creator_shared/actions/channel_permissions.dart';
import 'package:bot_creator_shared/actions/register_guild_commands.dart';
import 'package:bot_creator_shared/actions/unregister_guild_commands.dart';
import 'package:bot_creator_shared/actions/send_message.dart';
import 'package:bot_creator_shared/actions/permission_checks.dart';
import 'package:bot_creator_shared/actions/executors/messaging_executor.dart';
import 'package:bot_creator_shared/actions/executors/moderation_roles_executor.dart';
import 'package:bot_creator_shared/actions/executors/reactions_executor.dart';
import 'package:bot_creator_shared/actions/executors/channels_executor.dart';
import 'package:bot_creator_shared/actions/executors/calculate_executor.dart';
import 'package:bot_creator_shared/actions/executors/components_interactions_executor.dart';
import 'package:bot_creator_shared/actions/executors/control_flow_executor.dart';
import 'package:bot_creator_shared/actions/executors/http_executor.dart';
import 'package:bot_creator_shared/actions/executors/variables_executor.dart';
import 'package:bot_creator_shared/actions/executors/webhooks_executor.dart';
import 'package:bot_creator_shared/actions/executors/lavalink_executor.dart';
import 'package:bot_creator_shared/services/lavalink_service.dart';
import 'package:bot_creator_shared/bot/bot_data_store.dart';
import 'package:bot_creator_shared/utils/runtime_variables.dart';
import 'package:bot_creator_shared/engine/discord_entity_fetcher.dart';
import 'package:nyxx/nyxx.dart';
import '../types/action.dart';

// Helper functions for common action patterns

Snowflake? _resolveSnowflake(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final parsed = int.tryParse(value.trim());
  return parsed != null ? Snowflake(parsed) : null;
}

Future<Map<String, String>> handleActions(
  NyxxGateway client,
  Interaction? interaction, {
  required List<Action> actions,
  required BotDataStore store,
  required String botId,
  required Map<String, String> variables,
  required String Function(String input) resolveTemplate,
  Snowflake? fallbackChannelId,
  Snowflake? fallbackGuildId,
  Set<String>? workflowStack,
  void Function(String message)? onLog,

  /// When provided, every executed action is captured and [onReplayCaptured]
  /// is called at the end of execution with the full frame list and total ms.
  /// This is independent of the $debug embed — both can be active at once.
  void Function(List<Map<String, dynamic>> frames, int totalMs)?
  onReplayCaptured,

  /// When provided, applied to actions before each nested execution triggered
  /// by [runBdfdScript] or [runWorkflow]. Used by Legacy command handlers to
  /// adapt interaction-oriented actions (e.g. respondWithMessage → sendMessage)
  /// for messageCreate context.
  List<Action> Function(List<Action>)? nestedActionsPreprocessor,

  /// When provided, caches Discord entities fetched during hydration to avoid
  /// redundant network calls across nested executions (loops, scripts, etc).
  Map<String, dynamic>? entityCache,

  /// When provided, tracks which Action objects have already been scanned for
  /// placeholders in this session to avoid redundant regex processing.
  Set<dynamic>? hydratedActions,

  /// When provided, enables Lavalink music actions (playMusic, pauseMusic, etc).
  LavalinkService? lavalinkService,
}) async {
  final results = <String, String>{};
  final resolvedFallbackChannelId =
      fallbackChannelId ?? (interaction as dynamic)?.channel?.id as Snowflake?;
  final guildId =
      fallbackGuildId ?? (interaction as dynamic)?.guildId as Snowflake?;
  final activeWorkflowStack = workflowStack ?? <String>{};
  final activeEntityCache = entityCache ?? <String, dynamic>{};
  final activeHydratedActions = hydratedActions ?? <dynamic>{};

  // Ensure all actions (including potential nested ones) have their placeholders hydrated.
  await hydrateActionPlaceholders(
    store: store,
    botId: botId,
    actions: actions,
    variables: variables,
    discordFetcher: (scope, contextId, vars) async {
      await DiscordEntityFetcher.hydrateEntity(
        client,
        scope,
        contextId,
        vars,
        cache: activeEntityCache,
      );
    },
    hydratedActions: activeHydratedActions,
  );

  String resolveValue(String value) {
    // Try template resolution first (variables, interaction context, etc.)
    String result = resolveTemplate(value);

    // Fall back to local action results for any remaining ((...)) patterns.
    // Uses replaceAllMapped instead of anchored ^...$ regex so mixed content
    // like "ID: ((action_0.emojiId)) | Name: ((action_0.name))" is resolved.
    // Results are keyed by action.key (e.g. 'translation', 'action_0.emojiId'),
    // but placeholders may use 'action.<key>' format — strip the prefix.
    result = result.replaceAllMapped(
      RegExp(r'\(\(([^)]+)\)\)'),
      (match) {
        var key = match.group(1)!;
        // Direct match (e.g. legacy action_message style, or action_0.emojiId)
        if (results.containsKey(key)) {
          return results[key]!;
        }
        // Strip 'action.' prefix to match results keyed by action.key
        if (key.startsWith('action.')) {
          final stripped = key.substring('action.'.length);
          if (results.containsKey(stripped)) {
            return results[stripped]!;
          }
        }
        return match.group(0)!; // Keep original if not found
      },
    );

    return result;
  }


  // Permission cache – shared across all actions in this execution
  final permCache = BotPermissionCache();

  // Debug profiling state
  Stopwatch? debugStopwatch;
  List<_DebugTraceEntry>? debugTrace;
  int? debugCompilationMs;
  int? debugSourceLength;
  int? debugActionCount;

  // Replay capture state (independent of $debug embed)
  Stopwatch? replayStopwatch;
  List<_DebugTraceEntry>? replayTrace;
  if (onReplayCaptured != null) {
    replayStopwatch = Stopwatch()..start();
    replayTrace = <_DebugTraceEntry>[];
  }

  // Execution timer for ((execution.time)) resolution.
  final executionStopwatch = Stopwatch()..start();

  Action? currentAction;
  String? currentResultKey;
  int? currentReplayStartMs;
  Map<String, String>? currentVarSnapshotBefore;

  try {
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      final resultKey = action.key ?? 'action_$i';
      currentAction = action;
      currentResultKey = resultKey;
      currentReplayStartMs = replayStopwatch?.elapsedMilliseconds ?? 0;
      currentVarSnapshotBefore = replayTrace != null ? _snapshotVariables(variables) : null;
      if (!action.enabled) {
        continue;
      }

    // Update execution.time before each action so templates pick up the
    // elapsed time since command execution started.
    variables['execution.time'] = '${executionStopwatch.elapsedMilliseconds}ms';

    // Start debug profiling when debugProfile action is encountered
    if (action.type == BotCreatorActionType.debugProfile) {
      debugStopwatch = Stopwatch()..start();
      debugTrace = <_DebugTraceEntry>[];
      debugCompilationMs = action.payload['compilationMs'] as int?;
      debugSourceLength = action.payload['sourceLength'] as int?;
      debugActionCount = action.payload['actionCount'] as int?;
      continue;
    }

    // Record timing before executing the action
    final int? traceStartMs = debugStopwatch?.elapsedMilliseconds;
    final int replayStartMs = replayStopwatch?.elapsedMilliseconds ?? 0;

    // Capture variable snapshot before execution for replay.
    final Map<String, String>? varSnapshotBefore =
        replayTrace != null ? _snapshotVariables(variables) : null;

    void recordTrace({String? resultOverride}) {
      final traceResult = resultOverride ?? results[resultKey];
      if (traceResult != null &&
          RegExp(r'^\d+$').hasMatch(traceResult) &&
          !traceResult.startsWith('Error:')) {
        variables['lastSentMessageId'] = traceResult;
        variables['lastMessageId'] = traceResult;
      }
      final loopDepth = action.payload['_debugLoopDepth'] as int?;
      final loopIteration = action.payload['_debugLoopIteration'] as int?;
      final Map<String, String>? varSnapshotAfter =
          replayTrace != null ? _snapshotVariables(variables) : null;
      debugTrace?.add(
        _DebugTraceEntry(
          actionType: action.type.name,
          startMs: traceStartMs ?? 0,
          endMs: debugStopwatch?.elapsedMilliseconds ?? 0,
          result: traceResult,
          loopDepth: loopDepth,
          loopIteration: loopIteration,
        ),
      );
      replayTrace?.add(
        _DebugTraceEntry(
          actionType: action.type.name,
          startMs: replayStartMs,
          endMs: replayStopwatch?.elapsedMilliseconds ?? 0,
          result: traceResult,
          loopDepth: loopDepth,
          loopIteration: loopIteration,
          variablesBefore: varSnapshotBefore,
          variablesAfter: varSnapshotAfter,
        ),
      );
    }

    final handledByMessagingExecutor = await executeMessagingAction(
      type: action.type,
      client: client,
      interaction: interaction,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      botId: botId,
      guildId: guildId,
      fallbackChannelId: resolvedFallbackChannelId,
      resolveValue: resolveValue,
      permissionCache: permCache,
    );
    if (handledByMessagingExecutor) {
      recordTrace();
      continue;
    }

    final handledByReactionsExecutor = await executeReactionsAction(
      type: action.type,
      client: client,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      fallbackChannelId: resolvedFallbackChannelId,
      guildId: guildId,
      resolveValue: resolveValue,
      permissionCache: permCache,
    );
    if (handledByReactionsExecutor) {
      recordTrace();
      continue;
    }

    final handledByModerationRolesExecutor = await executeModerationRolesAction(
      type: action.type,
      client: client,
      guildId: guildId,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      resolveValue: resolveValue,
    );
    if (handledByModerationRolesExecutor) {
      recordTrace();
      continue;
    }

    final handledByChannelsExecutor = await executeChannelsAction(
      type: action.type,
      client: client,
      guildId: guildId,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      resolveValue: resolveValue,
      permissionCache: permCache,
    );
    if (handledByChannelsExecutor) {
      recordTrace();
      continue;
    }

    final handledByWebhooksExecutor = await executeWebhooksAction(
      type: action.type,
      client: client,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      fallbackChannelId: fallbackChannelId,
      fallbackGuildId: guildId,
      resolveValue: resolveValue,
      permissionCache: permCache,
    );
    if (handledByWebhooksExecutor) {
      recordTrace();
      continue;
    }

    // Lavalink music actions
    if (lavalinkService != null &&
        (action.type == BotCreatorActionType.playMusic || action.type == BotCreatorActionType.joinVoice)) {
      // Auto-inject userId for voice channel resolution if both fields are missing or empty
      final payloadUserId = action.payload['userId']?.toString().trim();
      final payloadChannelId = action.payload['channelId']?.toString().trim();
      if ((payloadUserId == null || payloadUserId.isEmpty) &&
          (payloadChannelId == null || payloadChannelId.isEmpty)) {
        final userId = interaction?.user?.id.toString() ?? variables['userId'];
        if (userId != null && userId.isNotEmpty) {
          action.payload['userId'] = userId;
          onLog?.call('Lavalink: auto-injected userId=$userId for action ${action.type.name}');
        } else {
          onLog?.call('Lavalink: could not resolve userId — interaction=${interaction != null}, userId=${variables['userId']}');
        }
      }
    }

    if (lavalinkService != null) {
      // Resolve templates in action payload before execution
      final resolvedPayload = <String, dynamic>{};
      for (final entry in action.payload.entries) {
        if (entry.value is String) {
          resolvedPayload[entry.key] = resolveValue(entry.value as String);
        } else {
          resolvedPayload[entry.key] = entry.value;
        }
      }

      final lavalinkHandled = await executeLavalinkAction(
        type: action.type,
        client: client,
        guildId: guildId!,
        payload: resolvedPayload,
        results: results,
        resultKey: resultKey,
        lavalinkService: lavalinkService,
      );
      if (lavalinkHandled) {
        results[resultKey] = results[resultKey] ?? '';
        recordTrace();
        continue;
      }
    }

    final handledByComponentsInteractionsExecutor =
        await executeComponentsInteractionsAction(
          type: action.type,
          client: client,
          interaction: interaction,
          payload: action.payload,
          resultKey: resultKey,
          results: results,
          variables: variables,
          botId: botId,
          guildId: guildId,
          fallbackChannelId: fallbackChannelId,
          fallbackMessageId: _resolveSnowflake(
            variables['message.id'] ?? variables['messageId'],
          ),
          resolveValue: resolveValue,
          store: store,
          lavalinkService: lavalinkService,
        );
    if (handledByComponentsInteractionsExecutor) {
      recordTrace();
      continue;
    }

    final handledByVariablesExecutor = await executeVariablesAction(
      type: action.type,
      store: store,
      botId: botId,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      resolveValue: resolveValue,
      guildId: guildId,
      fallbackChannelId: fallbackChannelId,
      interaction: interaction,
      onLog: onLog,
    );
    if (handledByVariablesExecutor) {
      recordTrace();
      if (results.containsKey('__stopped__')) {
        return results;
      }
      continue;
    }

    final handledByControlFlowExecutor = await executeControlFlowAction(
      type: action.type,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      botId: botId,
      resolveValue: resolveValue,
      onLog: onLog,
      activeWorkflowStack: activeWorkflowStack,
      getWorkflowByName:
          (workflowName) => store.getWorkflowByName(botId, workflowName),
      nestedActionsPreprocessor: nestedActionsPreprocessor,
      getScopedVariableTtl:
          (scope, key) async => await store.getScopedVariableTtl(
            botId,
            scope,
            resolveScopeContextId(
              scope: scope,
              variables: variables,
              interaction: interaction,
              guildId: guildId,
              channelId: resolvedFallbackChannelId,
            ) ??
            '',
            key,
          ),
      executeActions:
          (nestedActions) => handleActions(
            client,
            interaction,
            actions: nestedActions,
            store: store,
            botId: botId,
            variables: variables,
            resolveTemplate: resolveTemplate,
            fallbackChannelId: resolvedFallbackChannelId,
            fallbackGuildId: guildId,
            workflowStack: activeWorkflowStack,
            onLog: onLog,
            nestedActionsPreprocessor: nestedActionsPreprocessor,
            entityCache: activeEntityCache,
            hydratedActions: activeHydratedActions,
          ),
    );
    if (handledByControlFlowExecutor) {
      recordTrace();
      if (results.containsKey('__stopped__')) {
        return results;
      }
      if (results.containsKey('__skipCount__')) {
        final count =
            int.tryParse(results.remove('__skipCount__')!) ?? 0;
        if (count > 0) {
          i += count;
        }
        continue;
      }
      if (results.containsKey('__jumpToTargetKey__')) {
        final targetKey = results.remove('__jumpToTargetKey__')!;
        // Match by action key, action ID, or 1-indexed position
        final targetIndex = actions.indexWhere(
          (a) =>
              (a.key != null && a.key == targetKey) ||
              a.payload['_actionId'] == targetKey,
        );
        if (targetIndex < 0) {
          final indexNum = int.tryParse(targetKey);
          if (indexNum != null && indexNum >= 1 && indexNum <= actions.length) {
            i = indexNum - 2; // -1 for 0-based, -1 because loop increments
          }
        } else if (targetIndex > i) {
          i = targetIndex - 1; // -1 because loop increments
        }
        continue;
      }
      continue;
    }

    final handledByHttpExecutor = await executeHttpAction(
      type: action.type,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      resolveValue: resolveValue,
      onLog: onLog,
      setGlobalVariable:
          (key, value) => store.setGlobalVariable(botId, key, value),
    );
    if (handledByHttpExecutor) {
      recordTrace();
      continue;
    }

    final handledByCalculateExecutor = await executeCalculateAction(
      type: action.type,
      payload: action.payload,
      resultKey: resultKey,
      results: results,
      variables: variables,
      resolveValue: resolveValue,
    );
    if (handledByCalculateExecutor) {
      recordTrace();
      continue;
    }

    try {
      switch (action.type) {
        case BotCreatorActionType.deleteMessages:
        case BotCreatorActionType.createChannel:
        case BotCreatorActionType.updateChannel:
        case BotCreatorActionType.removeChannel:
        case BotCreatorActionType.sendMessage:
        case BotCreatorActionType.editMessage:
        case BotCreatorActionType.getMessage:
        case BotCreatorActionType.addReaction:
        case BotCreatorActionType.removeReaction:
        case BotCreatorActionType.clearAllReactions:
        case BotCreatorActionType.banUser:
        case BotCreatorActionType.unbanUser:
        case BotCreatorActionType.kickUser:
        case BotCreatorActionType.muteUser:
        case BotCreatorActionType.unmuteUser:
        case BotCreatorActionType.addRole:
        case BotCreatorActionType.removeRole:
        case BotCreatorActionType.sendWebhook:
        case BotCreatorActionType.editWebhook:
        case BotCreatorActionType.deleteWebhook:
        case BotCreatorActionType.listWebhooks:
        case BotCreatorActionType.getWebhook:
        case BotCreatorActionType.sendComponentV2:
        case BotCreatorActionType.editComponentV2:
        case BotCreatorActionType.respondWithComponentV2:
        case BotCreatorActionType.respondWithMessage:
        case BotCreatorActionType.respondWithModal:
        case BotCreatorActionType.editInteractionMessage:
        case BotCreatorActionType.listenForButtonClick:
        case BotCreatorActionType.listenForSelectMenu:
        case BotCreatorActionType.listenForModalSubmit:
        case BotCreatorActionType.listenAndExecute:
        case BotCreatorActionType.setScopedVariable:
        case BotCreatorActionType.getScopedVariable:
        case BotCreatorActionType.removeScopedVariable:
        case BotCreatorActionType.renameScopedVariable:
        case BotCreatorActionType.listScopedVariableIndex:
        case BotCreatorActionType.appendArrayElement:
        case BotCreatorActionType.removeArrayElement:
        case BotCreatorActionType.queryArray:
        case BotCreatorActionType.setGlobalVariable:
        case BotCreatorActionType.getGlobalVariable:
        case BotCreatorActionType.removeGlobalVariable:
        case BotCreatorActionType.respondWithAutocomplete:
        case BotCreatorActionType.httpRequest:
        case BotCreatorActionType.runWorkflow:
        case BotCreatorActionType.runBdfdScript:
        case BotCreatorActionType.stopUnless:
        case BotCreatorActionType.ifBlock:
        case BotCreatorActionType.forLoop:
        case BotCreatorActionType.cooldown:
        case BotCreatorActionType.calculate:
        case BotCreatorActionType.debugProfile:
        case BotCreatorActionType.log:
        case BotCreatorActionType.runtimeJsonBlock:
        case BotCreatorActionType.runtimeImageBlock:
        case BotCreatorActionType.attachImage:
        case BotCreatorActionType.canvasCreateBlock:
        case BotCreatorActionType.canvasLoadImageBlock:
        case BotCreatorActionType.canvasDrawTextBlock:
        case BotCreatorActionType.canvasDrawCircleBlock:
        case BotCreatorActionType.canvasDrawRectBlock:
        case BotCreatorActionType.canvasDrawLineBlock:
        case BotCreatorActionType.setTemporaryVariable:
        case BotCreatorActionType.jsonForEachLoop:
        case BotCreatorActionType.wait:
        case BotCreatorActionType.deleteTrigger:
        case BotCreatorActionType.sendDm:
        case BotCreatorActionType.setNickname:
        case BotCreatorActionType.slowmode:
        case BotCreatorActionType.stop:
        case BotCreatorActionType.skipActions:
        case BotCreatorActionType.jumpToAction:
        case BotCreatorActionType.randomChoice:
        case BotCreatorActionType.deferInteraction:
        case BotCreatorActionType.playMusic:
        case BotCreatorActionType.pauseMusic:
        case BotCreatorActionType.resumeMusic:
        case BotCreatorActionType.skipMusic:
        case BotCreatorActionType.stopMusic:
        case BotCreatorActionType.setMusicVolume:
        case BotCreatorActionType.setMusicLoop:
        case BotCreatorActionType.seekMusic:
        case BotCreatorActionType.getMusicInfo:
        case BotCreatorActionType.joinVoice:
        case BotCreatorActionType.leaveVoice:
          throw StateError(
            'Action ${action.type.name} should have been handled by an executor before switch dispatch.',
          );
        case BotCreatorActionType.pinMessage:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageMessages],
              actionLabel: 'pin messages',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final resolvedPinPayload = Map<String, dynamic>.from(action.payload);
          if (action.payload.containsKey('messageId')) {
            resolvedPinPayload['messageId'] = resolveValue(
              action.payload['messageId'].toString(),
            );
          }
          if (action.payload.containsKey('channelId')) {
            resolvedPinPayload['channelId'] = resolveValue(
              action.payload['channelId'].toString(),
            );
          }
          final result = await pinMessageAction(
            client,
            payload: resolvedPinPayload,
            fallbackChannelId: fallbackChannelId,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['messageId'] ?? '';
          break;
        case BotCreatorActionType.updateAutoMod:
          final resolvedPayload = Map<String, dynamic>.from(action.payload);
          if (action.payload.containsKey('ruleId')) {
            resolvedPayload['ruleId'] = resolveValue(
              action.payload['ruleId'].toString(),
            );
          }
          final result = await updateAutoModAction(
            client,
            guildId: guildId,
            payload: resolvedPayload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['status'] ?? 'OK';
          break;
        case BotCreatorActionType.updateGuild:
          final result = await updateGuildAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['guildId'] ?? '';
          break;
        case BotCreatorActionType.leaveGuild:
          final resolvedGuildId = _resolveSnowflake(
            resolveValue((action.payload['guildId'] ?? '').toString()),
          );
          final result = await updateGuildAction(
            client,
            guildId: resolvedGuildId ?? guildId,
            payload: <String, dynamic>{'leave': true},
            resolve: resolveValue,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['guildId'] ?? '';
          break;
        case BotCreatorActionType.listMembers:
          final resolvedPayload = Map<String, dynamic>.from(action.payload);
          if (action.payload.containsKey('limit')) {
            resolvedPayload['limit'] = resolveValue(
              action.payload['limit'].toString(),
            );
          }
          if (action.payload.containsKey('after')) {
            resolvedPayload['after'] = resolveValue(
              action.payload['after'].toString(),
            );
          }
          if (action.payload.containsKey('query')) {
            resolvedPayload['query'] = resolveValue(
              action.payload['query'].toString(),
            );
          }
          final result = await listMembersAction(
            client,
            guildId: guildId,
            payload: resolvedPayload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['members'] ?? '[]';
          break;
        case BotCreatorActionType.getMember:
          final resolvedPayload = Map<String, dynamic>.from(action.payload);
          if (action.payload.containsKey('userId')) {
            resolvedPayload['userId'] = resolveValue(
              action.payload['userId'].toString(),
            );
          }
          if (action.payload.containsKey('memberId')) {
            resolvedPayload['memberId'] = resolveValue(
              action.payload['memberId'].toString(),
            );
          }
          final result = await getMemberAction(
            client,
            guildId: guildId,
            payload: resolvedPayload,
          );
          if (result['error'] != null) {
            throw Exception(result['error']);
          }
          results[resultKey] = result['member'] ?? '';
          break;
        case BotCreatorActionType.unpinMessage:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageMessages],
              actionLabel: 'unpin messages',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final resolvedUnpinPayload = Map<String, dynamic>.from(action.payload);
          if (action.payload.containsKey('messageId')) {
            resolvedUnpinPayload['messageId'] = resolveValue(
              action.payload['messageId'].toString(),
            );
          }
          if (action.payload.containsKey('channelId')) {
            resolvedUnpinPayload['channelId'] = resolveValue(
              action.payload['channelId'].toString(),
            );
          }
          final unpinResult = await unpinMessageAction(
            client,
            payload: resolvedUnpinPayload,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (unpinResult['error'] != null) {
            throw Exception(unpinResult['error']);
          }
          results[resultKey] = unpinResult['status'] ?? 'unpinned';
          break;

        // ─── Polls ────────────────────────────────────────────────────────
        case BotCreatorActionType.createPoll:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.sendMessages],
              actionLabel: 'create polls',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final pollResult = await createPollAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (pollResult['error'] != null) {
            throw Exception(pollResult['error']);
          }
          results[resultKey] = pollResult['messageId'] ?? '';
          variables['$resultKey.messageId'] = pollResult['messageId'] ?? '';
          variables['$resultKey.pollId'] = pollResult['pollId'] ?? '';
          break;

        case BotCreatorActionType.endPoll:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageMessages],
              actionLabel: 'end polls',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final resolvedEndPollPayload = Map<String, dynamic>.from(action.payload);
          if (action.payload.containsKey('channelId')) {
            resolvedEndPollPayload['channelId'] = resolveValue(
              action.payload['channelId'].toString(),
            );
          }
          if (action.payload.containsKey('messageId')) {
            resolvedEndPollPayload['messageId'] = resolveValue(
              action.payload['messageId'].toString(),
            );
          }
          final endPollResult = await endPollAction(
            client,
            payload: resolvedEndPollPayload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (endPollResult['error'] != null) {
            throw Exception(endPollResult['error']);
          }
          results[resultKey] = endPollResult['status'] ?? 'ended';
          break;

        // ─── Invitations ──────────────────────────────────────────────────
        case BotCreatorActionType.createInvite:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.createInstantInvite],
              actionLabel: 'create invites',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final ciResult = await createInviteAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
            fallbackChannelId: resolvedFallbackChannelId,
          );
          if (ciResult['error'] != null) {
            throw Exception(ciResult['error']);
          }
          results[resultKey] = ciResult['inviteCode'] ?? '';
          for (final entry in ciResult.entries) {
            variables['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        case BotCreatorActionType.deleteInvite:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageChannels],
              actionLabel: 'delete invites',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final diResult = await deleteInviteAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (diResult['error'] != null) {
            throw Exception(diResult['error']);
          }
          results[resultKey] = diResult['status'] ?? 'deleted';
          break;

        case BotCreatorActionType.getInvite:
          final giResult = await getInviteAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (giResult['error'] != null) {
            throw Exception(giResult['error']);
          }
          results[resultKey] = giResult['inviteCode'] ?? '';
          for (final entry in giResult.entries) {
            variables['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        // ─── Voice management ─────────────────────────────────────────────
        case BotCreatorActionType.moveToVoiceChannel:
          final mvResult = await moveToVoiceChannelAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (mvResult['error'] != null) {
            throw Exception(mvResult['error']);
          }
          results[resultKey] = mvResult['status'] ?? 'moved';
          break;

        case BotCreatorActionType.disconnectFromVoice:
          final dvResult = await disconnectFromVoiceAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (dvResult['error'] != null) {
            throw Exception(dvResult['error']);
          }
          results[resultKey] = dvResult['status'] ?? 'disconnected';
          break;

        case BotCreatorActionType.serverMuteMember:
          final smResult = await serverMuteMemberAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (smResult['error'] != null) {
            throw Exception(smResult['error']);
          }
          results[resultKey] = smResult['status'] ?? 'muted';
          break;

        case BotCreatorActionType.serverDeafenMember:
          final sdResult = await serverDeafenMemberAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (sdResult['error'] != null) {
            throw Exception(sdResult['error']);
          }
          results[resultKey] = sdResult['status'] ?? 'deafened';
          break;

        // ─── Emoji management ─────────────────────────────────────────────
        case BotCreatorActionType.createEmoji:
          final ceResult = await createEmojiAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (ceResult['error'] != null) {
            throw Exception(ceResult['error']);
          }
          // Store full JSON as main result + individual keys as sub-results
          // so ((action_1)) returns valid JSON and ((action_1.emojiId)) works.
          results[resultKey] = jsonEncode(ceResult);
          for (final entry in ceResult.entries) {
            results['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        case BotCreatorActionType.updateEmoji:
          final ueResult = await updateEmojiAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (ueResult['error'] != null) {
            throw Exception(ueResult['error']);
          }
          results[resultKey] = jsonEncode(ueResult);
          for (final entry in ueResult.entries) {
            results['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        case BotCreatorActionType.deleteEmoji:
          final deResult = await deleteEmojiAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (deResult['error'] != null) {
            throw Exception(deResult['error']);
          }
          results[resultKey] = jsonEncode(deResult);
          for (final entry in deResult.entries) {
            results['$resultKey.${entry.key}'] = entry.value;
          }
          break;

        // ─── AutoMod management ───────────────────────────────────────────
        case BotCreatorActionType.createAutoModRule:
          final camResult = await createAutoModRuleAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (camResult['error'] != null) {
            throw Exception(camResult['error']);
          }
          results[resultKey] = camResult['ruleId'] ?? '';
          variables['$resultKey.ruleId'] = camResult['ruleId'] ?? '';
          variables['$resultKey.name'] = camResult['name'] ?? '';
          break;

        case BotCreatorActionType.deleteAutoModRule:
          final damResult = await deleteAutoModRuleAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (damResult['error'] != null) {
            throw Exception(damResult['error']);
          }
          results[resultKey] = damResult['status'] ?? 'deleted';
          break;

        case BotCreatorActionType.listAutoModRules:
          final lamResult = await listAutoModRulesAction(
            client,
            guildId: guildId,
          );
          if (lamResult['error'] != null) {
            throw Exception(lamResult['error']);
          }
          results[resultKey] = lamResult['rulesJson'] ?? '[]';
          variables['$resultKey.rulesJson'] = lamResult['rulesJson'] ?? '[]';
          variables['$resultKey.count'] = lamResult['count'] ?? '0';
          break;

        // ─── Guild Onboarding ─────────────────────────────────────────────
        case BotCreatorActionType.getGuildOnboarding:
          final goResult = await getGuildOnboardingAction(
            client,
            guildId: guildId,
          );
          if (goResult['error'] != null) {
            throw Exception(goResult['error']);
          }
          results[resultKey] = goResult['onboardingJson'] ?? '{}';
          variables['$resultKey.onboardingJson'] =
              goResult['onboardingJson'] ?? '{}';
          variables['$resultKey.enabled'] = goResult['enabled'] ?? 'false';
          break;

        case BotCreatorActionType.updateGuildOnboarding:
          final ugoResult = await updateGuildOnboardingAction(
            client,
            guildId: guildId,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (ugoResult['error'] != null) {
            throw Exception(ugoResult['error']);
          }
          results[resultKey] = ugoResult['status'] ?? 'updated';
          break;

        // ─── Self user ────────────────────────────────────────────────────
        case BotCreatorActionType.updateSelfUser:
          final suResult = await updateSelfUserAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (suResult['error'] != null) {
            throw Exception(suResult['error']);
          }
          results[resultKey] = suResult['status'] ?? 'updated';
          variables['$resultKey.username'] = suResult['username'] ?? '';
          variables['$resultKey.userId'] = suResult['userId'] ?? '';
          break;

        // ─── Guild Commands ───────────────────────────────────────────────
        case BotCreatorActionType.registerGuildCommands:
          final rgcResult = await registerGuildCommandsAction(
            client,
            botId: botId,
            store: store,
            guildId: guildId,
            payload: action.payload,
          );
          if (rgcResult['error'] != null) {
            throw Exception(rgcResult['error']);
          }
          results[resultKey] = rgcResult['registered'] ?? '0';
          break;

        case BotCreatorActionType.unregisterGuildCommands:
          final ugcResult = await unregisterGuildCommandsAction(
            client,
            botId: botId,
            store: store,
            guildId: guildId,
            payload: action.payload,
          );
          if (ugcResult['error'] != null) {
            throw Exception(ugcResult['error']);
          }
          results[resultKey] = ugcResult['unregistered'] ?? '0';
          break;

        // ─── Thread management ────────────────────────────────────────────
        case BotCreatorActionType.createThread:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.createPublicThreads],
              actionLabel: 'create threads',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final ctResult = await createThreadAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (ctResult['error'] != null) {
            throw Exception(ctResult['error']);
          }
          results[resultKey] = ctResult['threadId'] ?? '';
          variables['$resultKey.threadId'] = ctResult['threadId'] ?? '';
          variables['$resultKey.name'] = ctResult['name'] ?? '';
          variables['$resultKey.parentId'] = ctResult['parentId'] ?? '';
          variables['thread.lastId'] = ctResult['threadId'] ?? '';
          variables['thread.lastName'] = ctResult['name'] ?? '';
          break;

        case BotCreatorActionType.addThreadMember:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageThreads],
              actionLabel: 'add thread members',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final atmResult = await addThreadMemberAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (atmResult['error'] != null) {
            throw Exception(atmResult['error']);
          }
          results[resultKey] = 'ADDED';
          variables['$resultKey.threadId'] = atmResult['threadId'] ?? '';
          variables['$resultKey.userId'] = atmResult['userId'] ?? '';
          break;

        case BotCreatorActionType.removeThreadMember:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageThreads],
              actionLabel: 'remove thread members',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final rtmResult = await removeThreadMemberAction(
            client,
            payload: action.payload,
            resolve: resolveValue,
          );
          if (rtmResult['error'] != null) {
            throw Exception(rtmResult['error']);
          }
          results[resultKey] = 'REMOVED';
          variables['$resultKey.threadId'] = rtmResult['threadId'] ?? '';
          variables['$resultKey.userId'] = rtmResult['userId'] ?? '';
          break;

        // ─── Channel permissions ──────────────────────────────────────────
        case BotCreatorActionType.editChannelPermissions:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageRoles],
              actionLabel: 'edit channel permissions',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final ecpResult = await editChannelPermissionsAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (ecpResult['error'] != null) {
            throw Exception(ecpResult['error']);
          }
          results[resultKey] = ecpResult['status'] ?? 'updated';
          break;

        case BotCreatorActionType.deleteChannelPermission:
          if (guildId != null) {
            final permError = await checkBotGuildPermission(
              client,
              guildId: guildId,
              requiredPermissions: [Permissions.manageRoles],
              actionLabel: 'delete channel permissions',
              cache: permCache,
            );
            if (permError != null) throw Exception(permError);
          }
          final dcpResult = await deleteChannelPermissionAction(
            client,
            payload: action.payload,
            fallbackChannelId: resolvedFallbackChannelId,
            resolve: resolveValue,
          );
          if (dcpResult['error'] != null) {
            throw Exception(dcpResult['error']);
          }
          results[resultKey] = dcpResult['status'] ?? 'deleted';
          break;
      }
    } catch (e) {
      variables['error.message'] = e.toString();
      variables['error.command'] = action.type.name;
      variables['error.source'] = '';
      variables['error.row'] = '';
      variables['error.column'] = '';
      results[resultKey] = 'Error: $e';
      recordTrace(resultOverride: 'Error: $e');
      switch (action.onErrorMode) {
        case ActionOnErrorMode.stop:
          break; // exit loop
        case ActionOnErrorMode.jump:
          final targetId = action.jumpToActionId;
          if (targetId != null) {
            final targetIndex = actions.indexWhere(
              (a) => (a.key != null && a.key == targetId) || a.payload['_actionId'] == targetId,
            );
            if (targetIndex > i) {
              i = targetIndex - 1; // -1 because loop increments
              continue;
            }
          }
          // fall through to stop if target not found
          break;
        case ActionOnErrorMode.skip:
          final count = action.skipCount;
          if (count > 0) {
            i += count;
            continue;
          }
          break;
        case ActionOnErrorMode.continueMode:
          // continue to next action (default)
          break;
      }
    }

    // Record trace for switch-handled actions (no error)
    if ((debugTrace != null || replayTrace != null) &&
        !(results[resultKey]?.startsWith('Error:') ?? false)) {
      recordTrace();
    }
  }

  // Send debug profiling embed if $debug was used
  if (debugTrace != null && resolvedFallbackChannelId != null) {
    debugStopwatch?.stop();
    final totalMs = debugStopwatch?.elapsedMilliseconds ?? 0;
    final traceLines = <String>[];
    int? currentLoopIteration;
    for (var t = 0; t < debugTrace.length; t++) {
      final entry = debugTrace[t];
      final durationMs = entry.endMs - entry.startMs;
      final status =
          entry.result?.startsWith('Error:') == true ? '\u274c' : '\u2705';
      // Show loop iteration header when entering a new iteration
      if (entry.loopDepth != null &&
          entry.loopIteration != currentLoopIteration) {
        currentLoopIteration = entry.loopIteration;
        traceLines.add('\u2500 **\$for** iteration $currentLoopIteration');
      } else if (entry.loopDepth == null && currentLoopIteration != null) {
        currentLoopIteration = null;
      }
      final indent = entry.loopDepth != null ? '\u2003' : '';
      traceLines.add(
        '$indent`${t + 1}.` $status **${entry.actionType}** \u2014 +${entry.startMs}ms (${durationMs}ms)',
      );
    }
    // Build compilation info field
    final compilationField =
        debugCompilationMs != null
            ? {
              'name': '\u2699\ufe0f Compilation',
              'value':
                  '${debugCompilationMs}ms \u2022 ${debugSourceLength ?? '?'} chars \u2022 ${debugActionCount ?? '?'} actions',
              'inline': false,
            }
            : null;
    final description =
        traceLines.isEmpty
            ? '_No actions executed after \$debug._'
            : traceLines.join('\n');
    try {
      await sendMessageToChannel(
        client,
        resolvedFallbackChannelId,
        content: '',
        payload: <String, dynamic>{
          'embeds': [
            {
              'title': '\ud83d\udd0d Debug Trace',
              'description': description,
              'color': 0xFF9800,
              if (compilationField != null) 'fields': [compilationField],
              'footer': {
                'text':
                    'Total: ${totalMs}ms \u2022 ${debugTrace.length} action(s)',
              },
            },
          ],
        },
      );
    } catch (_) {
      // Best-effort: don't fail the command if the debug embed fails
    }
  }

  } catch (e) {
    variables['error.message'] = e.toString();
    variables['error.command'] = currentAction?.type.name ?? '';
    variables['error.source'] = '';
    variables['error.row'] = '';
    variables['error.column'] = '';
    if (currentAction != null && currentResultKey != null) {
      results[currentResultKey] = 'Error: $e';
      replayTrace?.add(
        _DebugTraceEntry(
          actionType: currentAction.type.name,
          startMs: currentReplayStartMs ?? 0,
          endMs: replayStopwatch?.elapsedMilliseconds ?? 0,
          result: 'Error: $e',
          loopDepth: currentAction.payload['_debugLoopDepth'] as int?,
          loopIteration: currentAction.payload['_debugLoopIteration'] as int?,
          variablesBefore: currentVarSnapshotBefore,
          variablesAfter: _snapshotVariables(variables),
        ),
      );
    }
    rethrow;
  } finally {
    // Replay capture callback — fires after the embed (if any) is sent.
    if (onReplayCaptured != null && replayTrace != null) {
      replayStopwatch?.stop();
      final totalMs = replayStopwatch?.elapsedMilliseconds ?? 0;
      onReplayCaptured(
        replayTrace
            .map(
              (entry) => <String, dynamic>{
                'actionType': entry.actionType,
                'startMs': entry.startMs,
                'durationMs': entry.endMs - entry.startMs,
                if (entry.result != null) 'result': entry.result,
                if (entry.loopDepth != null) 'loopDepth': entry.loopDepth,
                if (entry.loopIteration != null)
                  'loopIteration': entry.loopIteration,
                if (entry.variablesBefore != null)
                  'variablesBefore': entry.variablesBefore,
                if (entry.variablesAfter != null)
                  'variablesAfter': entry.variablesAfter,
              },
            )
            .toList(growable: false),
        totalMs,
      );
    }
  }

  return results;
}

/// Simplified action handler for workflows triggered by component/modal interactions.
/// These workflows don't have a slash command interaction context, so some action
/// types (e.g. respondWithModal) will not work and are simply skipped.
Future<Map<String, String>> handleListenerWorkflowActions(
  NyxxGateway client, {
  required List<Action> actions,
  required BotDataStore store,
  required String botId,
  required Map<String, String> variables,
  required String Function(String input) resolveTemplate,
  Interaction? interaction,
  LavalinkService? lavalinkService,
}) async {
  return handleActions(
    client,
    interaction,
    actions: actions,
    store: store,
    botId: botId,
    variables: variables,
    resolveTemplate: resolveTemplate,
    lavalinkService: lavalinkService,
  );
}

/// Takes a lightweight snapshot of [variables] for debug replay, capped
/// at 800 entries with values truncated to 500 characters.
Map<String, String> _snapshotVariables(Map<String, String> variables) {
  const maxEntries = 800;
  const maxValueLen = 500;
  final snapshot = <String, String>{};
  var count = 0;
  for (final entry in variables.entries) {
    if (count >= maxEntries) break;
    final value = entry.value;
    snapshot[entry.key] =
        value.length > maxValueLen ? value.substring(0, maxValueLen) : value;
    count++;
  }
  return snapshot;
}

class _DebugTraceEntry {
  const _DebugTraceEntry({
    required this.actionType,
    required this.startMs,
    required this.endMs,
    this.result,
    this.loopDepth,
    this.loopIteration,
    this.variablesBefore,
    this.variablesAfter,
  });

  final String actionType;
  final int startMs;
  final int endMs;
  final String? result;
  final int? loopDepth;
  final int? loopIteration;
  final Map<String, String>? variablesBefore;
  final Map<String, String>? variablesAfter;
}
