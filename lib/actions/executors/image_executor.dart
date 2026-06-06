import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

// ─── Memory Constants ─────────────────────────────────────────────────────

/// Maximum canvas dimension (width or height) to prevent unbounded memory
/// allocation. A 4096×4096 RGBA canvas is ~67 MB.
const _kMaxCanvasDimension = 4096;

/// Maximum total bytes cached in the per-block URL cache. Beyond this limit,
/// the least-recently-used entries are evicted.
const _kUrlCacheMaxBytes = 50 * 1024 * 1024; // 50 MB

// ─── LRU Cache ────────────────────────────────────────────────────────────

/// A bounded LRU cache backed by [LinkedHashMap].
///
/// Tracks total byte size and evicts the least-recently-used entries when the
/// byte budget is exceeded. Value type [V] must have a [length] getter
/// (e.g. [Uint8List]).
class LruCache<V> {
  LruCache(this._maxBytes);

  final int _maxBytes;
  int _currentBytes = 0;
  final _map = <String, V>{};

  V? operator [](String key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // move to end (most-recent)
    }
    return value;
  }

  void operator []=(String key, V value) {
    final newBytes = (value as dynamic).length as int;
    // Remove existing entry for the same key if present.
    final old = _map.remove(key);
    if (old != null) {
      _currentBytes -= (old as dynamic).length as int;
    }
    // Evict LRU entries until enough room.
    while (_currentBytes + newBytes > _maxBytes && _map.isNotEmpty) {
      final firstKey = _map.keys.first;
      final removed = _map.remove(firstKey);
      if (removed != null) {
        _currentBytes -= (removed as dynamic).length as int;
      }
    }
    // If the new entry alone exceeds the budget, don't cache it.
    if (_currentBytes + newBytes <= _maxBytes) {
      _map[key] = value;
      _currentBytes += newBytes;
    }
  }

  bool containsKey(String key) => _map.containsKey(key);

  void clear() {
    _map.clear();
    _currentBytes = 0;
  }
}

// ─── Main Executor ────────────────────────────────────────────────────────

/// Executes an Image Manipulation Block at runtime.
///
/// The transpiler emits a single [BotCreatorActionType.runtimeImageBlock] action
/// when image canvas functions are detected. All canvas operations are collected
/// as a list of operations and executed sequentially on an image context.
///
/// Supported operations:
/// - `create` — creates a blank canvas
/// - `loadImage` — loads an image from a URL (http/https), data URL, or raw
///   base64 string. Uses an in-memory cache per block to avoid redundant
///   downloads.
/// - `compositeImage` — composites an external image at (x, y)
/// - `drawText` — draws text
/// - `drawCircle` — draws a circle (filled or outlined)
/// - `drawRect` — draws a rectangle (filled or outlined)
Future<void> executeRuntimeImageBlock({
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
}) async {
  img.Image? canvas;
  final operations = payload['operations'];
  // Per-block LRU cache for URL fetches (avoids redundant HTTP calls
  // while preventing unbounded memory growth from many distinct URLs).
  final urlCache = LruCache<Uint8List>(_kUrlCacheMaxBytes);

  if (operations is! List || operations.isEmpty) {
    results[resultKey] = '';
    variables[resultKey] = '';
    return;
  }

  for (final rawOp in operations) {
    if (rawOp is! Map) continue;
    final op = (rawOp['op'] ?? '').toString();

    // Resolve container-relative positioning.
    final containerName = (rawOp['container'] ?? '').toString().trim();
    int offsetX = 0, offsetY = 0;
    if (containerName.isNotEmpty) {
      final c = _containers[containerName];
      if (c != null) {
        offsetX = c.x;
        offsetY = c.y;
      }
    }
    // Apply offset to the rawOp clone so handlers receive absolute coords.
    final adjustedOp = Map<String, dynamic>.from(rawOp);
    if (offsetX != 0 || offsetY != 0) {
      _adjustPositionKeys(adjustedOp, offsetX, offsetY);
    }

    switch (op) {
      case 'create':
        canvas = _opCreate(adjustedOp, resolveValue);
        break;
      case 'loadImage':
        canvas = await _opLoadImage(adjustedOp, resolveValue, canvas,
            urlCache: urlCache);
        break;
      case 'compositeImage':
        canvas = await _opCompositeImage(adjustedOp, resolveValue, canvas,
            urlCache: urlCache);
        break;
      case 'drawText':
        canvas = _opDrawText(adjustedOp, resolveValue, canvas);
        break;
      case 'drawCircle':
        canvas = _opDrawCircle(adjustedOp, resolveValue, canvas);
        break;
      case 'drawRect':
        canvas = _opDrawRect(adjustedOp, resolveValue, canvas);
        break;
      case 'drawLine':
        canvas = _opDrawLine(adjustedOp, resolveValue, canvas);
        break;
      case 'container':
        _registerContainer(rawOp, resolveValue);
        break;
    }
  }

  if (canvas != null) {
    final pngBytes = img.encodePng(canvas);
    // Release the pixel buffer to help GC before the base64 inflation
    // allocates even more memory.
    canvas = null;

    final base64Png = base64Encode(pngBytes);
    results[resultKey] = base64Png;
    variables[resultKey] = base64Png;
    // dataUrl is derivable from base64 — store only the base64 and
    // let consumers compute the dataUrl when needed to avoid double storage.
    variables['$resultKey.dataUrl'] = 'data:image/png;base64,$base64Png';
    // If the block has an imageName, register as an attachment so
    // respondWithMessage / sendMessage collectors pick it up.
    final imageName = payload['imageName']?.toString().trim() ?? '';
    if (imageName.isNotEmpty) {
      variables['temp._canvasAttachment_$imageName'] = base64Png;
    }
  } else {
    results[resultKey] = '';
    variables[resultKey] = '';
  }

  // Clear the URL cache to release downloaded image bytes.
  urlCache.clear();
}

