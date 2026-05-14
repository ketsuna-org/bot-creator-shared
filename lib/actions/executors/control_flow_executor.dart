import 'dart:convert';

import 'package:bot_creator_shared/utils/bdfd_duration_parser.dart';

import '../../types/action.dart';
import '../../utils/bdfd_compiler.dart';
import '../../utils/workflow_call.dart';

class ControlFlowExecutor {
  static final Map<String, int> _runtimeCooldowns = {};

  static String _getCooldownKey(
    String botId,
    String scope,
    String varKey,
    Map<String, String> variables,
  ) {
    final effectiveBotId = botId.isNotEmpty ? botId : (variables['bot.id'] ?? variables['botId'] ?? '');
    final userId = variables['user.id'] ?? variables['author.id'] ?? variables['userId'] ?? '';
    final guildId = variables['guild.id'] ?? variables['guildId'] ?? '';
    return '$effectiveBotId:$scope:$varKey:$userId:$guildId';
  }

  static void setRuntimeCooldown(
    String botId,
    String scope,
    String varKey,
    Map<String, String> variables,
    String durationStr,
  ) {
    final duration = parseBdfdDuration(durationStr);
    if (duration == null) return;

    final key = _getCooldownKey(botId, scope, varKey, variables);
    _runtimeCooldowns[key] = DateTime.now().millisecondsSinceEpoch + duration.inMilliseconds;
  }

  static void removeRuntimeCooldown(
    String botId,
    String scope,
    String varKey,
    Map<String, String> variables,
  ) {
    final key = _getCooldownKey(botId, scope, varKey, variables);
    _runtimeCooldowns.remove(key);
  }
}

bool _evaluateCondition({
  required String leftValue,
  required String operator,
  required String rightValue,
}) {
  final op = operator.toLowerCase().trim();
  switch (op) {
    case 'equals':
    case '==':
      return leftValue == rightValue;
    case 'notequals':
    case '!=':
      return leftValue != rightValue;
    case 'contains':
      return leftValue.contains(rightValue);
    case 'notcontains':
      return !leftValue.contains(rightValue);
    case 'startswith':
      return leftValue.startsWith(rightValue);
    case 'endswith':
      return leftValue.endsWith(rightValue);
    case 'greaterthan':
    case '>':
      return (num.tryParse(leftValue) ?? 0) > (num.tryParse(rightValue) ?? 0);
    case 'lessthan':
    case '<':
      return (num.tryParse(leftValue) ?? 0) < (num.tryParse(rightValue) ?? 0);
    case 'greaterorequal':
    case '>=':
      return (num.tryParse(leftValue) ?? 0) >= (num.tryParse(rightValue) ?? 0);
    case 'lessorequal':
    case '<=':
      return (num.tryParse(leftValue) ?? 0) <= (num.tryParse(rightValue) ?? 0);
    case 'isempty':
      return leftValue.trim().isEmpty;
    case 'isnotempty':
      return leftValue.trim().isNotEmpty;
    case 'matches':
      try {
        return RegExp(rightValue, caseSensitive: false).hasMatch(leftValue);
      } catch (_) {
        return false;
      }
    default:
      return false;
  }
}

bool _parseBooleanFlag(dynamic value) {
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' ||
      normalized == '1' ||
      normalized == 'yes' ||
      normalized == 'on';
}

