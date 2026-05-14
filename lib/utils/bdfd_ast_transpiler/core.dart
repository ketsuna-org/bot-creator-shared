part of '../bdfd_ast_transpiler.dart';

enum BdfdTranspileDiagnosticSeverity { warning, error }

class BdfdTranspileDiagnostic {
  const BdfdTranspileDiagnostic({
    required this.message,
    this.severity = BdfdTranspileDiagnosticSeverity.error,
    this.start,
    this.end,
    this.functionName,
  });

  final String message;
  final BdfdTranspileDiagnosticSeverity severity;
  final int? start;
  final int? end;
  final String? functionName;
}

class BdfdTranspileResult {
  const BdfdTranspileResult({required this.actions, required this.diagnostics});

  final List<Action> actions;
  final List<BdfdTranspileDiagnostic> diagnostics;

  bool get hasErrors => diagnostics.any(
    (diagnostic) =>
        diagnostic.severity == BdfdTranspileDiagnosticSeverity.error,
  );
}

class BdfdAstTranspiler {
  BdfdTranspileResult transpile(BdfdScriptAst script) {
    final diagnostics = <BdfdTranspileDiagnostic>[];
    final transpiler = _BdfdAstTranspilationScope(diagnostics: diagnostics);
    final actions = transpiler.transpileScript(script);
    return BdfdTranspileResult(
      actions: List<Action>.unmodifiable(actions),
      diagnostics: List<BdfdTranspileDiagnostic>.unmodifiable(diagnostics),
    );
  }
}

class _BdfdAstTranspilationScope {
  _BdfdAstTranspilationScope({
    required List<BdfdTranspileDiagnostic> diagnostics,
  }) : _diagnostics = diagnostics;

  final List<BdfdTranspileDiagnostic> _diagnostics;
  final Map<String, String> _pendingHttpHeaders = <String, String>{};
  int _httpRequestCounter = 0;
  int _threadActionCounter = 0;
  int _permissionCheckCounter = 0;
  int _callWorkflowCounter = 0;
  String? _lastHttpRequestKey;
  String? _lastCallWorkflowKey;
  final List<Action> _deferredInlineActions = <Action>[];
  final List<List<Action>> _conditionActionStack = <List<Action>>[];
  dynamic _jsonContext;
  bool _hasJsonContext = false;

  // ── Deferred (runtime) JSON state ──────────────────────────────────────────
  /// When true, JSON operations are collected instead of executed because the
  /// source contains runtime placeholders that cannot be resolved at
  /// compile-time.
  bool _deferredJsonMode = false;
  String _deferredJsonSource = '';
  final List<Map<String, dynamic>> _deferredJsonOps = <Map<String, dynamic>>[];
  int _deferredJsonReadCounter = 0;
  int _deferredJsonBlockCounter = 0;
  String? _deferredJsonResultKeyPrefix;
  String? _lastDeferredJsonResultKeyPrefix;

  List<String> _textSplitParts = <String>[];
  String? _useChannelId;
  bool _suppressErrors = false;
  int _loopIterationIndex = 0;
  int _loopDepth = 0;
  Map<String, int> _loopVariables = <String, int>{};
  Set<String>? _runtimeLoopVarNames;
  final List<Map<String, dynamic>> _pendingModalInputs =
      <Map<String, dynamic>>[];

  List<Action> transpileScript(BdfdScriptAst script) {
    return _transpileNodes(script.nodes);
  }

