part of '../bdfd_ast_transpiler.dart';

// ── Image Canvas Function Transpilation ──────────────────────────────────────
//
// Canvas functions ($canvasCreate, $canvasLoadImage, etc.) are collected into
// a deferred image block. The first $canvasCreate call starts the block,
// subsequent canvas functions add operations, and the block is flushed when
// any non-canvas function is encountered.

extension _BdfdAstTranspilationScopeImageCanvas on _BdfdAstTranspilationScope {
  /// Returns true if [normalizedName] is an image canvas function.
  bool _isImageCanvasFunction(String normalizedName) {
    switch (normalizedName) {
      case 'canvascreate':
      case 'canvasloadimage':
      case 'canvasdrawtext':
      case 'canvasdrawcircle':
      case 'canvasdrawrect':
        return true;
      default:
        return false;
    }
  }

  /// Starts or resets the deferred image block with a canvas create operation.
  /// Auto-flushes any previous image block before starting a new one.
  void _canvasCreate(BdfdFunctionCallAst node) {
    // Auto-flush previous image block if one is pending.
    if (_deferredImageMode) {
      final previous = _flushDeferredImage();
      if (previous != null) {
        _deferredInlineActions.add(previous);
      }
    }

    _deferredImageMode = true;
    _deferredImageOps.clear();
    _deferredImageResultKeyPrefix =
        'rtImage_${_deferredImageBlockCounter++}';

    final width = _stringifyArgument(node, 0);
    final height = _stringifyArgument(node, 1);
    final color = _stringifyArgument(node, 2);

    _deferredImageOps.add(<String, dynamic>{
      'op': 'create',
      'width': width,
      'height': height,
      'color': color,
    });
  }

  /// Adds a loadImage operation to the deferred image block.
  /// Operates on the image from the current runtimeImageBlock or from a
  /// data URL.
  void _canvasLoadImage(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    final dataUrl = _stringifyArgument(node, 0);

    _deferredImageOps.add(<String, dynamic>{
      'op': 'loadImage',
      'dataUrl': dataUrl,
    });
  }

  /// Adds a drawText operation to the deferred image block.
  void _canvasDrawText(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    final text = _stringifyArgument(node, 0);
    final x = _stringifyArgument(node, 1);
    final y = _stringifyArgument(node, 2);
    final fontSize = _stringifyArgument(node, 3);
    final color = _stringifyArgument(node, 4);

    _deferredImageOps.add(<String, dynamic>{
      'op': 'drawText',
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color,
    });
  }

  /// Adds a drawCircle operation to the deferred image block.
  void _canvasDrawCircle(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    final x = _stringifyArgument(node, 0);
    final y = _stringifyArgument(node, 1);
    final radius = _stringifyArgument(node, 2);
    final color = _stringifyArgument(node, 3);
    final fill = _stringifyArgument(node, 4);

    _deferredImageOps.add(<String, dynamic>{
      'op': 'drawCircle',
      'x': x,
      'y': y,
      'radius': radius,
      'color': color,
      'fill': fill,
    });
  }

  /// Adds a drawRect operation to the deferred image block.
  void _canvasDrawRect(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    final x = _stringifyArgument(node, 0);
    final y = _stringifyArgument(node, 1);
    final width = _stringifyArgument(node, 2);
    final height = _stringifyArgument(node, 3);
    final color = _stringifyArgument(node, 4);
    final fill = _stringifyArgument(node, 5);

    _deferredImageOps.add(<String, dynamic>{
      'op': 'drawRect',
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'color': color,
      'fill': fill,
    });
  }

  /// Flushes any pending deferred image operations into a
  /// [BotCreatorActionType.runtimeImageBlock] action and resets the state.
  Action? _flushDeferredImage() {
    if (!_deferredImageMode) return null;
    final action = Action(
      type: BotCreatorActionType.runtimeImageBlock,
      key: _deferredImageResultKeyPrefix,
      payload: <String, dynamic>{
        'operations': List<Map<String, dynamic>>.from(_deferredImageOps),
      },
    );
    _deferredImageMode = false;
    _deferredImageOps.clear();
    _deferredImageResultKeyPrefix = null;
    return action;
  }
}