Future<bool> _evaluateConditionFromPayload({
  required Map<String, dynamic> payload,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  required Future<int?> Function(String scope, String key)?
  getScopedVariableTtl,
}) async {
  final rawGroup =
      (payload['condition.group'] ?? payload['group'] ?? '').toString().trim();
  if (rawGroup.isNotEmpty) {
    final group = rawGroup.toLowerCase();
    final rawConditions =
        payload['condition.conditions'] ?? payload['conditions'];
    final conditionList = <Map<String, dynamic>>[];
    if (rawConditions is List) {
      for (final item in rawConditions) {
        if (item is Map) {
          conditionList.add(Map<String, dynamic>.from(item));
        }
      }
    }

    var groupResult = group == 'and';
    for (final condition in conditionList) {
      final passed = await _evaluateConditionFromPayload(
        payload: condition,
        variables: variables,
        resolveValue: resolveValue,
        getScopedVariableTtl: getScopedVariableTtl,
      );
      if (group == 'and') {
        groupResult = groupResult && passed;
      } else {
        groupResult = groupResult || passed;
      }
    }

    final negate = _parseBooleanFlag(
      payload['condition.negate'] ?? payload['negate'],
    );
    return negate ? !groupResult : groupResult;
  }

  final rawConditionVariable =
      (payload['condition.variable'] ?? payload['variable'] ?? '').toString();
  final conditionOperator =
      resolveValue(
        (payload['condition.operator'] ?? payload['operator'] ?? 'equals')
            .toString(),
      ).trim();
  final conditionValue = resolveValue(
    (payload['condition.value'] ?? payload['value'] ?? '').toString(),
  );
  final leftValue = _resolveConditionLeftValue(
    rawConditionVariable,
    variables,
    resolveValue,
  );

  final passed = _evaluateCondition(
    leftValue: leftValue,
    operator: conditionOperator,
    rightValue: conditionValue,
  );

  // Special handling for cooldown placeholders like %time%
  if (!passed &&
      conditionOperator.toLowerCase() == 'isempty' &&
      rawConditionVariable.contains('.bc_cooldown_')) {
    final trimmed = rawConditionVariable.trim();
    final contentMatch = RegExp(r'^\(\((.+)\)\)$').firstMatch(trimmed);
    if (contentMatch != null) {
      final content = contentMatch.group(1)!;
      final firstExpression = content.split('|').first.trim();
      final scopeMatch = RegExp(r'^([^.]+)\.(.+)$').firstMatch(firstExpression);
      if (scopeMatch != null) {
        final scope = scopeMatch.group(1)!;
        final key = scopeMatch.group(2)!;
        final botId = variables['bot.id'] ?? '';

        final storageKey = key.startsWith('bc_') ? key.substring(3) : key;
        final mapKey = ControlFlowExecutor._getCooldownKey(
          botId,
          scope,
          storageKey,
          variables,
        );
        final expiresAt = ControlFlowExecutor._runtimeCooldowns[mapKey];

        if (expiresAt != null) {
          final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;
          if (remaining > 0) {
            final unixTimestampSeconds = (expiresAt / 1000).floor();
            final discordTimestamp = '<t:$unixTimestampSeconds:R>';
            variables['cooldown.time'] = discordTimestamp;
            variables['time'] = discordTimestamp;
          } else {
            // Expired, clean up
            ControlFlowExecutor._runtimeCooldowns.remove(mapKey);
          }
        }
      }
    }
  }

  return passed;
}

String _resolveConditionLeftValue(
  String rawConditionVariable,
  Map<String, String> variables,
  String Function(String input) resolveValue,
) {
  final raw = rawConditionVariable.trim();
  if (raw.isEmpty) {
    return '';
  }

  if (variables.containsKey(raw)) {
    return variables[raw] ?? '';
  }

  final wrappedMatch = RegExp(r'^\(\((.+)\)\)$').firstMatch(raw);
  if (wrappedMatch != null) {
    final wrappedKey = (wrappedMatch.group(1) ?? '').trim();
    final expressions = wrappedKey.split('|').map((e) => e.trim()).toList();

    for (final expr in expressions) {
      if (expr.contains('.bc_cooldown_')) {
        final scopeMatch = RegExp(r'^([^.]+)\.(.+)$').firstMatch(expr);
        if (scopeMatch != null) {
          final scope = scopeMatch.group(1)!;
          final key = scopeMatch.group(2)!;
          final botId = variables['bot.id'] ?? '';
          final storageKey = key.startsWith('bc_') ? key.substring(3) : key;

          final mapKey = ControlFlowExecutor._getCooldownKey(
            botId,
            scope,
            storageKey,
            variables,
          );
          final expiresAt = ControlFlowExecutor._runtimeCooldowns[mapKey];
          if (expiresAt != null) {
            final remaining = expiresAt - DateTime.now().millisecondsSinceEpoch;
            if (remaining > 0) {
              return 'cooldown_active';
            } else {
              ControlFlowExecutor._runtimeCooldowns.remove(mapKey);
            }
          }
          // Cooldown is NOT active in RAM, so return empty even if it exists in 'variables'
          return '';
        }
      }

      final value = variables[expr];
      if (value != null) {
        return value;
      }
    }
  }

  return resolveValue(rawConditionVariable);
}

List<Action> _decodeActionList(dynamic branchRaw) {
  final branchActions = <Action>[];
  if (branchRaw is! List) {
    return branchActions;
  }

  for (final item in branchRaw) {
    if (item is Map) {
      branchActions.add(Action.fromJson(Map<String, dynamic>.from(item)));
    }
  }

  return branchActions;
}

