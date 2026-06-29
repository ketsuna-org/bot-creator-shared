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
  _BdfdAstTranspilationScope({required this._diagnostics});

  final List<BdfdTranspileDiagnostic> _diagnostics;
  final Map<String, String> _pendingHttpHeaders = <String, String>{};
  int _httpRequestCounter = 0;
  int _threadActionCounter = 0;
  int _permissionCheckCounter = 0;
  int _callWorkflowCounter = 0;
  int _createEmojiCounter = 0;
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

  // ── Deferred (runtime) Image state ─────────────────────────────────────────
  /// When true, image canvas operations are being collected into a deferred
  /// [runtimeImageBlock] action. Started by `$canvasCreate` and flushed when
  /// any non-canvas function is encountered.
  bool _deferredImageMode = false;
  final List<Map<String, dynamic>> _deferredImageOps = <Map<String, dynamic>>[];
  int _deferredImageBlockCounter = 0;
  String? _deferredImageResultKeyPrefix;

  List<String> _textSplitParts = <String>[];
  String? _useChannelId;
  bool _suppressErrors = false;
  String? _suppressErrorsMessage;
  Map<String, dynamic>? _suppressErrorsEmbed;

  /// Number of actions already emitted when [_suppressErrors] was first set.
  /// Used to avoid wrapping actions that precede $suppressErrors.
  int? _suppressErrorsActionCount;
  bool _enableDecimals = false;
  int _loopIterationIndex = 0;
  int _loopDepth = 0;
  Map<String, int> _loopVariables = <String, int>{};
  Map<String, String> _loopStringVariables = <String, String>{};
  Set<String>? _runtimeLoopVarNames;

  // ── User-defined functions ($func[...]...$funcEnd) ───────────────────────
  final Map<String, _BdfdUserFunction> _userFunctions =
      <String, _BdfdUserFunction>{};
  Map<String, String> _funcArgScope = <String, String>{};
  String? _funcReturnValue;
  int _funcCallDepth = 0;
  final List<Map<String, dynamic>> _pendingModalComponents =
      <Map<String, dynamic>>[];

  /// Tracks the custom ID of the most recently added modal radio/checkbox
  /// group so that subsequent `addradiogroupoption` /
  /// `addcheckboxgroupoption` calls know where to append options.
  String? _pendingModalGroupId;

  // ── Sticky response flags ─────────────────────────────────────────────────
  /// Flags that survive across branch transpilation (IF/ELSE, loops).
  /// When a new [_PendingResponse] is created inside a branch, it inherits
  /// these flags so that `$ephemeral` / `$reply` / `$tts` applied before
  /// the control-flow block are honored by message actions inside the block.
  bool _stickyEphemeral = false;
  bool _stickyTts = false;
  String? _stickyReplyMessageId;
  String? _stickyReplyChannelId;

  /// Resets all sticky response flags — called after a message is produced
  /// (either via $sendMessage or via buildAction flush) so that the next
  /// message starts with fresh flags.
  void _consumeStickyFlags() {
    _stickyEphemeral = false;
    _stickyTts = false;
    _stickyReplyMessageId = null;
    _stickyReplyChannelId = null;
  }

  List<Action> transpileScript(BdfdScriptAst script) {
    return _transpileNodes(script.nodes);
  }

  List<Action> _transpileNodes(List<BdfdAstNode> nodes) {
    _conditionActionStack.add(<Action>[]);
    final actions = <Action>[];
    final pendingResponse = _PendingResponse()
      .._ephemeral = _stickyEphemeral
      .._tts = _stickyTts;
    if (_stickyReplyMessageId != null) {
      pendingResponse._replyMessageId = _stickyReplyMessageId;
      pendingResponse._replyChannelId = _stickyReplyChannelId;
    }

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

          if (pendingResponse.hasPendingContent) {
            final flushed = pendingResponse.buildAction(
              channelId: _useChannelId,
            );
            if (flushed != null) {
              actions.add(flushed);
              _consumeStickyFlags();
            }
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
            if (pendingResponse.hasPendingContent) {
              final flushed = pendingResponse.buildAction(
                channelId: _useChannelId,
              );
              if (flushed != null) {
                actions.add(flushed);
                _consumeStickyFlags();
              }
            }
            actions.add(_buildRuntimeForLoopAction(consumed));
            index = consumed.nextIndex;
            continue;
          }

          if (consumed.isRuntimeListIteration) {
            final runtimeListDeferredJson = _flushDeferredJson();
            if (runtimeListDeferredJson != null) {
              actions.add(runtimeListDeferredJson);
            }
            if (pendingResponse.hasPendingContent) {
              final flushed = pendingResponse.buildAction(
                channelId: _useChannelId,
              );
              if (flushed != null) {
                actions.add(flushed);
                _consumeStickyFlags();
              }
            }
            actions.add(_buildRuntimeListForLoopAction(consumed));
            index = consumed.nextIndex;
            continue;
          }

          if (consumed.isListIteration) {
            final extraNames = <String>{consumed.listVarName!};
            if (_isResponseOnlyLoopBody(
              consumed.bodyNodes,
              extraInlineNames: extraNames,
            )) {
              _applyListIterationLoopBodyToResponse(
                bodyNodes: consumed.bodyNodes,
                varName: consumed.listVarName!,
                values: consumed.listValues!,
                response: pendingResponse,
              );
            } else {
              final flushed = pendingResponse.buildAction(
                channelId: _useChannelId,
              );
              if (flushed != null) {
                actions.add(flushed);
                _consumeStickyFlags();
              }
              actions.addAll(
                _transpileListIterationLoop(
                  bodyNodes: consumed.bodyNodes,
                  varName: consumed.listVarName!,
                  values: consumed.listValues!,
                ),
              );
            }
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
                _consumeStickyFlags();
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
              _consumeStickyFlags();
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
            _consumeStickyFlags();
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
            _consumeStickyFlags();
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

        // $func[name;params...] ... $funcEnd — user-defined function.
        if (_isBlockFuncSignature(node)) {
          final consumed = _consumeFuncBlock(nodes: nodes, startIndex: index);
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

        if (_isStandaloneTryDelimiter(node)) {
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

        if (_isStandaloneFuncEndDelimiter(node)) {
          _diagnostics.add(
            BdfdTranspileDiagnostic(
              message:
                  'Unexpected ${node.name} without a matching surrounding ${r'$func'}[] block.',
              start: node.start,
              end: node.end,
              functionName: node.name,
            ),
          );
          index += 1;
          continue;
        }

        // Inside a list-iteration loop, loop string variables (e.g. $item in
        // $for[item;a;b;c]) shadow any BDFD function of the same name (such as
        // $color, $title, etc.). Resolve them BEFORE response mutation checks.
        if (_loopDepth > 0 &&
            _loopStringVariables.containsKey(node.normalizedName)) {
          final isEffectivelyEmptyArgs = node.arguments.isEmpty ||
              (node.arguments.length == 1 &&
                  node.arguments.first.isEmpty);
          if (isEffectivelyEmptyArgs) {
            pendingResponse
                .appendContent(_loopStringVariables[node.normalizedName]!);
            index += 1;
            continue;
          }
        }

        if (_applyResponseMutation(node, pendingResponse)) {
          final wasSuppressErrors = _suppressErrors;
          actions.addAll(_drainDeferredInlineActions());
          // Record the split point when suppressErrors is first activated.
          // Actions emitted before this point should NOT be wrapped.
          if (_suppressErrors && !wasSuppressErrors) {
            _suppressErrorsActionCount ??= actions.length;
          }
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
        final inlineReplacement = allowsTopLevelInline
            ? _stringifyInlineFunction(node)
            : null;
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
            _consumeStickyFlags();
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

        // Flush deferred image block when a non-canvas function is encountered.
        if (!_isImageCanvasFunction(node.normalizedName)) {
          final deferredImage = _flushDeferredImage();
          if (deferredImage != null) actions.add(deferredImage);
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

      // Flush any remaining deferred image block.
      final trailingDeferredImage = _flushDeferredImage();
      if (trailingDeferredImage != null) {
        actions.add(trailingDeferredImage);
      }

      final trailingResponse = pendingResponse.buildAction(
        channelId: _useChannelId,
      );
      if (trailingResponse != null) {
        actions.add(trailingResponse);
        _consumeStickyFlags();
      }

      if (_suppressErrors && actions.isNotEmpty) {
        final splitIndex = _suppressErrorsActionCount ?? 0;
        // If suppressErrors was set after all actions were emitted, don't wrap anything.
        if (splitIndex >= actions.length) {
          return actions;
        }
        final preActions = actions.sublist(0, splitIndex);
        final postActions = actions.sublist(splitIndex);
        final suppressBlock = Action(
          type: BotCreatorActionType.ifBlock,
          payload: <String, dynamic>{
            'condition.variable': '__suppressErrors_guard__',
            'condition.operator': 'equals',
            'condition.value': '__suppressErrors_guard__',
            'thenActions': postActions
                .map((action) => action.toJson())
                .toList(),
            'elseIfConditions': const <Map<String, dynamic>>[],
            'elseActions': const <Map<String, dynamic>>[],
            'suppressErrors': true,
            if (_suppressErrorsMessage != null)
              'suppressErrorsMessage': _suppressErrorsMessage,
            if (_suppressErrorsEmbed != null)
              'suppressErrorsEmbed': _suppressErrorsEmbed,
          },
        );
        return <Action>[...preActions, suppressBlock];
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
    // Accept $for / $loop with any argument count. The specific form
    // (simple count, C-style, or list iteration) is disambiguated in
    // _buildConsumedLoop.
    return node.normalizedName == 'for' || node.normalizedName == 'loop';
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

  bool _isStandaloneTryDelimiter(BdfdFunctionCallAst node) {
    final name = node.normalizedName;
    if (name == 'error') {
      // $error without arguments is a delimiter; $error[message] is an inline function.
      return node.arguments.isEmpty;
    }
    return name == 'catch' || name == 'endtry';
  }

  bool _isBlockFuncSignature(BdfdFunctionCallAst node) {
    return node.normalizedName == 'func' && node.arguments.isNotEmpty;
  }

  bool _isStandaloneFuncEndDelimiter(BdfdFunctionCallAst node) {
    return node.normalizedName == 'funcend';
  }

  /// Consumes a `$func[name;param1;param2;...] ... $funcEnd` block.
  /// Stores the function definition and produces no actions.
  _ConsumedFuncBlock _consumeFuncBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final funcNode = nodes[startIndex] as BdfdFunctionCallAst;
    final funcName = _stringifyArgument(funcNode, 0).trim().toLowerCase();
    final paramNames = <String>[];
    for (var i = 1; i < funcNode.arguments.length; i++) {
      final param = _stringifyArgument(funcNode, i).trim().toLowerCase();
      if (param.isNotEmpty) {
        paramNames.add(param);
      }
    }

    final bodyNodes = <BdfdAstNode>[];
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockFuncSignature(currentNode)) {
          nestingDepth += 1;
          bodyNodes.add(currentNode);
          continue;
        }

        if (name == 'funcend') {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            bodyNodes.add(currentNode);
            continue;
          }

          // End of function definition — store it.
          if (funcName.isNotEmpty) {
            _userFunctions[funcName] = _BdfdUserFunction(
              name: funcName,
              paramNames: paramNames,
              bodyNodes: List<BdfdAstNode>.unmodifiable(bodyNodes),
            );
          }

          return _ConsumedFuncBlock(nextIndex: cursor + 1);
        }
      }

      bodyNodes.add(currentNode);
    }

    // No $funcEnd found — diagnostic + store anyway.
    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message: '${funcNode.name} not closed with ${r'$funcEnd'}.',
        start: funcNode.start,
        end: funcNode.end,
        functionName: funcNode.name,
      ),
    );

    if (funcName.isNotEmpty) {
      _userFunctions[funcName] = _BdfdUserFunction(
        name: funcName,
        paramNames: paramNames,
        bodyNodes: List<BdfdAstNode>.unmodifiable(bodyNodes),
      );
    }

    return _ConsumedFuncBlock(nextIndex: nodes.length);
  }
}
