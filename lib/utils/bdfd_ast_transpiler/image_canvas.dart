part of '../bdfd_ast_transpiler.dart';

// ── Image Canvas Function Transpilation ──────────────────────────────────────
//
// Canvas functions ($canvasCreate, $canvasLoadImage, etc.) are collected into
// a deferred image block. The first $canvasCreate call starts the block,
// subsequent canvas functions add operations, and the block is flushed when
// any non-canvas function is encountered or when $attachImage is called.

extension _BdfdAstTranspilationScopeImageCanvas on _BdfdAstTranspilationScope {
  /// Returns true if [normalizedName] is an image canvas function.
  bool _isImageCanvasFunction(String normalizedName) {
    switch (normalizedName) {
      case 'canvascreate':
      case 'canvasloadimage':
      case 'canvasdrawtext':
      case 'canvasdrawcircle':
      case 'canvasdrawrect':
      case 'canvascompositeimage':
      case 'attachimage':
        return true;
      default:
        return false;
    }
  }

  /// Starts or resets the deferred image block with a canvas create operation.
  /// Auto-flushes any previous image block before starting a new one.
  ///
  /// Signature: $canvasCreate[name;width;height;color]
  /// - name: identifier for the canvas (used by $attachImage)
  /// - width, height: canvas dimensions
  /// - color: background color (optional, default white)
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

    final name = _stringifyArgument(node, 0);
    final width = _stringifyArgument(node, 1);
    final height = _stringifyArgument(node, 2);
    final color = _stringifyArgument(node, 3);

    _deferredImageResultKeyPrefix =
        'rtImage_${_deferredImageBlockCounter++}';

    _deferredImageOps.add(<String, dynamic>{
      'op': 'create',
      'name': name,
      'width': width,
      'height': height,
      'color': color,
    });
  }

  /// Finalizes the current canvas and stores it in a temporary variable
  /// so that respondWithMessage can attach it as a file.
  ///
  /// Signature: $attachImage[name]
  /// - name: the filename for the attachment (without extension)
  ///
  /// At runtime, the image bytes are accessible via ((_canvasAttachment_name))
  /// and attachment://name.png can be used in embeds.
  void _canvasAttachImage(BdfdFunctionCallAst node) {
    final name = _stringifyArgument(node, 0).trim();

    // Flush the deferred image block.
    final imageAction = _flushDeferredImage();
    if (imageAction != null) {
      _deferredInlineActions.add(imageAction);
    }

    final key = imageAction?.key ?? _deferredImageResultKeyPrefix;
    final attachmentName =
        name.isNotEmpty ? name : (key?.replaceAll('rtImage_', 'canvas') ?? 'canvas');

    // Emit a setTemporaryVariable action that stores the canvas output.
    // respondWithMessage will read _canvasAttachment_<name> at runtime
    // and include the decoded image as a file attachment.
    _deferredInlineActions.add(Action(
      type: BotCreatorActionType.setTemporaryVariable,
      payload: <String, dynamic>{
        'key': '_canvasAttachment_$attachmentName',
        'value': '(($key))',
        'valueType': 'string',
      },
    ));
  }

  /// Adds a loadImage operation to the deferred image block.
  void _canvasLoadImage(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;
    final url = _stringifyArgument(node, 0);

    _deferredImageOps.add(<String, dynamic>{
      'op': 'loadImage',
      'url': url,
    });
  }

  /// Adds a compositeImage operation (overlay image at position).
  /// Signature: $canvasCompositeImage[url;x;y;width;height;shape]
  void _canvasCompositeImage(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    _deferredImageOps.add(<String, dynamic>{
      'op': 'compositeImage',
      'url': _stringifyArgument(node, 0),
      'x': _stringifyArgument(node, 1),
      'y': _stringifyArgument(node, 2),
      'width': _stringifyArgument(node, 3),
      'height': _stringifyArgument(node, 4),
      if (node.arguments.length > 5) 'shape': _stringifyArgument(node, 5),
    });
  }

  /// Adds a drawText operation to the deferred image block.
  void _canvasDrawText(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    _deferredImageOps.add(<String, dynamic>{
      'op': 'drawText',
      'text': _stringifyArgument(node, 0),
      'x': _stringifyArgument(node, 1),
      'y': _stringifyArgument(node, 2),
      'fontSize': _stringifyArgument(node, 3),
      'color': _stringifyArgument(node, 4),
    });
  }

  /// Adds a drawCircle operation to the deferred image block.
  void _canvasDrawCircle(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    _deferredImageOps.add(<String, dynamic>{
      'op': 'drawCircle',
      'x': _stringifyArgument(node, 0),
      'y': _stringifyArgument(node, 1),
      'radius': _stringifyArgument(node, 2),
      'color': _stringifyArgument(node, 3),
      'fill': _stringifyArgument(node, 4),
    });
  }

  /// Adds a drawRect operation to the deferred image block.
  void _canvasDrawRect(BdfdFunctionCallAst node) {
    if (!_deferredImageMode) return;

    _deferredImageOps.add(<String, dynamic>{
      'op': 'drawRect',
      'x': _stringifyArgument(node, 0),
      'y': _stringifyArgument(node, 1),
      'width': _stringifyArgument(node, 2),
      'height': _stringifyArgument(node, 3),
      'color': _stringifyArgument(node, 4),
      'fill': _stringifyArgument(node, 5),
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