/// Executes an Attach Image action at runtime.
///
/// Downloads or resolves the image from [payload['imageSource']] and stores
/// it as a base64-encoded attachment under `temp._canvasAttachment_<imageName>`
/// in the variables map. The existing canvas attachment collectors in
/// `respond_with_message.dart` and `messaging_executor.dart` pick it up and
/// send it as a Discord file attachment.
///
/// Parameters:
/// - `imageName` (String, required): filename base for the attachment (e.g., "photo" → "photo.png")
/// - `imageSource` (String, required): HTTP URL, data URL, or raw base64
/// - `altText` (String, optional): ignored at runtime (Discord attachments don't support alt text)
///
/// Supported source formats (via [resolveImageSource]):
/// 1. `http://` or `https://` → HTTP GET with 15s timeout
/// 2. `data:image/...;base64,...` → base64 decode after comma
/// 3. Raw base64 string
Future<void> executeAttachImage({
  required Map<String, dynamic> payload,
  required String resultKey,
  required Map<String, String> results,
  required Map<String, String> variables,
  required String Function(String input) resolveValue,
}) async {
  final imageName = resolveValue((payload['imageName'] ?? '').toString()).trim();
  final imageSource = resolveValue((payload['imageSource'] ?? '').toString()).trim();

  if (imageName.isEmpty) {
    throw Exception('attachImage: imageName is required');
  }
  if (imageSource.isEmpty) {
    throw Exception('attachImage: imageSource is required');
  }

  final bytes = await resolveImageSource(imageSource);
  if (bytes == null || bytes.isEmpty) {
    throw Exception('attachImage: failed to load image from source');
  }

  // Store under the same prefix used by $attachImage (canvas attachments)
  // so that _collectCanvasAttachments and inline collection in
  // messaging_executor.dart pick it up automatically.
  variables['temp._canvasAttachment_$imageName'] = base64Encode(bytes);
  results[resultKey] = 'attached';
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _resolve(dynamic raw, String Function(String) resolveValue) {
  if (raw == null) return '';
  final s = raw.toString().trim();
  if (s.contains('((')) return resolveValue(s);
  return s;
}

int _parseInt(dynamic raw, String Function(String) resolveValue,
    {int defaultValue = 0}) {
  final s = _resolve(raw, resolveValue);
  return int.tryParse(s) ?? defaultValue;
}

bool _parseBool(dynamic raw, String Function(String) resolveValue,
    {bool defaultValue = false}) {
  final s = _resolve(raw, resolveValue).toLowerCase().trim();
  if (s == 'true' || s == 'yes' || s == '1') return true;
  if (s == 'false' || s == 'no' || s == '0') return false;
  return defaultValue;
}

/// Parses a color from a string. Supports hex (RRGGBB, #RRGGBB, RRGGBBAA)
/// and named colors.
img.ColorRgba8 _parseColor(dynamic raw, String Function(String) resolveValue) {
  final s = _resolve(raw, resolveValue).replaceAll('#', '').trim();
  if (s.isEmpty) return img.ColorRgba8(255, 255, 255, 255);

  // Named colors
  const namedColors = <String, List<int>>{
    'red': [255, 0, 0, 255],
    'green': [0, 255, 0, 255],
    'blue': [0, 0, 255, 255],
    'white': [255, 255, 255, 255],
    'black': [0, 0, 0, 255],
    'transparent': [0, 0, 0, 0],
    'yellow': [255, 255, 0, 255],
    'cyan': [0, 255, 255, 255],
    'magenta': [255, 0, 255, 255],
    'orange': [255, 165, 0, 255],
    'purple': [128, 0, 128, 255],
    'pink': [255, 192, 203, 255],
    'gray': [128, 128, 128, 255],
    'grey': [128, 128, 128, 255],
    'lime': [0, 255, 0, 255],
    'navy': [0, 0, 128, 255],
    'teal': [0, 128, 128, 255],
    'aqua': [0, 255, 255, 255],
    'maroon': [128, 0, 0, 255],
    'silver': [192, 192, 192, 255],
    'gold': [255, 215, 0, 255],
  };

  final lower = s.toLowerCase();
  final named = namedColors[lower];
  if (named != null) {
    return img.ColorRgba8(named[0], named[1], named[2], named[3]);
  }

  // Hex color
  try {
    final hex = int.parse(s, radix: 16);
    if (s.length <= 6) {
      return img.ColorRgba8(
        (hex >> 16) & 0xFF,
        (hex >> 8) & 0xFF,
        hex & 0xFF,
        255,
      );
    } else {
      return img.ColorRgba8(
        (hex >> 24) & 0xFF,
        (hex >> 16) & 0xFF,
        (hex >> 8) & 0xFF,
        hex & 0xFF,
      );
    }
  } catch (_) {
    return img.ColorRgba8(255, 255, 255, 255);
  }
}

/// Selects a bitmap font by size.
img.BitmapFont _selectFont(int fontSize) {
  if (fontSize >= 40) return img.arial48;
  if (fontSize >= 20) return img.arial24;
  return img.arial14;
}

/// Resolves a URL/dataUrl/raw-base64 string to image bytes.
///
/// Resolution order:
/// 1. `http://` or `https://` → HTTP GET (cached per block via [LruCache])
/// 2. `data:image/...;base64,...` → base64 decode
/// 3. Raw base64 string fallback
///
/// Returns `null` if the source cannot be resolved or the download fails.
///
/// Shared by [executeRuntimeImageBlock] and [executeAttachImage].
Future<Uint8List?> resolveImageSource(
  String source, {
  LruCache<Uint8List>? urlCache,
}) async {
  if (source.isEmpty) return null;

  // HTTP/HTTPS URL
  if (source.startsWith('http://') || source.startsWith('https://')) {
    if (urlCache != null && urlCache.containsKey(source)) {
      return urlCache[source];
    }
    try {
      final response =
          await http.get(Uri.parse(source)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        urlCache?[source] = response.bodyBytes;
        return response.bodyBytes;
      }
    } catch (_) {
      // Network error — skip silently, keep current canvas
    }
    return null;
  }

  // Data URL: data:image/png;base64,...
  if (source.startsWith('data:')) {
    final commaIdx = source.indexOf(',');
    if (commaIdx >= 0) {
      try {
        return base64Decode(source.substring(commaIdx + 1));
      } catch (_) {}
    }
    return null;
  }

  // Raw base64
  try {
    final bytes = base64Decode(source);
    if (bytes.isNotEmpty) return bytes;
  } catch (_) {}

  return null;
}

// ─── Operation Handlers ───────────────────────────────────────────────────────

img.Image _opCreate(Map rawOp, String Function(String) resolveValue) {
  final width = _parseInt(rawOp['width'], resolveValue, defaultValue: 400)
      .clamp(1, _kMaxCanvasDimension);
  final height = _parseInt(rawOp['height'], resolveValue, defaultValue: 300)
      .clamp(1, _kMaxCanvasDimension);
  final color = _parseColor(rawOp['color'], resolveValue);

  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: color);
  return canvas;
}