  List<Action> _transpileNodes(List<BdfdAstNode> nodes) {
    _conditionActionStack.add(<Action>[]);
    final actions = <Action>[];
    final pendingResponse = _PendingResponse();

    try {
      var index = 0;
      while (index < nodes.length) {
        final node = nodes[index];
        if (node is BdfdTextAst) {
          pendingResponse.appendContent(node.value);
          index += 1;
          continue;
        }

        if (node is! BdfdFunctionCallAst) {
          _diagnostics.add(
            BdfdTranspileDiagnostic(
              message: 'Unsupported AST node encountered during transpilation.',
              start: node.start,
              end: node.end,
            ),
          );
          index += 1;
          continue;
        }

        if (_isBlockIfSignature(node)) {
          final deferredJson = _flushDeferredJson();
          if (deferredJson != null) {
            actions.add(deferredJson);
          }

          final flushed = pendingResponse.buildAction(channelId: _useChannelId);
          if (flushed != null) {
            actions.add(flushed);
          }

          final consumed = _consumeIfBlock(nodes: nodes, startIndex: index);
          if (consumed == null) {
            index += 1;
            continue;
          }

          actions.addAll(_drainPendingConditionActions());
          actions.addAll(_drainDeferredInlineActions());
          actions.add(consumed.action);
          index = consumed.nextIndex;
          continue;
        }

        if (_isBlockLoopSignature(node)) {
          final deferredJson = _flushDeferredJson();
          if (deferredJson != null) {
            actions.add(deferredJson);
          }

          final consumed = _consumeLoopBlock(nodes: nodes, startIndex: index);
          if (consumed == null) {
            index += 1;
            continue;
          }

          if (consumed.isRuntimeLoop) {
            final runtimeLoopDeferredJson = _flushDeferredJson();
            if (runtimeLoopDeferredJson != null) {
              actions.add(runtimeLoopDeferredJson);
            }
            final flushed = pendingResponse.buildAction(
              channelId: _useChannelId,
            );
            if (flushed != null) {
              actions.add(flushed);
            }
            actions.add(_buildRuntimeForLoopAction(consumed));
            index = consumed.nextIndex;
            continue;
          }

          if (consumed.isCStyleLoop) {
            final extraNames = consumed.cStyleInit!.keys.toSet();
            if (_isResponseOnlyLoopBody(
              consumed.bodyNodes,
              extraInlineNames: extraNames,
            )) {
              _applyCStyleLoopBodyToResponse(
                bodyNodes: consumed.bodyNodes,
                initVars: consumed.cStyleInit!,
                condition: consumed.cStyleCondition!,
                update: consumed.cStyleUpdate!,
                response: pendingResponse,
              );
            } else {
              final flushed = pendingResponse.buildAction(
                channelId: _useChannelId,
              );
              if (flushed != null) {
                actions.add(flushed);
              }
              actions.addAll(
                _transpileCStyleLoop(
                  bodyNodes: consumed.bodyNodes,
                  initVars: consumed.cStyleInit!,
                  condition: consumed.cStyleCondition!,
                  update: consumed.cStyleUpdate!,
                ),
              );
            }
          } else if (_isResponseOnlyLoopBody(consumed.bodyNodes)) {
            _applyLoopBodyToResponse(
              bodyNodes: consumed.bodyNodes,
              iterations: consumed.iterations,
              response: pendingResponse,
            );
          } else {
            final flushed = pendingResponse.buildAction(
              channelId: _useChannelId,
            );
            if (flushed != null) {
              actions.add(flushed);
            }
            final loopActions =
                consumed.precomputedActions ??
                _transpileLoopIterations(
                  bodyNodes: consumed.bodyNodes,
                  iterations: consumed.iterations,
                );
            actions.addAll(loopActions);
          }
          index = consumed.nextIndex;
          continue;
        }

        if (_isBlockJsonForEachSignature(node)) {
          final deferredJson = _flushDeferredJson();
          if (deferredJson != null) {
            actions.add(deferredJson);
          }

          final result = _consumeJsonForEachBlock(
            nodes: nodes,
            startIndex: index,
          );
          if (result == null) {
            index += 1;
            continue;
          }

          final runtimeDeferredJson = _flushDeferredJson();
          if (runtimeDeferredJson != null) {
            actions.add(runtimeDeferredJson);
          }
          final flushed = pendingResponse.buildAction(channelId: _useChannelId);
          if (flushed != null) {
            actions.add(flushed);
          }
          actions.add(result.action);
          index = result.nextIndex;
          continue;
        }

        if (_isBlockTrySignature(node)) {
          final deferredJson = _flushDeferredJson();
          if (deferredJson != null) {
            actions.add(deferredJson);
          }

          final flushed = pendingResponse.buildAction(channelId: _useChannelId);
          if (flushed != null) {
            actions.add(flushed);
          }

          final consumed = _consumeTryCatchBlock(
            nodes: nodes,
            startIndex: index,
          );
          if (consumed == null) {
            index += 1;
            continue;
          }

          actions.addAll(consumed.precomputedActions ?? const <Action>[]);
          index = consumed.nextIndex;
          continue;
        }

        if (_isStandaloneIfDelimiter(node.normalizedName)) {
          _diagnostics.add(
            BdfdTranspileDiagnostic(
              message:
                  'Unexpected ${node.name} without a matching surrounding block ${r'$if'}[] statement.',
              start: node.start,
              end: node.end,
              functionName: node.name,
            ),
          );
          index += 1;
          continue;
        }

        if (_isStandaloneLoopDelimiter(node.normalizedName)) {
          _diagnostics.add(
            BdfdTranspileDiagnostic(
              message:
                  'Unexpected ${node.name} without a matching surrounding block ${r'$for'}[] statement.',
              start: node.start,
              end: node.end,
              functionName: node.name,
            ),
          );
          index += 1;
          continue;
        }

        if (_isStandaloneJsonForEachDelimiter(node.normalizedName)) {
          _diagnostics.add(
            BdfdTranspileDiagnostic(
              message:
                  'Unexpected ${node.name} without a matching surrounding ${r'$jsonForEach'}[] block.',
              start: node.start,
              end: node.end,
              functionName: node.name,
            ),
          );
          index += 1;
          continue;
        }

        if (_isStandaloneTryDelimiter(node.normalizedName)) {
          _diagnostics.add(
            BdfdTranspileDiagnostic(
              message:
                  'Unexpected ${node.name} without a matching surrounding ${r'$try'} block.',
              start: node.start,
              end: node.end,
              functionName: node.name,
            ),
          );
          index += 1;
          continue;
        }

        if (_applyResponseMutation(node, pendingResponse)) {
          actions.addAll(_drainDeferredInlineActions());
          index += 1;
          continue;
        }

        final isCheckUserPermsInlineCandidate =
            node.normalizedName == 'checkuserperms' ||
            node.normalizedName == 'checkusersperms';
        final hasTrailingTextNode =
            index + 1 < nodes.length && nodes[index + 1] is BdfdTextAst;
        final allowsTopLevelInline =
            !isCheckUserPermsInlineCandidate ||
            pendingResponse.hasPendingContent ||
            hasTrailingTextNode;
        final inlineReplacement =
            allowsTopLevelInline ? _stringifyInlineFunction(node) : null;
        if (inlineReplacement != null) {
          pendingResponse.appendContent(inlineReplacement);
          actions.addAll(_drainDeferredInlineActions());
          index += 1;
          continue;
        }

        if (_requiresPendingResponseFlush(node.normalizedName) &&
            pendingResponse.hasPendingContent) {
          // Flush deferred JSON before emitting a pending response so that
          // runtime JSON placeholders used in the response are resolved first.
          final deferredJson = _flushDeferredJson();
          if (deferredJson != null) actions.add(deferredJson);

          final flushed = pendingResponse.buildAction(channelId: _useChannelId);
          if (flushed != null) {
            actions.add(flushed);
          }
        }

        final shouldFlushDeferredBeforeCurrentAction =
            node.normalizedName == 'if';

        if (shouldFlushDeferredBeforeCurrentAction) {
          final deferredJson = _flushDeferredJson();
          if (deferredJson != null) actions.add(deferredJson);
        }

        final emitted = _transpileStandaloneFunction(
          node,
          pendingResponse: pendingResponse,
        );
        actions.addAll(_drainPendingConditionActions());
        actions.addAll(_drainDeferredInlineActions());

        // Flush deferred JSON AFTER transpiling a non-JSON standalone function
        // so inline JSON reads inside its arguments (e.g. $setServerVar[...,
        // $jsonStringify]) are converted into runtime placeholders first.
        final shouldFlushDeferredAfterCurrentAction =
            !_isJsonMutationFunction(node.normalizedName) &&
            node.normalizedName != 'jsonparse' &&
            !shouldFlushDeferredBeforeCurrentAction;
        if (shouldFlushDeferredAfterCurrentAction) {
          final deferredJson = _flushDeferredJson();
          if (deferredJson != null) actions.add(deferredJson);
        }

        if (emitted != null) {
          actions.add(emitted);
        }

        index += 1;
      }

      final trailingConditionActions = _drainPendingConditionActions();
      if (trailingConditionActions.isNotEmpty) {
        actions.addAll(trailingConditionActions);
      }

      // Flush any remaining deferred JSON block before the trailing response.
      final trailingDeferredJson = _flushDeferredJson();
      if (trailingDeferredJson != null) {
        actions.add(trailingDeferredJson);
      }

      final trailingResponse = pendingResponse.buildAction(
        channelId: _useChannelId,
      );
      if (trailingResponse != null) {
        actions.add(trailingResponse);
      }

      if (_suppressErrors && actions.isNotEmpty) {
        return <Action>[
          Action(
            type: BotCreatorActionType.ifBlock,
            payload: <String, dynamic>{
              'condition.variable': '1',
              'condition.operator': 'equals',
              'condition.value': '1',
              'thenActions': actions.map((action) => action.toJson()).toList(),
              'elseIfConditions': const <Map<String, dynamic>>[],
              'elseActions': const <Map<String, dynamic>>[],
              'suppressErrors': true,
            },
          ),
        ];
      }

      return actions;
    } finally {
      _conditionActionStack.removeLast();
    }
  }

