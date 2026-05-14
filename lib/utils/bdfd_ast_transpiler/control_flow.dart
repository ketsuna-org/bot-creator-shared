part of '../bdfd_ast_transpiler.dart';

extension _BdfdAstTranspilationScopeControlFlow on _BdfdAstTranspilationScope {
  _ConsumedLoopBlock? _consumeTryCatchBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final tryNode = nodes[startIndex];
    if (tryNode is! BdfdFunctionCallAst || !_isBlockTrySignature(tryNode)) {
      return null;
    }

    final tryNodes = <BdfdAstNode>[];
    final catchNodes = <BdfdAstNode>[];
    List<BdfdAstNode> currentTarget = tryNodes;
    var hasCatchBranch = false;
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockTrySignature(currentNode)) {
          nestingDepth += 1;
          currentTarget.add(currentNode);
          continue;
        }

        if (name == 'endtry') {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            currentTarget.add(currentNode);
            continue;
          }

          final tryActions = _transpileNodesPreservingTempVariables(tryNodes);
          final catchActions = _transpileNodesPreservingTempVariables(
            catchNodes,
          );

          if (catchActions.isEmpty) {
            return _ConsumedLoopBlock(
              precomputedActions: tryActions,
              nextIndex: cursor + 1,
              bodyNodes: const <BdfdAstNode>[],
              iterations: 0,
            );
          }

          final wrappedActions = <Action>[
            Action(
              type: BotCreatorActionType.ifBlock,
              payload: <String, dynamic>{
                'condition.variable': '((error.message))',
                'condition.operator': 'isEmpty',
                'condition.value': '',
                'thenActions':
                    tryActions.map((action) => action.toJson()).toList(),
                'elseIfConditions': const <Map<String, dynamic>>[],
                'elseActions':
                    catchActions.map((action) => action.toJson()).toList(),
              },
            ),
          ];
          return _ConsumedLoopBlock(
            precomputedActions: wrappedActions,
            nextIndex: cursor + 1,
            bodyNodes: const <BdfdAstNode>[],
            iterations: 0,
          );
        }

        if (nestingDepth == 0 && name == 'catch') {
          if (hasCatchBranch) {
            _diagnostics.add(
              BdfdTranspileDiagnostic(
                message: 'Duplicate ${r'$catch'} in ${r'$try'} block.',
                start: currentNode.start,
                end: currentNode.end,
                functionName: currentNode.name,
              ),
            );
            continue;
          }
          hasCatchBranch = true;
          currentTarget = catchNodes;
          continue;
        }
      }

      currentTarget.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message: '${tryNode.name} not closed with ${r'$endtry'}.',
        start: tryNode.start,
        end: tryNode.end,
        functionName: tryNode.name,
      ),
    );

    return _ConsumedLoopBlock(
      precomputedActions: _transpileNodesPreservingTempVariables(tryNodes),
      nextIndex: nodes.length,
      bodyNodes: const <BdfdAstNode>[],
      iterations: 0,
    );
  }

  _ConsumedIfBlock? _consumeIfBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final ifNode = nodes[startIndex];
    if (ifNode is! BdfdFunctionCallAst || !_isBlockIfSignature(ifNode)) {
      return null;
    }

    final thenNodes = <BdfdAstNode>[];
    final elseIfBranches = <_IfBranch>[];
    final elseNodes = <BdfdAstNode>[];

    List<BdfdAstNode> currentTarget = thenNodes;
    var hasElseBranch = false;
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockIfSignature(currentNode)) {
          nestingDepth += 1;
          currentTarget.add(currentNode);
          continue;
        }

        if (name == 'endif') {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            currentTarget.add(currentNode);
            continue;
          }

          final action = _buildIfAction(
            ifNode: ifNode,
            thenNodes: thenNodes,
            elseIfBranches: elseIfBranches,
            elseNodes: elseNodes,
          );
          return _ConsumedIfBlock(action: action, nextIndex: cursor + 1);
        }

        if (nestingDepth == 0 && name == 'elseif') {
          if (hasElseBranch) {
            _diagnostics.add(
              BdfdTranspileDiagnostic(
                message:
                    'Found ${currentNode.name} after ${r'$else'} in if block.',
                start: currentNode.start,
                end: currentNode.end,
                functionName: currentNode.name,
              ),
            );
            continue;
          }

          final branch = _IfBranch(
            conditionNode: currentNode,
            nodes: <BdfdAstNode>[],
          );
          elseIfBranches.add(branch);
          currentTarget = branch.nodes;
          continue;
        }

        if (nestingDepth == 0 && name == 'else') {
          if (hasElseBranch) {
            _diagnostics.add(
              BdfdTranspileDiagnostic(
                message: 'Duplicate ${r'$else'} branch in if block.',
                start: currentNode.start,
                end: currentNode.end,
                functionName: currentNode.name,
              ),
            );
            continue;
          }
          hasElseBranch = true;
          currentTarget = elseNodes;
          continue;
        }
      }

      currentTarget.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message: '${ifNode.name} not closed with ${r'$endif'}.',
        start: ifNode.start,
        end: ifNode.end,
        functionName: ifNode.name,
      ),
    );
    return _ConsumedIfBlock(
      action: _buildIfAction(
        ifNode: ifNode,
        thenNodes: thenNodes,
        elseIfBranches: elseIfBranches,
        elseNodes: elseNodes,
      ),
      nextIndex: nodes.length,
    );
  }

  _ConsumedLoopBlock? _consumeLoopBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final loopNode = nodes[startIndex];
    if (loopNode is! BdfdFunctionCallAst || !_isBlockLoopSignature(loopNode)) {
      return null;
    }

    final loopBodyNodes = <BdfdAstNode>[];
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockLoopSignature(currentNode)) {
          nestingDepth += 1;
          loopBodyNodes.add(currentNode);
          continue;
        }

        if (_isStandaloneLoopDelimiter(name)) {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            loopBodyNodes.add(currentNode);
            continue;
          }

          return _buildConsumedLoop(
            loopNode: loopNode,
            bodyNodes: loopBodyNodes,
            nextIndex: cursor + 1,
          );
        }
      }

      loopBodyNodes.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message:
            '${loopNode.name} not closed with ${r'$endfor'} or ${r'$endloop'}.',
        start: loopNode.start,
        end: loopNode.end,
        functionName: loopNode.name,
      ),
    );

    return _buildConsumedLoop(
      loopNode: loopNode,
      bodyNodes: loopBodyNodes,
      nextIndex: nodes.length,
    );
  }

  _ConsumedLoopBlock _buildConsumedLoop({
    required BdfdFunctionCallAst loopNode,
    required List<BdfdAstNode> bodyNodes,
    required int nextIndex,
  }) {
    // C-style for: $for[init; condition; update]
    if (loopNode.arguments.length == 3) {
      final initStr = _stringifyArgument(loopNode, 0);
      final condStr = _stringifyArgument(loopNode, 1).trim();
      final updateStr = _stringifyArgument(loopNode, 2);

      // Detect runtime placeholders in any of the three parts.
      final hasRuntimeInit = initStr.contains('((');
      final hasRuntimeCond = condStr.contains('((');
      final hasRuntimeUpdate = updateStr.contains('((');
      if (hasRuntimeInit || hasRuntimeCond || hasRuntimeUpdate) {
        // Extract declared variable names from init for body placeholder mapping.
        final varNames = <String>{};
        for (final part in initStr.split(',')) {
          final eqIndex = part.indexOf('=');
          if (eqIndex >= 0) {
            varNames.add(part.substring(0, eqIndex).trim().toLowerCase());
          }
        }
        return _ConsumedLoopBlock(
          nextIndex: nextIndex,
          bodyNodes: bodyNodes,
          iterations: 0,
          isRuntimeLoop: true,
          runtimeInit: initStr,
          runtimeCondition: condStr,
          runtimeUpdate: updateStr,
          runtimeVarNames: varNames,
        );
      }

      final initVars = _parseCStyleLoopInit(initStr, loopNode);
      if (initVars == null) {
        return _ConsumedLoopBlock(
          nextIndex: nextIndex,
          bodyNodes: bodyNodes,
          iterations: 0,
        );
      }

      if (!_validateCStyleCondition(condStr, initVars, loopNode)) {
        return _ConsumedLoopBlock(
          nextIndex: nextIndex,
          bodyNodes: bodyNodes,
          iterations: 0,
        );
      }

      return _ConsumedLoopBlock(
        nextIndex: nextIndex,
        bodyNodes: bodyNodes,
        iterations: 0,
        cStyleInit: initVars,
        cStyleCondition: condStr,
        cStyleUpdate: updateStr,
      );
    }

    // Simple for: $for[n]
    final rawIterations = _stringifyArgument(loopNode, 0).trim();
    if (rawIterations.contains('((')) {
      return _ConsumedLoopBlock(
        nextIndex: nextIndex,
        bodyNodes: bodyNodes,
        iterations: 0,
        isRuntimeLoop: true,
        runtimeIterations: rawIterations,
      );
    }

    final iterations = _parseLoopIterations(loopNode);
    if (iterations == null) {
      return _ConsumedLoopBlock(
        nextIndex: nextIndex,
        bodyNodes: bodyNodes,
        iterations: 0,
      );
    }

    return _ConsumedLoopBlock(
      nextIndex: nextIndex,
      bodyNodes: bodyNodes,
      iterations: iterations,
    );
  }

  static final RegExp _cStyleConditionPattern = RegExp(
    r'^(\w+)\s*(<=|>=|<|>|==|!=)\s*(-?\w+)$',
  );

  Map<String, int>? _parseCStyleLoopInit(String raw, BdfdFunctionCallAst node) {
    final vars = <String, int>{};
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final eqIndex = trimmed.indexOf('=');
      if (eqIndex < 0) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Invalid loop init: expected "variable = value", got "$trimmed".',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        return null;
      }
      final name = trimmed.substring(0, eqIndex).trim().toLowerCase();
      final valueStr = trimmed.substring(eqIndex + 1).trim();
      final value = int.tryParse(valueStr);
      if (value == null) {
        _diagnostics.add(
          BdfdTranspileDiagnostic(
            message:
                'Loop init variable "$name" must be an integer literal, got "$valueStr".',
            start: node.start,
            end: node.end,
            functionName: node.name,
          ),
        );
        return null;
      }
      vars[name] = value;
    }
    if (vars.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: 'Loop init must declare at least one variable.',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return null;
    }
    return vars;
  }

  bool _validateCStyleCondition(
    String raw,
    Map<String, int> initVars,
    BdfdFunctionCallAst node,
  ) {
    final match = _cStyleConditionPattern.firstMatch(raw);
    if (match == null) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              'Invalid loop condition: expected "variable op value", got "$raw".',
          start: node.start,
          end: node.end,
          functionName: node.name,
        ),
      );
      return false;
    }
    return true;
  }

  int _resolveCStyleOperand(String token, Map<String, int> vars) {
    final asVar = vars[token.toLowerCase()];
    if (asVar != null) return asVar;
    return int.tryParse(token) ?? 0;
  }

  bool _evaluateCStyleCondition(String raw, Map<String, int> vars) {
    final match = _cStyleConditionPattern.firstMatch(raw);
    if (match == null) return false;
    final left = _resolveCStyleOperand(match.group(1)!, vars);
    final op = match.group(2)!;
    final right = _resolveCStyleOperand(match.group(3)!, vars);
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

  void _applyCStyleLoopUpdate(String raw, Map<String, int> vars) {
    for (final part in raw.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.endsWith('++')) {
        final name =
            trimmed.substring(0, trimmed.length - 2).trim().toLowerCase();
        vars[name] = (vars[name] ?? 0) + 1;
      } else if (trimmed.endsWith('--')) {
        final name =
            trimmed.substring(0, trimmed.length - 2).trim().toLowerCase();
        vars[name] = (vars[name] ?? 0) - 1;
      } else if (trimmed.contains('+=')) {
        final sides = trimmed.split('+=');
        final name = sides[0].trim().toLowerCase();
        final value = int.tryParse(sides[1].trim()) ?? 0;
        vars[name] = (vars[name] ?? 0) + value;
      } else if (trimmed.contains('-=')) {
        final sides = trimmed.split('-=');
        final name = sides[0].trim().toLowerCase();
        final value = int.tryParse(sides[1].trim()) ?? 0;
        vars[name] = (vars[name] ?? 0) - value;
      } else if (trimmed.contains('*=')) {
        final sides = trimmed.split('*=');
        final name = sides[0].trim().toLowerCase();
        final value = int.tryParse(sides[1].trim()) ?? 1;
        vars[name] = (vars[name] ?? 0) * value;
      }
    }
  }

  List<Action> _transpileCStyleLoop({
    required List<BdfdAstNode> bodyNodes,
    required Map<String, int> initVars,
    required String condition,
    required String update,
  }) {
    if (bodyNodes.isEmpty) return const <Action>[];

    final previousIndex = _loopIterationIndex;
    final previousVars = Map<String, int>.from(_loopVariables);
    _loopDepth += 1;
    _loopVariables = Map<String, int>.from(initVars);

    final actions = <Action>[];
    var iterationCount = 0;

    while (_evaluateCStyleCondition(condition, _loopVariables) &&
        iterationCount < _maxSupportedLoopIterations) {
      _loopIterationIndex = iterationCount;
      final iterActions = _transpileNodes(bodyNodes);
      for (final a in iterActions) {
        a.payload['_debugLoopDepth'] = _loopDepth;
        a.payload['_debugLoopIteration'] = iterationCount;
      }
      actions.addAll(iterActions);
      _applyCStyleLoopUpdate(update, _loopVariables);
      iterationCount++;
    }

    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
    _loopVariables = previousVars;

    return actions;
  }

  void _applyCStyleLoopBodyToResponse({
    required List<BdfdAstNode> bodyNodes,
    required Map<String, int> initVars,
    required String condition,
    required String update,
    required _PendingResponse response,
  }) {
    if (bodyNodes.isEmpty) return;

    final previousIndex = _loopIterationIndex;
    final previousVars = Map<String, int>.from(_loopVariables);
    _loopDepth += 1;
    _loopVariables = Map<String, int>.from(initVars);

    var iterationCount = 0;

    while (_evaluateCStyleCondition(condition, _loopVariables) &&
        iterationCount < _maxSupportedLoopIterations) {
      _loopIterationIndex = iterationCount;
      for (final node in bodyNodes) {
        if (node is BdfdTextAst) {
          response.appendContent(node.value);
          continue;
        }
        if (node is! BdfdFunctionCallAst) continue;
        if (_applyResponseMutation(node, response)) continue;
        final inlineResult = _stringifyInlineFunction(node);
        if (inlineResult != null) {
          response.appendContent(inlineResult);
          continue;
        }
        final placeholder = _inlineRuntimePlaceholder(node);
        if (placeholder != null) {
          response.appendContent(placeholder);
          continue;
        }
        _transpileStandaloneFunction(node, pendingResponse: response);
      }
      _applyCStyleLoopUpdate(update, _loopVariables);
      iterationCount++;
    }

    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
    _loopVariables = previousVars;
  }

  int? _parseLoopIterations(BdfdFunctionCallAst loopNode) {
    final raw = _stringifyArgument(loopNode, 0).trim();
    if (raw.isEmpty) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${loopNode.name} requires an iteration count.',
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return null;
    }

    final parsed = int.tryParse(raw);
    if (parsed == null) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${loopNode.name} iteration count must be an integer literal.',
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return null;
    }

    if (parsed < 0) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message: '${loopNode.name} iteration count must be non-negative.',
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return null;
    }

    if (parsed > _maxSupportedLoopIterations) {
      _diagnostics.add(
        BdfdTranspileDiagnostic(
          message:
              '${loopNode.name} iteration count $parsed exceeds limit $_maxSupportedLoopIterations and will be capped.',
          severity: BdfdTranspileDiagnosticSeverity.warning,
          start: loopNode.start,
          end: loopNode.end,
          functionName: loopNode.name,
        ),
      );
      return _maxSupportedLoopIterations;
    }

    return parsed;
  }

  List<Action> _transpileLoopIterations({
    required List<BdfdAstNode> bodyNodes,
    required int iterations,
  }) {
    if (iterations <= 0 || bodyNodes.isEmpty) {
      return const <Action>[];
    }

    final previousIndex = _loopIterationIndex;
    _loopDepth += 1;
    final actions = <Action>[];
    for (var index = 0; index < iterations; index++) {
      _loopIterationIndex = index;
      final iterActions = _transpileNodes(bodyNodes);
      for (final a in iterActions) {
        a.payload['_debugLoopDepth'] = _loopDepth;
        a.payload['_debugLoopIteration'] = index;
      }
      actions.addAll(iterActions);
    }
    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
    return actions;
  }

  /// Builds a runtime [BotCreatorActionType.forLoop] action whose body is
  /// transpiled with loop-variable references emitted as `((_loop.var.{name}))`
  /// or `((_loop.index))` / `((_loop.count))` placeholders that the handler
  /// will resolve on each iteration.
  Action _buildRuntimeForLoopAction(_ConsumedLoopBlock consumed) {
    // Save transpiler state.
    final previousIndex = _loopIterationIndex;
    final previousVars = Map<String, int>.from(_loopVariables);
    final previousDepth = _loopDepth;

    // Enter a special "runtime loop" scope: set _loopDepth so that $i / $loopCount /
    // C-style variable names are recognised, but map them to placeholder strings instead
    // of concrete integers. We achieve this by *not* touching _loopIterationIndex (unused
    // at runtime) and by populating _loopVariables with a sentinel that we intercept in
    // _stringifyInlineFunction via a new flag.
    _loopDepth += 1;
    _runtimeLoopVarNames = consumed.runtimeVarNames ?? const <String>{};
    _loopVariables = <String, int>{};
    // Seed _loopVariables so the normal `_loopVariables[name]` lookup falls through
    // but `_isInlineOnlyFunction` still recognises the names.
    for (final name in _runtimeLoopVarNames!) {
      _loopVariables[name] = 0; // sentinel – overridden by placeholder path
    }

    // Save and restore _lastDeferredJsonResultKeyPrefix around the body so
    // that JSON operations inside the loop body cannot leak their prefix into
    // the outer scope after $endfor.
    final savedDeferredKey = _lastDeferredJsonResultKeyPrefix;
    final bodyActions = _transpileNodesPreservingTempVariables(
      consumed.bodyNodes,
    );
    _lastDeferredJsonResultKeyPrefix = savedDeferredKey;

    // Restore transpiler state.
    _runtimeLoopVarNames = null;
    _loopDepth = previousDepth;
    _loopIterationIndex = previousIndex;
    _loopVariables = previousVars;

    final payload = <String, dynamic>{
      'bodyActions': bodyActions.map((action) => action.toJson()).toList(),
      'maxIterations': _maxSupportedLoopIterations,
    };

    if (consumed.isRuntimeCStyleLoop) {
      payload['mode'] = 'cstyle';
      payload['init'] = consumed.runtimeInit!;
      payload['condition'] = consumed.runtimeCondition!;
      payload['update'] = consumed.runtimeUpdate!;
      payload['varNames'] =
          consumed.runtimeVarNames?.toList(growable: false) ?? const <String>[];
    } else {
      payload['mode'] = 'simple';
      payload['iterations'] = consumed.runtimeIterations!;
    }

    return Action(type: BotCreatorActionType.forLoop, payload: payload);
  }

  // ── $jsonForEach / $endJsonForEach ──────────────────────────────────────

  _ConsumedJsonForEachBlock? _consumeJsonForEachBlock({
    required List<BdfdAstNode> nodes,
    required int startIndex,
  }) {
    final feNode = nodes[startIndex];
    if (feNode is! BdfdFunctionCallAst ||
        !_isBlockJsonForEachSignature(feNode)) {
      return null;
    }

    final bodyNodes = <BdfdAstNode>[];
    var nestingDepth = 0;

    for (var cursor = startIndex + 1; cursor < nodes.length; cursor++) {
      final currentNode = nodes[cursor];

      if (currentNode is BdfdFunctionCallAst) {
        final name = currentNode.normalizedName;

        if (_isBlockJsonForEachSignature(currentNode)) {
          nestingDepth += 1;
          bodyNodes.add(currentNode);
          continue;
        }

        if (_isStandaloneJsonForEachDelimiter(name)) {
          if (nestingDepth > 0) {
            nestingDepth -= 1;
            bodyNodes.add(currentNode);
            continue;
          }

          return _buildJsonForEachAction(
            feNode: feNode,
            bodyNodes: bodyNodes,
            nextIndex: cursor + 1,
          );
        }
      }

      bodyNodes.add(currentNode);
    }

    _diagnostics.add(
      BdfdTranspileDiagnostic(
        message: '${feNode.name} not closed with ${r'$endJsonForEach'}.',
        start: feNode.start,
        end: feNode.end,
        functionName: feNode.name,
      ),
    );

    return _buildJsonForEachAction(
      feNode: feNode,
      bodyNodes: bodyNodes,
      nextIndex: nodes.length,
    );
  }

  _ConsumedJsonForEachBlock _buildJsonForEachAction({
    required BdfdFunctionCallAst feNode,
    required List<BdfdAstNode> bodyNodes,
    required int nextIndex,
  }) {
    // Extract the JSON path argument (all args form the path).
    final pathSegments = <String>[];
    for (var i = 0; i < feNode.arguments.length; i++) {
      final raw = _stringifyArgument(feNode, i).trim();
      if (raw.isNotEmpty) pathSegments.add(raw);
    }

    // Save transpiler state.
    final previousDepth = _loopDepth;
    final previousVars = Map<String, int>.from(_loopVariables);
    final previousRuntimeVarNames = _runtimeLoopVarNames;

    _loopDepth += 1;
    _runtimeLoopVarNames = const <String>{'jsonkey', 'jsonvalue', 'jsonindex'};
    // Seed _loopVariables so the inline resolver recognises these names.
    _loopVariables = <String, int>{};
    for (final name in _runtimeLoopVarNames!) {
      _loopVariables[name] = 0;
    }

    final savedDeferredKey = _lastDeferredJsonResultKeyPrefix;
    final bodyActions = _transpileNodesPreservingTempVariables(bodyNodes);
    _lastDeferredJsonResultKeyPrefix = savedDeferredKey;

    // Restore transpiler state.
    _runtimeLoopVarNames = previousRuntimeVarNames;
    _loopDepth = previousDepth;
    _loopVariables = previousVars;

    final payload = <String, dynamic>{
      'path': pathSegments,
      'bodyActions': bodyActions.map((a) => a.toJson()).toList(),
      'maxIterations': _maxSupportedLoopIterations,
      if (_hasJsonContext && _jsonContext != null)
        'source': jsonEncode(_jsonContext),
    };

    return _ConsumedJsonForEachBlock(
      action: Action(
        type: BotCreatorActionType.jsonForEachLoop,
        payload: payload,
      ),
      nextIndex: nextIndex,
    );
  }

  /// Returns `true` when every node in [bodyNodes] is either plain text,
  /// an inline-only function, or a response-mutation function.  In that case
  /// the loop body can be unrolled directly into the current pending response
  /// instead of flushing the response and creating separate actions.
  bool _isResponseOnlyLoopBody(
    List<BdfdAstNode> bodyNodes, {
    Set<String>? extraInlineNames,
  }) {
    for (final node in bodyNodes) {
      if (node is BdfdTextAst) continue;
      if (node is! BdfdFunctionCallAst) return false;
      final name = node.normalizedName;
      if (_isInlineOnlyNode(node)) continue;
      if (_inlineRuntimeVariables.containsKey(name)) continue;
      if (_isResponseMutationFunction(name)) continue;
      // JSON helpers that mutate compile-time state only (no action produced).
      if (_isJsonMutationFunction(name)) continue;
      if (extraInlineNames != null && extraInlineNames.contains(name)) continue;
      return false;
    }
    return true;
  }

  bool _isResponseMutationFunction(String normalizedName) {
    switch (normalizedName) {
      case 'nomention':
      case 'title':
      case 'description':
      case 'color':
      case 'footer':
      case 'footericon':
      case 'thumbnail':
      case 'image':
      case 'author':
      case 'authoricon':
      case 'authorurl':
      case 'addfield':
      case 'addtimestamp':
      case 'embeddedurl':
      case 'addcontainer':
      case 'addsection':
      case 'addthumbnail':
      case 'addmediagallery':
      case 'addbutton':
      case 'addbuttoncv2':
      case 'addselectmenuoption':
      case 'newselectmenu':
      case 'editselectmenu':
      case 'editselectmenuoption':
      case 'editbutton':
      case 'removeallcomponents':
      case 'removebuttons':
      case 'removecomponent':
      case 'addseparator':
      case 'addtextdisplay':
      case 'addactionrow':
      case 'addmediagalleryitem':
      case 'addmentionableselect':
      case 'adduserselect':
      case 'addroleselect':
      case 'addchannelselect':
      case 'addstringselect':
      case 'addstringselectoption':
      case 'ephemeral':
      case 'allowmention':
      case 'allowusermentions':
      case 'tts':
      case 'removelinks':
      case 'allowrolementions':
      case 'suppresserrors':
      case 'embedsuppresserrors':
        return true;
      default:
        return false;
    }
  }

  bool _isJsonMutationFunction(String normalizedName) {
    switch (normalizedName) {
      case 'jsonparse':
      case 'jsonset':
      case 'jsonsetstring':
      case 'jsonunset':
      case 'jsonclear':
      case 'jsonarray':
      case 'jsonarrayappend':
      case 'jsonarrayunshift':
      case 'jsonarraysort':
      case 'jsonarrayreverse':
        return true;
      default:
        return false;
    }
  }

  /// Applies the loop body's mutations directly to [response] for each
  /// iteration, without flushing or creating separate actions.
  void _applyLoopBodyToResponse({
    required List<BdfdAstNode> bodyNodes,
    required int iterations,
    required _PendingResponse response,
  }) {
    if (iterations <= 0 || bodyNodes.isEmpty) return;

    final previousIndex = _loopIterationIndex;
    _loopDepth += 1;
    for (var index = 0; index < iterations; index++) {
      _loopIterationIndex = index;
      for (final node in bodyNodes) {
        if (node is BdfdTextAst) {
          response.appendContent(node.value);
          continue;
        }
        if (node is! BdfdFunctionCallAst) continue;
        if (_applyResponseMutation(node, response)) continue;
        // Inline function or runtime variable — resolve and append.
        final inlineResult = _stringifyInlineFunction(node);
        if (inlineResult != null) {
          response.appendContent(inlineResult);
          continue;
        }
        final placeholder = _inlineRuntimePlaceholder(node);
        if (placeholder != null) {
          response.appendContent(placeholder);
          continue;
        }
        // JSON mutation functions — apply side-effect only.
        _transpileStandaloneFunction(node, pendingResponse: response);
      }
    }
    _loopDepth -= 1;
    _loopIterationIndex = previousIndex;
  }

  Action _buildIfAction({
    required BdfdFunctionCallAst ifNode,
    required List<BdfdAstNode> thenNodes,
    required List<_IfBranch> elseIfBranches,
    required List<BdfdAstNode> elseNodes,
  }) {
    final condition = _parseCondition(_stringifyArgument(ifNode, 0), ifNode);
    final conditionDeferredJson = _flushDeferredJson();
    if (conditionDeferredJson != null) {
      _enqueuePendingConditionAction(conditionDeferredJson);
    }

    // Save and restore _lastDeferredJsonResultKeyPrefix around each branch so
    // that JSON operations inside a branch (e.g. a nested $jsonParse) cannot
    // leak their prefix back into the outer scope after $endif.
    final savedDeferredKey = _lastDeferredJsonResultKeyPrefix;

    final thenActions = _transpileNodesPreservingTempVariables(thenNodes);
    _lastDeferredJsonResultKeyPrefix = savedDeferredKey;

    final elseActions = _transpileNodesPreservingTempVariables(elseNodes);
    _lastDeferredJsonResultKeyPrefix = savedDeferredKey;

    final elseIfPayload = elseIfBranches
        .map((branch) {
          final elseIfCondition = _parseCondition(
            _stringifyArgument(branch.conditionNode, 0),
            branch.conditionNode,
          );
          final branchActions = _transpileNodesPreservingTempVariables(
            branch.nodes,
          );
          _lastDeferredJsonResultKeyPrefix = savedDeferredKey;
          return <String, dynamic>{
            ...elseIfCondition.toPayload(prefix: 'condition.'),
            'actions': branchActions.map((action) => action.toJson()).toList(),
          };
        })
        .toList(growable: false);

    return Action(
      type: BotCreatorActionType.ifBlock,
      payload: <String, dynamic>{
        ...condition.toPayload(prefix: 'condition.'),
        'thenActions': thenActions.map((action) => action.toJson()).toList(),
        'elseIfConditions': elseIfPayload,
        'elseActions': elseActions.map((action) => action.toJson()).toList(),
      },
    );
  }
}