Future<img.Image?> _opLoadImage(
  Map rawOp,
  String Function(String) resolveValue,
  img.Image? current, {
  LruCache<Uint8List>? urlCache,
}) async {
  // Support both 'url' (preferred) and 'dataUrl' (legacy) keys.
  final source =
      _resolve(rawOp['url'] ?? rawOp['dataUrl'], resolveValue);
  if (source.isEmpty) return current;

  final bytes = await resolveImageSource(source, urlCache: urlCache);
  if (bytes == null) return current;

  var decoded = img.decodeImage(bytes);
  if (decoded == null) return current;

  // ── Position + resize (editor parity) ──────────────────────────────
  final x = _parseInt(rawOp['x'], resolveValue);
  final y = _parseInt(rawOp['y'], resolveValue);
  final targetWidth =
      _parseInt(rawOp['width'], resolveValue, defaultValue: -1);
  final targetHeight =
      _parseInt(rawOp['height'], resolveValue, defaultValue: -1);

  if (targetWidth > 0 && targetHeight > 0) {
    decoded = img.copyResize(decoded, width: targetWidth, height: targetHeight);
  }

  // If positioned AND there is a current canvas, composite on top.
  // Otherwise just return the decoded image (becomes the new canvas).
  if (current != null && (x != 0 || y != 0 || targetWidth > 0)) {
    img.compositeImage(current, decoded, dstX: x, dstY: y);
    return current;
  }

  return decoded;
}