  bool _isBlockIfSignature(BdfdFunctionCallAst node) {
    return node.normalizedName == 'if' && node.arguments.length <= 1;
  }

  bool _isStandaloneIfDelimiter(String normalizedName) {
    return normalizedName == 'elseif' ||
        normalizedName == 'else' ||
        normalizedName == 'endif';
  }

  bool _isBlockLoopSignature(BdfdFunctionCallAst node) {
    return (node.normalizedName == 'for' || node.normalizedName == 'loop') &&
        (node.arguments.length <= 1 || node.arguments.length == 3);
  }

  bool _isStandaloneLoopDelimiter(String normalizedName) {
    return normalizedName == 'endfor' || normalizedName == 'endloop';
  }

  bool _isBlockJsonForEachSignature(BdfdFunctionCallAst node) {
    return node.normalizedName == 'jsonforeach';
  }

  bool _isStandaloneJsonForEachDelimiter(String normalizedName) {
    return normalizedName == 'endjsonforeach';
  }

  bool _isBlockTrySignature(BdfdFunctionCallAst node) {
    return node.normalizedName == 'try' && node.arguments.isEmpty;
  }

  bool _isStandaloneTryDelimiter(String normalizedName) {
    return normalizedName == 'catch' ||
        normalizedName == 'endtry' ||
        normalizedName == 'error';
  }
}