Future<bool> executeControlFlowAction({
  required BotCreatorActionType type,
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String botId,
  required String Function(String input) resolveValue,
  required void Function(String message)? onLog,
  required Set<String> activeWorkflowStack,
  required Future<Map<String, dynamic>?> Function(String workflowName)
  getWorkflowByName,
  required Future<Map<String, String>> Function(List<Action> actions)
  executeActions,

  /// When provided, applied to compiled/resolved actions before they are
  /// passed to [executeActions] in [runBdfdScript] and [runWorkflow]. Used by
  /// Legacy command handlers to adapt actions for messageCreate context.
  List<Action> Function(List<Action>)? nestedActionsPreprocessor,

  /// Optional provider for variable TTLs, used for cooldown resolution.
  Future<int?> Function(String scope, String key)? getScopedVariableTtl,
}) async {
  switch (type) {
    case BotCreatorActionType.runBdfdScript:
      final bdfdSource = resolveValue(
        (payload['scriptContent'] ?? '').toString(),
      );
      if (bdfdSource.trim().isEmpty) {
        results[resultKey] = 'BDFD_EMPTY';
        return true;
      }

      final compileResult = BdfdCompiler().compile(bdfdSource);
      if (compileResult.hasErrors) {
        final summary = compileResult.diagnostics
            .where((d) => d.severity == BdfdCompileDiagnosticSeverity.error)
            .take(5)
            .map((d) => d.message)
            .join('; ');
        throw Exception('BDFD compile error: $summary');
      }

      if (compileResult.actions.isEmpty) {
        results[resultKey] = 'BDFD_NO_ACTIONS';
        return true;
      }

      final preprocessedActions =
          nestedActionsPreprocessor?.call(compileResult.actions) ??
          compileResult.actions;
      final bdfdResults = await executeActions(preprocessedActions);
      for (final entry in bdfdResults.entries) {
        results['$resultKey.${entry.key}'] = entry.value;
      }
      if (bdfdResults.containsKey('__stopped__')) {
        results['__stopped__'] = 'true';
      }
      results[resultKey] = 'BDFD_OK';
      return true;

    case BotCreatorActionType.runWorkflow:
      final workflowName =
          resolveValue((payload['workflowName'] ?? '').toString()).trim();
      if (workflowName.isEmpty) {
        throw Exception('workflowName is required for runWorkflow');
      }

      final workflow = await getWorkflowByName(workflowName);
      if (workflow == null) {
        throw Exception('Workflow not found: $workflowName');
      }

      final requestedEntryPoint =
          resolveValue((payload['entryPoint'] ?? '').toString()).trim();
      final workflowEntryPoint = normalizeWorkflowEntryPoint(
        requestedEntryPoint,
        fallback: normalizeWorkflowEntryPoint(workflow['entryPoint']),
      );
      final workflowArgDefinitions = parseWorkflowArgumentDefinitions(
        workflow['arguments'],
      );
      final workflowCallArguments = resolveWorkflowCallArguments(
        payload['arguments'],
        resolveValue,
      );

      final stackKey =
          '${workflowName.toLowerCase()}::${workflowEntryPoint.toLowerCase()}';
      if (activeWorkflowStack.contains(stackKey)) {
        throw Exception(
          'Workflow recursion detected for "$workflowName" (entry: $workflowEntryPoint)',
        );
      }

      applyWorkflowInvocationContext(
        variables: variables,
        workflowName: workflowName,
        entryPoint: workflowEntryPoint,
        definitions: workflowArgDefinitions,
        providedArguments: workflowCallArguments,
      );

      final workflowActions = List<Action>.from(
        ((workflow['actions'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((json) => Action.fromJson(Map<String, dynamic>.from(json))),
      );
      final preprocessedWorkflowActions =
          nestedActionsPreprocessor?.call(workflowActions) ?? workflowActions;

      activeWorkflowStack.add(stackKey);
      late final Map<String, String> workflowResults;
      try {
        workflowResults = await executeActions(preprocessedWorkflowActions);
      } finally {
        activeWorkflowStack.remove(stackKey);
      }

      for (final entry in workflowResults.entries) {
        results['$resultKey.${entry.key}'] = entry.value;
        variables['workflow.response.${entry.key}'] = entry.value;
      }
      variables['workflow.response'] = 'WORKFLOW_OK:$workflowEntryPoint';
      results[resultKey] = 'WORKFLOW_OK:$workflowEntryPoint';
      return true;

    case BotCreatorActionType.stopUnless:
      final conditionPassed = await _evaluateConditionFromPayload(
        payload: payload,
        variables: variables,
        resolveValue: resolveValue,
        getScopedVariableTtl: getScopedVariableTtl,
      );
      results[resultKey] = conditionPassed ? 'PASSED' : 'STOPPED';
      if (!conditionPassed) {
        results['__stopped__'] = 'true';
      }
      return true;

    case BotCreatorActionType.ifBlock:
      final conditionPassed = await _evaluateConditionFromPayload(
        payload: payload,
        variables: variables,
        resolveValue: resolveValue,
        getScopedVariableTtl: getScopedVariableTtl,
      );

      final rawThen = payload['thenActions'];
      final rawElse = payload['elseActions'];
      dynamic branchRaw = rawThen;
      var branchResult = 'IF_TRUE';

      if (!conditionPassed) {
        branchRaw = rawElse;
        branchResult = 'IF_FALSE';

        final rawElseIfConditions = payload['elseIfConditions'];
        if (rawElseIfConditions is List) {
          for (var index = 0; index < rawElseIfConditions.length; index++) {
            final entry = rawElseIfConditions[index];
            if (entry is! Map) {
              continue;
            }

            final elseIf = Map<String, dynamic>.from(entry);
            final elseIfPassed = await _evaluateConditionFromPayload(
              payload: elseIf,
              variables: variables,
              resolveValue: resolveValue,
              getScopedVariableTtl: getScopedVariableTtl,
            );
            if (!elseIfPassed) {
              continue;
            }

            branchRaw = elseIf['actions'];
            branchResult = 'ELSE_IF_${index + 1}';
            break;
          }
        }
      }

      final branchActions = _decodeActionList(branchRaw);

      results[resultKey] = branchResult;
      if (branchActions.isEmpty) {
        return true;
      }

      final branchResults = await executeActions(branchActions);
      for (final entry in branchResults.entries) {
        results['$resultKey.${entry.key}'] = entry.value;
      }
      if (branchResults.containsKey('__stopped__')) {
        results['__stopped__'] = 'true';
      }
      return true;

    case BotCreatorActionType.forLoop:
      final mode = (payload['mode'] ?? 'simple').toString();
      final maxIterations = (payload['maxIterations'] as int?) ?? 100;

      if (mode == 'cstyle') {
        return _executeCStyleForLoop(
          payload: payload,
          resultKey: resultKey,
          results: results,
          variables: variables,
          resolveValue: resolveValue,
          executeActions: executeActions,
          maxIterations: maxIterations,
        );
      }

      // Simple runtime loop: iterations is a template string.
      final rawIterations =
          resolveValue((payload['iterations'] ?? '0').toString()).trim();
      final iterations = int.tryParse(rawIterations) ?? 0;
      final capped = iterations > maxIterations ? maxIterations : iterations;
      final bodyActionsRaw = payload['bodyActions'];
      final templateActions = _decodeActionList(bodyActionsRaw);

      if (capped <= 0 || templateActions.isEmpty) {
        results[resultKey] = 'LOOP_0';
        return true;
      }

      for (var i = 0; i < capped; i++) {
        variables['_loop.index'] = i.toString();
        variables['_loop.count'] = (i + 1).toString();

        final iterActions = _cloneActionsWithLoopVars(
          templateActions,
          loopVars: <String, String>{
            '_loop.index': i.toString(),
            '_loop.count': (i + 1).toString(),
          },
        );
        final iterResults = await executeActions(iterActions);
        for (final entry in iterResults.entries) {
          results['$resultKey.iter$i.${entry.key}'] = entry.value;
        }
        if (iterResults.containsKey('__stopped__')) {
          results['__stopped__'] = 'true';
          break;
        }
      }
      variables.remove('_loop.index');
      variables.remove('_loop.count');
      results[resultKey] = 'LOOP_$capped';
      return true;

    case BotCreatorActionType.jsonForEachLoop:
      final maxIterations = (payload['maxIterations'] as int?) ?? 100;
      final pathRaw = payload['path'];
      final pathSegments =
          (pathRaw is List)
              ? pathRaw.map((e) => resolveValue(e.toString())).toList()
              : const <String>[];
      final bodyActionsRaw = payload['bodyActions'];
      final templateActions = _decodeActionList(bodyActionsRaw);

      if (templateActions.isEmpty) {
        results[resultKey] = 'JSONFE_0';
        return true;
      }

      // Resolve the JSON source from the variables/results context.
      // Look for the latest runtimeJsonBlock result in variables.
      dynamic jsonCtx;
      final mergedContext = <String, String>{...variables, ...results};
      var jsonSource = _findLatestJsonContext(mergedContext);
      // Fall back to the compile-time source embedded in the payload.
      if (jsonSource.isEmpty) {
        jsonSource = (payload['source'] as String?) ?? '';
      }
      if (jsonSource.isNotEmpty) {
        try {
          jsonCtx = jsonDecode(jsonSource);
        } catch (_) {
          jsonCtx = null;
        }
      }

      // Navigate the path.
      if (jsonCtx != null && pathSegments.isNotEmpty) {
        for (final segment in pathSegments) {
          final index = int.tryParse(segment);
          if (index != null && jsonCtx is List) {
            if (index < 0 || index >= jsonCtx.length) {
              jsonCtx = null;
              break;
            }
            jsonCtx = jsonCtx[index];
          } else if (jsonCtx is Map) {
            if (!jsonCtx.containsKey(segment)) {
              jsonCtx = null;
              break;
            }
            jsonCtx = jsonCtx[segment];
          } else {
            jsonCtx = null;
            break;
          }
        }
      }

      if (jsonCtx is! Map) {
        results[resultKey] = 'JSONFE_0';
        return true;
      }

      final keys = jsonCtx.keys.toList();
      final capped2 = keys.length > maxIterations ? maxIterations : keys.length;

      for (var i = 0; i < capped2; i++) {
        final key = keys[i].toString();
        final value = _jsonStringifyForEach(jsonCtx[keys[i]]);
        variables['_loop.var.jsonkey'] = key;
        variables['_loop.var.jsonvalue'] = value;
        variables['_loop.var.jsonindex'] = i.toString();
        variables['_loop.index'] = i.toString();
        variables['_loop.count'] = (i + 1).toString();

        final iterActions = _cloneActionsWithLoopVars(
          templateActions,
          loopVars: <String, String>{
            '_loop.var.jsonkey': key,
            '_loop.var.jsonvalue': value,
            '_loop.var.jsonindex': i.toString(),
            '_loop.index': i.toString(),
            '_loop.count': (i + 1).toString(),
          },
        );
        final iterResults = await executeActions(iterActions);
        for (final entry in iterResults.entries) {
          results['$resultKey.iter$i.${entry.key}'] = entry.value;
        }
        if (iterResults.containsKey('__stopped__')) {
          results['__stopped__'] = 'true';
          break;
        }
      }
      variables.remove('_loop.var.jsonkey');
      variables.remove('_loop.var.jsonvalue');
      variables.remove('_loop.var.jsonindex');
      variables.remove('_loop.index');
      variables.remove('_loop.count');
      results[resultKey] = 'JSONFE_$capped2';
      return true;

    case BotCreatorActionType.cooldown:
      final scope = resolveValue((payload['scope'] ?? 'user').toString()).trim();
      final durationStr =
          resolveValue((payload['duration'] ?? '0s').toString()).trim();
      final varKey =
          resolveValue((payload['key'] ?? 'default').toString()).trim();
      final errorMessage =
          resolveValue((payload['errorMessage'] ?? '').toString());

      final key = ControlFlowExecutor._getCooldownKey(botId, scope, varKey, variables);
      final expiresAt = ControlFlowExecutor._runtimeCooldowns[key];
      final now = DateTime.now().millisecondsSinceEpoch;

      if (expiresAt != null && expiresAt > now) {
        // Cooldown is active
        results[resultKey] = 'ACTIVE';
        results['__stopped__'] = 'true';

        if (errorMessage.isNotEmpty) {
          final unixTimestampSeconds = (expiresAt / 1000).floor();
          final discordTimestamp = '<t:$unixTimestampSeconds:R>';

          variables['cooldown.time'] = discordTimestamp;
          variables['time'] = discordTimestamp;

          final resolvedMessage = errorMessage.replaceAll(
            '%time%',
            discordTimestamp,
          );
          results['cooldown.error'] = resolvedMessage;

          // Send the message automatically using the shared executeActions logic.
          await executeActions([
            Action(
              type: BotCreatorActionType.sendMessage,
              payload: <String, dynamic>{'content': resolvedMessage},
            ),
          ]);
        }
        return true;
      }

      // No active cooldown, set a new one
      final duration = parseBdfdDuration(durationStr);
      if (duration != null && duration.inMilliseconds > 0) {
        ControlFlowExecutor._runtimeCooldowns[key] = now + duration.inMilliseconds;
      }

      results[resultKey] = 'SET';
      return true;
    case BotCreatorActionType.wait:
      final durationStr = resolveValue((payload['duration'] ?? '0s').toString()).trim();
      final duration = parseBdfdDuration(durationStr);
      if (duration != null && duration.inMilliseconds > 0) {
        await Future.delayed(duration);
      }
      results[resultKey] = 'WAITED';
      return true;
    case BotCreatorActionType.stop:
      results[resultKey] = 'STOPPED';
      results['__stopped__'] = 'true';
      return true;
    default:
      return false;
  }
}

/// Executes a C-style runtime for loop.
Future<bool> _executeCStyleForLoop({
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
  required Future<Map<String, String>> Function(List<Action> actions)
  executeActions,
  required int maxIterations,
}) async {
  final initRaw = resolveValue((payload['init'] ?? '').toString());
  final conditionTemplate = (payload['condition'] ?? '').toString();
  final updateTemplate = (payload['update'] ?? '').toString();
  final varNames = List<String>.from(payload['varNames'] ?? const <String>[]);
  final bodyActionsRaw = payload['bodyActions'];
  final templateActions = _decodeActionList(bodyActionsRaw);

  // Parse init: "i=0, j=10" where values may now be runtime-resolved.
  final loopVars = <String, int>{};
  for (final part in initRaw.split(',')) {
    final eqIndex = part.indexOf('=');
    if (eqIndex < 0) continue;
    final name = part.substring(0, eqIndex).trim().toLowerCase();
    final valueStr = resolveValue(part.substring(eqIndex + 1).trim());
    loopVars[name] = int.tryParse(valueStr) ?? 0;
  }

  if (templateActions.isEmpty) {
    results[resultKey] = 'LOOP_0';
    return true;
  }

  var iterationCount = 0;

  while (iterationCount < maxIterations) {
    final resolvedCondition = _resolveLoopExpression(
      conditionTemplate,
      loopVars,
      resolveValue,
    );
    if (!_evaluateSimpleCondition(resolvedCondition)) break;

    for (final entry in loopVars.entries) {
      variables['_loop.var.${entry.key}'] = entry.value.toString();
    }
    variables['_loop.index'] = iterationCount.toString();
    variables['_loop.count'] = (iterationCount + 1).toString();

    final iterActions = _cloneActionsWithLoopVars(
      templateActions,
      loopVars: <String, String>{
        for (final entry in loopVars.entries)
          '_loop.var.${entry.key}': entry.value.toString(),
        '_loop.index': iterationCount.toString(),
        '_loop.count': (iterationCount + 1).toString(),
      },
    );
    final iterResults = await executeActions(iterActions);
    for (final entry in iterResults.entries) {
      results['$resultKey.iter$iterationCount.${entry.key}'] = entry.value;
    }
    if (iterResults.containsKey('__stopped__')) {
      results['__stopped__'] = 'true';
      break;
    }

    _applyRuntimeCStyleUpdate(updateTemplate, loopVars, resolveValue);
    iterationCount++;
  }

  for (final name in varNames) {
    variables.remove('_loop.var.$name');
  }
  variables.remove('_loop.index');
  variables.remove('_loop.count');
  results[resultKey] = 'LOOP_$iterationCount';
  return true;
}

List<Action> _cloneActionsWithLoopVars(
  List<Action> templateActions, {
  required Map<String, String> loopVars,
}) {
  return templateActions.map((action) {
    final resolvedPayload = _resolvePayloadLoopVars(action.payload, loopVars);
    return Action(
      type: action.type,
      key: action.key,
      payload: resolvedPayload,
      enabled: action.enabled,
    );
  }).toList();
}

Map<String, dynamic> _resolvePayloadLoopVars(
  Map<String, dynamic> payload,
  Map<String, String> loopVars,
) {
  return payload.map((key, value) {
    if (value is String) {
      return MapEntry(key, _substituteLoopPlaceholders(value, loopVars));
    }
    if (value is List) {
      return MapEntry(
        key,
        value.map((item) {
          if (item is String) {
            return _substituteLoopPlaceholders(item, loopVars);
          }
          if (item is Map) {
            return _resolvePayloadLoopVars(
              Map<String, dynamic>.from(item),
              loopVars,
            );
          }
          return item;
        }).toList(),
      );
    }
    if (value is Map) {
      return MapEntry(
        key,
        _resolvePayloadLoopVars(Map<String, dynamic>.from(value), loopVars),
      );
    }
    return MapEntry(key, value);
  });
}

String _substituteLoopPlaceholders(String input, Map<String, String> loopVars) {
  var result = input;
  for (final entry in loopVars.entries) {
    result = result.replaceAll('((${entry.key}))', entry.value);
  }
  return result;
}

String _resolveLoopExpression(
  String template,
  Map<String, int> loopVars,
  String Function(String input) resolveValue,
) {
  var result = template;
  for (final entry in loopVars.entries) {
    result = result.replaceAll(
      '((_loop.var.${entry.key}))',
      entry.value.toString(),
    );
  }
  return resolveValue(result);
}

bool _evaluateSimpleCondition(String resolved) {
  final pattern = RegExp(r'^(-?\d+)\s*(<=|>=|<|>|==|!=)\s*(-?\d+)$');
  final match = pattern.firstMatch(resolved.trim());
  if (match == null) return false;
  final left = int.tryParse(match.group(1)!) ?? 0;
  final op = match.group(2)!;
  final right = int.tryParse(match.group(3)!) ?? 0;
  switch (op) {
    case '<':
      return left < right;
    case '<=':
      return left <= right;
    case '>':
      return left > right;
    case '>=':
      return left >= right;
    case '==':
      return left == right;
    case '!=':
      return left != right;
    default:
      return false;
  }
}

void _applyRuntimeCStyleUpdate(
  String raw,
  Map<String, int> vars,
  String Function(String input) resolveValue,
) {
  for (final part in raw.split(',')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) continue;
    final resolved = _resolveLoopExpression(trimmed, vars, resolveValue);
    if (resolved.endsWith('++')) {
      final name =
          resolved.substring(0, resolved.length - 2).trim().toLowerCase();
      vars[name] = (vars[name] ?? 0) + 1;
    } else if (resolved.endsWith('--')) {
      final name =
          resolved.substring(0, resolved.length - 2).trim().toLowerCase();
      vars[name] = (vars[name] ?? 0) - 1;
    } else if (resolved.contains('+=')) {
      final sides = resolved.split('+=');
      final name = sides[0].trim().toLowerCase();
      final value = int.tryParse(sides[1].trim()) ?? 0;
      vars[name] = (vars[name] ?? 0) + value;
    } else if (resolved.contains('-=')) {
      final sides = resolved.split('-=');
      final name = sides[0].trim().toLowerCase();
      final value = int.tryParse(sides[1].trim()) ?? 0;
      vars[name] = (vars[name] ?? 0) - value;
    } else if (resolved.contains('*=')) {
      final sides = resolved.split('*=');
      final name = sides[0].trim().toLowerCase();
      final value = int.tryParse(sides[1].trim()) ?? 1;
      vars[name] = (vars[name] ?? 0) * value;
    }
  }
}

/// Finds the latest runtime JSON context value from merged variables/results.
String _findLatestJsonContext(Map<String, String> mergedContext) {
  String? best;
  int bestIndex = -1;
  for (final entry in mergedContext.entries) {
    final key = entry.key.toLowerCase();
    if (entry.value.trim().isEmpty) continue;
    if (!key.startsWith('rtjson_') &&
        !RegExp(r'^action_\d+(\.json_\d+)?$').hasMatch(key)) {
      continue;
    }
    final idx = _feActionKeyIndex(key);
    if (idx > bestIndex && _looksLikeJson(entry.value)) {
      bestIndex = idx;
      best = entry.value;
    }
  }
  return best ?? '';
}

int _feActionKeyIndex(String key) {
  final match = RegExp(r'(\d+)').firstMatch(key);
  return match != null ? (int.tryParse(match.group(1)!) ?? 0) : 0;
}

bool _looksLikeJson(String value) {
  final trimmed = value.trim();
  return (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
      (trimmed.startsWith('[') && trimmed.endsWith(']'));
}

String _jsonStringifyForEach(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return jsonEncode(value);
}