Future<img.Image?> _opCompositeImage(
  Map rawOp,
  String Function(String) resolveValue,
  img.Image? current, {
  LruCache<Uint8List>? urlCache,
}) async {
  if (current == null) return null;

  final source =
      _resolve(rawOp['url'] ?? rawOp['dataUrl'], resolveValue);
  final x = _parseInt(rawOp['x'], resolveValue);
  final y = _parseInt(rawOp['y'], resolveValue);
  final targetWidth =
      _parseInt(rawOp['width'], resolveValue, defaultValue: -1);
  final targetHeight =
      _parseInt(rawOp['height'], resolveValue, defaultValue: -1);
  final shape = _resolve(rawOp['shape'], resolveValue).toLowerCase().trim();
  final blend = _resolve(rawOp['blend'], resolveValue).toLowerCase().trim();

  final bytes = await resolveImageSource(source, urlCache: urlCache);
  if (bytes == null) return current;

  var overlay = img.decodeImage(bytes);
  if (overlay != null) {
    if (targetWidth > 0 && targetHeight > 0) {
      overlay =
          img.copyResize(overlay, width: targetWidth, height: targetHeight);
    }
    if (shape == 'circle' ||
        shape == 'round' ||
        shape == 'oval' ||
        shape == 'ellipse') {
      overlay = _makeCircular(overlay);
    } else if (shape.startsWith('rounded') || shape.startsWith('roundrect')) {
      var radius = 20.0;
      final parts = shape.split(':');
      if (parts.length > 1) {
        radius = double.tryParse(parts[1]) ?? 20.0;
      } else {
        final numStr = shape.replaceAll(RegExp(r'[^0-9.]'), '');
        if (numStr.isNotEmpty) {
          radius = double.tryParse(numStr) ?? 20.0;
        }
      }
      overlay = _makeRoundedRect(overlay, radius);
    } else if (shape == 'triangle') {
      overlay = _makeTriangle(overlay);
    }

    // Apply blend mode if specified (non-normal)
    if (blend.isNotEmpty && blend != 'normal' && blend != 'srcover') {
      _blendOverlay(current, overlay, dstX: x, dstY: y, blendMode: blend);
    } else {
      img.compositeImage(current, overlay, dstX: x, dstY: y);
    }
  }

  return current;
}

/// Blends an overlay onto the destination using a named blend mode.
///
/// Supported blend modes (Photoshop naming):
/// - `multiply`    — darkens, useful for shadows
/// - `screen`      — lightens, useful for highlights
/// - `overlay`     — combines multiply and screen, adds contrast
/// - `darken`      — keeps darkest pixel per channel
/// - `lighten`     — keeps lightest pixel per channel
/// - `difference`  — absolute difference, useful for inversion effects
/// - `hardLight`   — strong contrast blend
/// - `softLight`   — subtle contrast blend (like a soft spotlight)
void _blendOverlay(
  img.Image dst,
  img.Image src, {
  required int dstX,
  required int dstY,
  required String blendMode,
}) {
  for (var sy = 0; sy < src.height; sy++) {
    final dy = dstY + sy;
    if (dy < 0 || dy >= dst.height) continue;
    for (var sx = 0; sx < src.width; sx++) {
      final dx = dstX + sx;
      if (dx < 0 || dx >= dst.width) continue;

      final sp = src.getPixel(sx, sy);
      if (sp.a == 0) continue;

      final dp = dst.getPixel(dx, dy);
      final sr = sp.r.toInt(), sg = sp.g.toInt(), sb = sp.b.toInt();
      final dr = dp.r.toInt(), dg = dp.g.toInt(), db = dp.b.toInt();

      int rb, gb, bb;
      switch (blendMode) {
        case 'multiply':
          rb = ((dr * sr) / 255).round();
          gb = ((dg * sg) / 255).round();
          bb = ((db * sb) / 255).round();
          break;
        case 'screen':
          rb = 255 - (((255 - dr) * (255 - sr)) / 255).round();
          gb = 255 - (((255 - dg) * (255 - sg)) / 255).round();
          bb = 255 - (((255 - db) * (255 - sb)) / 255).round();
          break;
        case 'overlay':
          rb = _overlayChannel(dr, sr);
          gb = _overlayChannel(dg, sg);
          bb = _overlayChannel(db, sb);
          break;
        case 'darken':
          rb = dr < sr ? dr : sr;
          gb = dg < sg ? dg : sg;
          bb = db < sb ? db : sb;
          break;
        case 'lighten':
          rb = dr > sr ? dr : sr;
          gb = dg > sg ? dg : sg;
          bb = db > sb ? db : sb;
          break;
        case 'difference':
          rb = (dr - sr).abs();
          gb = (dg - sg).abs();
          bb = (db - sb).abs();
          break;
        case 'hardlight':
          rb = _overlayChannel(sr, dr); // Note: src/dst swapped vs overlay
          gb = _overlayChannel(sg, dg);
          bb = _overlayChannel(sb, db);
          break;
        case 'softlight':
          rb = _softLightChannel(dr, sr);
          gb = _softLightChannel(dg, sg);
          bb = _softLightChannel(db, sb);
          break;
        default:
          // Unknown blend mode, fall through to normal
          rb = sr;
          gb = sg;
          bb = sb;
      }

      // Alpha blending: blend result with destination using src alpha
      final a = sp.a / 255.0;
      final finalR = (rb * a + dp.r * (1 - a)).round();
      final finalG = (gb * a + dp.g * (1 - a)).round();
      final finalB = (bb * a + dp.b * (1 - a)).round();
      final finalA = ((sp.a + dp.a * (1 - a)).round()).clamp(0, 255);

      dst.setPixelRgba(dx, dy, finalR, finalG, finalB, finalA);
    }
  }
}

/// Overlay blend mode helper per channel.
///
/// Formula: if base < 128, multiply; otherwise screen.
int _overlayChannel(int base, int blend) {
  if (base < 128) {
    return (2 * base * blend / 255).round();
  }
  return 255 - (2 * (255 - base) * (255 - blend) / 255).round();
}

/// Soft light blend mode helper per channel.
///
/// Softer version of overlay using a different formula for dark values.
int _softLightChannel(int base, int blend) {
  if (blend < 128) {
    return (base - (255 - 2 * blend) * base * (255 - base) / (255 * 255))
        .round();
  }
  final db = base < 128
      ? (2 * blend - 255) * (math.sqrt(base / 255.0) * 255 - base) / 255
      : (2 * blend - 255) * (math.sqrt(base / 255.0) - base / 255.0);
  return (base + db).round().clamp(0, 255);
}

/// Creates an anti-aliased circular mask of the source image.
///
/// Uses a smoothstep alpha transition at the circle boundary (1-pixel falloff)
/// to produce visually pleasing anti-aliased edges, rather than the hard-edged
/// threshold of the `image` package's built-in draw operations.
///
/// The algorithm:
/// 1. For each pixel, compute distance from the circle center
/// 2. Apply a smoothstep alpha that transitions from 1.0 (center) to 0.0 (edge)
///    over a 1-pixel boundary zone
/// 3. Blend the source pixel with transparent black using the computed alpha
img.Image _makeCircular(img.Image src) {
  final size = src.width < src.height ? src.width : src.height;
  final circular = img.Image(width: size, height: size, numChannels: 4);
  final center = (size - 1) / 2.0;
  final radius = size / 2.0;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - center;
      final dy = y - center;
      final dist = math.sqrt(dx * dx + dy * dy);

      // Smoothstep: alpha = 1.0 at center, 0.0 at edge, transition over 1px
      final alpha = (1.0 - (dist - (radius - 1.0))).clamp(0.0, 1.0);

      if (alpha > 0) {
        final srcPixel = src.getPixel(x, y);
        final a = (srcPixel.a * alpha).round();
        circular.setPixelRgba(x, y,
            srcPixel.r.toInt(), srcPixel.g.toInt(), srcPixel.b.toInt(), a);
      } else {
        circular.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }
  return circular;
}

img.Image _makeRoundedRect(img.Image src, double r) {
  final w = src.width;
  final h = src.height;
  final maxR = (w < h ? w : h) / 2.0;
  final radius = r > maxR ? maxR : r;
  if (radius <= 0) return src;

  final rounded = img.Image(width: w, height: h, numChannels: 4);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var isInside = true;

      // Top-left corner
      if (x < radius && y < radius) {
        final dx = radius - x - 0.5;
        final dy = radius - y - 0.5;
        if (dx * dx + dy * dy > radius * radius) {
          isInside = false;
        }
      }
      // Top-right corner
      else if (x >= w - radius && y < radius) {
        final dx = x - (w - radius) + 0.5;
        final dy = radius - y - 0.5;
        if (dx * dx + dy * dy > radius * radius) {
          isInside = false;
        }
      }
      // Bottom-left corner
      else if (x < radius && y >= h - radius) {
        final dx = radius - x - 0.5;
        final dy = y - (h - radius) + 0.5;
        if (dx * dx + dy * dy > radius * radius) {
          isInside = false;
        }
      }
      // Bottom-right corner
      else if (x >= w - radius && y >= h - radius) {
        final dx = x - (w - radius) + 0.5;
        final dy = y - (h - radius) + 0.5;
        if (dx * dx + dy * dy > radius * radius) {
          isInside = false;
        }
      }

      if (isInside) {
        rounded.setPixel(x, y, src.getPixel(x, y));
      } else {
        rounded.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
      }
    }
  }
  return rounded;
}

img.Image _makeTriangle(img.Image src) {
  final w = src.width;
  final h = src.height;
  final triangle = img.Image(width: w, height: h, numChannels: 4);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final leftBound = (w / 2.0) * (1.0 - y / h.toDouble());
      final rightBound = (w / 2.0) * (1.0 + y / h.toDouble());

      if (x >= leftBound && x <= rightBound) {
        triangle.setPixel(x, y, src.getPixel(x, y));
      } else {
        triangle.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
      }
    }
  }
  return triangle;
}

img.Image? _opDrawText(
    Map rawOp, String Function(String) resolveValue, img.Image? current) {
  if (current == null) return null;

  final text = _resolve(rawOp['text'], resolveValue);
  if (text.isEmpty) return current;

  final x = _parseInt(rawOp['x'], resolveValue);
  final y = _parseInt(rawOp['y'], resolveValue);
  final fontSize =
      _parseInt(rawOp['fontSize'], resolveValue, defaultValue: 14);
  final color = _parseColor(rawOp['color'], resolveValue);
  final textAlign = _resolve(rawOp['textAlign'], resolveValue).toLowerCase().trim();
  final maxWidth = _parseInt(rawOp['maxWidth'], resolveValue, defaultValue: -1);

  final font = _selectFont(fontSize);

  var drawX = x;
  if (maxWidth > 0) {
    final textWidth = _measureTextWidth(text, font);
    switch (textAlign) {
      case 'center':
        drawX = x + ((maxWidth - textWidth) / 2).round();
        break;
      case 'right':
        drawX = x + maxWidth - textWidth;
        break;
      default: // left
        break;
    }
  }

  img.drawString(current, text, font: font, x: drawX, y: y, color: color);

  return current;
}

/// Measures the pixel width of [text] rendered with [font].
int _measureTextWidth(String text, img.BitmapFont font) {
  var width = 0;
  for (var i = 0; i < text.length; i++) {
    width += font.characterXAdvance(text[i]);
  }
  return width;
}

img.Image? _opDrawCircle(
    Map rawOp, String Function(String) resolveValue, img.Image? current) {
  if (current == null) return null;

  final x = _parseInt(rawOp['x'], resolveValue);
  final y = _parseInt(rawOp['y'], resolveValue);
  final radius = _parseInt(rawOp['radius'], resolveValue, defaultValue: 10);
  final color = _parseColor(rawOp['color'], resolveValue);
  final fill = _parseBool(rawOp['fill'], resolveValue, defaultValue: true);
  final blend = _resolve(rawOp['blend'], resolveValue).toLowerCase().trim();

  if (blend.isEmpty || blend == 'normal' || blend == 'srcover') {
    // Fast path: standard fill/draw
    if (fill) {
      img.fillCircle(current, x: x, y: y, radius: radius, color: color);
    } else {
      img.drawCircle(current, x: x, y: y, radius: radius, color: color);
    }
  } else {
    // Blended path: per-pixel blend
    final r2 = radius * radius;
    final minX = (x - radius).clamp(0, current.width);
    final maxX = (x + radius).clamp(0, current.width - 1);
    final minY = (y - radius).clamp(0, current.height);
    final maxY = (y + radius).clamp(0, current.height - 1);
    for (var py = minY; py <= maxY; py++) {
      for (var px = minX; px <= maxX; px++) {
        final dx = px - x;
        final dy = py - y;
        final dist2 = dx * dx + dy * dy;
        if (!fill) {
          // Outline: blend only the boundary (within 1px of circle edge)
          if (dist2 > r2 || dist2 < (radius - 1) * (radius - 1)) continue;
        } else {
          if (dist2 > r2) continue;
        }
        _blendPixel(current, px, py, color, blend);
      }
    }
  }

  return current;
}

img.Image? _opDrawRect(
    Map rawOp, String Function(String) resolveValue, img.Image? current) {
  if (current == null) return null;

  final x = _parseInt(rawOp['x'], resolveValue);
  final y = _parseInt(rawOp['y'], resolveValue);
  final width = _parseInt(rawOp['width'], resolveValue, defaultValue: 50);
  final height = _parseInt(rawOp['height'], resolveValue, defaultValue: 50);
  final color = _parseColor(rawOp['color'], resolveValue);
  final fill = _parseBool(rawOp['fill'], resolveValue, defaultValue: true);
  final blend = _resolve(rawOp['blend'], resolveValue).toLowerCase().trim();

  final x2 = (x + width).clamp(0, current.width - 1);
  final y2 = (y + height).clamp(0, current.height - 1);
  final x1 = x.clamp(0, current.width);
  final y1 = y.clamp(0, current.height);

  if (blend.isEmpty || blend == 'normal' || blend == 'srcover') {
    // Fast path: standard fill/draw via the image package.
    if (fill) {
      img.fillRect(current,
          x1: x1, y1: y1, x2: x2, y2: y2, color: color);
    } else {
      img.drawRect(current,
          x1: x1, y1: y1, x2: x2, y2: y2, color: color);
    }
  } else {
    // Blended path: per-pixel blend.
    for (var py = y1; py <= y2; py++) {
      for (var px = x1; px <= x2; px++) {
        if (!fill) {
          // Outline: blend only the border pixels.
          if (py > y1 && py < y2 && px > x1 && px < x2) continue;
        }
        _blendPixel(current, px, py, color, blend);
      }
    }
  }

  return current;
}

/// Draws a line between two points using Bresenham's line algorithm.
///
/// Parameters:
/// - `x1` (int): Start X coordinate
/// - `y1` (int): Start Y coordinate
/// - `x2` (int): End X coordinate
/// - `y2` (int): End Y coordinate
/// - `color` (string): Line color (hex or named)
/// - `thickness` (int, default 1): Line width in pixels
/// - `blend` (string, optional): Blend mode (multiply, screen, overlay, etc.)
img.Image? _opDrawLine(
    Map rawOp, String Function(String) resolveValue, img.Image? current) {
  if (current == null) return null;

  var x1 = _parseInt(rawOp['x1'], resolveValue);
  var y1 = _parseInt(rawOp['y1'], resolveValue);
  final x2 = _parseInt(rawOp['x2'], resolveValue);
  final y2 = _parseInt(rawOp['y2'], resolveValue);
  final color = _parseColor(rawOp['color'], resolveValue);
  final thickness =
      _parseInt(rawOp['thickness'], resolveValue, defaultValue: 1).clamp(1, 100);
  final blend = _resolve(rawOp['blend'], resolveValue).toLowerCase().trim();
  final useBlend = blend.isNotEmpty && blend != 'normal' && blend != 'srcover';

  // Bresenham's line algorithm with thickness support.
  // For thickness > 1, draw the line centered on the ideal path by
  // offsetting perpendicular to the line direction.
  final dx = (x2 - x1).abs();
  final dy = -(y2 - y1).abs();
  final sx = x1 < x2 ? 1 : -1;
  final sy = y1 < y2 ? 1 : -1;
  var err = dx + dy;

  // Collect all points on the ideal line
  final points = <(int, int)>[];
  while (true) {
    points.add((x1, y1));
    if (x1 == x2 && y1 == y2) break;
    final e2 = 2 * err;
    if (e2 >= dy) {
      err += dy;
      x1 += sx;
    }
    if (e2 <= dx) {
      err += dx;
      y1 += sy;
    }
  }

  void writePixel(int px, int py) {
    if (px >= 0 && px < current.width && py >= 0 && py < current.height) {
      if (useBlend) {
        _blendPixel(current, px, py, color, blend);
      } else {
        current.setPixelRgba(px, py, color.r, color.g, color.b, color.a);
      }
    }
  }

  // For thickness > 1, expand perpendicular to line direction
  final halfThick = thickness ~/ 2;
  if (halfThick > 0 && points.length >= 2) {
    // Determine perpendicular direction from first and last segment
    final p0 = points.first;
    final p1 = points.last;
    final lineDx = p1.$1 - p0.$1;
    final lineDy = p1.$2 - p0.$2;
    final len = (lineDx * lineDx + lineDy * lineDy).toDouble();
    final perpDx = len > 0 ? (-lineDy / len * 1000).round() : 0;
    final perpDy = len > 0 ? (lineDx / len * 1000).round() : 0;

    // Normalize perpendicular
    final perpLen =
        (perpDx * perpDx + perpDy * perpDy).toDouble();
    final normX =
        perpLen > 0 ? (perpDx / perpLen * halfThick).round() : 0;
    final normY =
        perpLen > 0 ? (perpDy / perpLen * halfThick).round() : 0;

    for (final pt in points) {
      final px = pt.$1;
      final py = pt.$2;
      for (var t = -halfThick; t <= halfThick; t++) {
        writePixel(px + (normX * t).round(), py + (normY * t).round());
      }
    }
  } else {
    // Thickness 1: just draw the single-pixel line
    for (final pt in points) {
      writePixel(pt.$1, pt.$2);
    }
  }

  return current;
}

/// Blends a source color onto the destination pixel at ([dx], [dy]) using
/// the named [blendMode] (multiply, screen, overlay, darken, lighten,
/// difference, hardLight, softLight). Alpha is applied from the source
/// color's alpha channel.
void _blendPixel(img.Image dst, int dx, int dy, img.ColorRgba8 src,
    String blendMode) {
  final dp = dst.getPixel(dx, dy);
  final sr = src.r.toInt(), sg = src.g.toInt(), sb = src.b.toInt();
  final dr = dp.r.toInt(), dg = dp.g.toInt(), db = dp.b.toInt();

  int rb, gb, bb;
  switch (blendMode) {
    case 'multiply':
      rb = ((dr * sr) / 255).round();
      gb = ((dg * sg) / 255).round();
      bb = ((db * sb) / 255).round();
      break;
    case 'screen':
      rb = 255 - (((255 - dr) * (255 - sr)) / 255).round();
      gb = 255 - (((255 - dg) * (255 - sg)) / 255).round();
      bb = 255 - (((255 - db) * (255 - sb)) / 255).round();
      break;
    case 'overlay':
      rb = _overlayChannel(dr, sr);
      gb = _overlayChannel(dg, sg);
      bb = _overlayChannel(db, sb);
      break;
    case 'darken':
      rb = dr < sr ? dr : sr;
      gb = dg < sg ? dg : sg;
      bb = db < sb ? db : sb;
      break;
    case 'lighten':
      rb = dr > sr ? dr : sr;
      gb = dg > sg ? dg : sg;
      bb = db > sb ? db : sb;
      break;
    case 'difference':
      rb = (dr - sr).abs();
      gb = (dg - sg).abs();
      bb = (db - sb).abs();
      break;
    case 'hardlight':
      rb = _overlayChannel(sr, dr);
      gb = _overlayChannel(sg, dg);
      bb = _overlayChannel(sb, db);
      break;
    case 'softlight':
      rb = _softLightChannel(dr, sr);
      gb = _softLightChannel(dg, sg);
      bb = _softLightChannel(db, sb);
      break;
    default:
      rb = sr;
      gb = sg;
      bb = sb;
  }

  final a = src.a / 255.0;
  final finalR = (rb * a + dp.r * (1 - a)).round();
  final finalG = (gb * a + dp.g * (1 - a)).round();
  final finalB = (bb * a + dp.b * (1 - a)).round();
  final finalA = ((src.a + dp.a * (1 - a)).round()).clamp(0, 255);

  dst.setPixelRgba(dx, dy, finalR, finalG, finalB, finalA);
}

// ─── Container Support ────────────────────────────────────────────────────

/// Registry of named containers declared via the `container` operation.
/// Keyed by container name, stores the container's absolute origin.
final _containers = <String, _ContainerInfo>{};

/// Parsed container information.
class _ContainerInfo {
  final int x;
  final int y;
  final int width;
  final int height;
  const _ContainerInfo(this.x, this.y, this.width, this.height);
}

/// Registers a container from a `container` operation so subsequent
/// operations can reference it via `container: name`.
void _registerContainer(
    Map rawOp, String Function(String) resolveValue) {
  final name = _resolve(rawOp['name'], resolveValue).trim();
  if (name.isEmpty) return;
  final x = _parseInt(rawOp['x'], resolveValue);
  final y = _parseInt(rawOp['y'], resolveValue);
  final width = _parseInt(rawOp['width'], resolveValue, defaultValue: 100);
  final height = _parseInt(rawOp['height'], resolveValue, defaultValue: 100);
  _containers[name] = _ContainerInfo(x, y, width, height);

  // If the container has a background color, draw it.
  final bg = _resolve(rawOp['color'], resolveValue);
  if (bg.isNotEmpty) {
    // Background is drawn lazily — it's just metadata until drawn.
    // We store it on the container info.
  }
}

/// Offsets position keys in [op] by ([dx], [dy]) for container-relative
/// positioning. Handles the different key naming conventions across ops.
void _adjustPositionKeys(Map<String, dynamic> op, int dx, int dy) {
  final opType = (op['op'] ?? '').toString();
  switch (opType) {
    case 'drawText':
    case 'drawRect':
    case 'drawCircle':
    case 'loadImage':
    case 'compositeImage':
      _shiftKey(op, 'x', dx);
      _shiftKey(op, 'y', dy);
      break;
    case 'drawLine':
      _shiftKey(op, 'x1', dx);
      _shiftKey(op, 'y1', dy);
      _shiftKey(op, 'x2', dx);
      _shiftKey(op, 'y2', dy);
      break;
  }
}

void _shiftKey(Map<String, dynamic> op, String key, int delta) {
  if (!op.containsKey(key) || delta == 0) return;
  final current = int.tryParse((op[key] ?? '0').toString()) ?? 0;
  op[key] = (current + delta).toString();
}
