import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

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
  // Per-block cache for URL fetches (avoids redundant HTTP calls).
  final urlCache = <String, Uint8List>{};

  if (operations is! List || operations.isEmpty) {
    results[resultKey] = '';
    variables[resultKey] = '';
    return;
  }

  for (final rawOp in operations) {
    if (rawOp is! Map) continue;
    final op = (rawOp['op'] ?? '').toString();

    switch (op) {
      case 'create':
        canvas = _opCreate(rawOp, resolveValue);
        break;
      case 'loadImage':
        canvas = await _opLoadImage(rawOp, resolveValue, canvas,
            urlCache: urlCache);
        break;
      case 'compositeImage':
        canvas = await _opCompositeImage(rawOp, resolveValue, canvas,
            urlCache: urlCache);
        break;
      case 'drawText':
        canvas = _opDrawText(rawOp, resolveValue, canvas);
        break;
      case 'drawCircle':
        canvas = _opDrawCircle(rawOp, resolveValue, canvas);
        break;
      case 'drawRect':
        canvas = _opDrawRect(rawOp, resolveValue, canvas);
        break;
    }
  }

  if (canvas != null) {
    final pngBytes = img.encodePng(canvas);
    final base64Png = base64Encode(pngBytes);
    results[resultKey] = base64Png;
    variables[resultKey] = base64Png;
    // Also expose as a data URL for embed compatibility
    final dataUrl = 'data:image/png;base64,$base64Png';
    variables['$resultKey.dataUrl'] = dataUrl;
  } else {
    results[resultKey] = '';
    variables[resultKey] = '';
  }
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
/// 1. `http://` or `https://` → HTTP GET (cached per block)
/// 2. `data:image/...;base64,...` → base64 decode
/// 3. Raw base64 string fallback
///
/// Returns `null` if the source cannot be resolved or the download fails.
Future<Uint8List?> _resolveImageSource(
  String source, {
  Map<String, Uint8List>? urlCache,
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
  final width = _parseInt(rawOp['width'], resolveValue, defaultValue: 400);
  final height = _parseInt(rawOp['height'], resolveValue, defaultValue: 300);
  final color = _parseColor(rawOp['color'], resolveValue);

  final canvas = img.Image(width: width, height: height);
  img.fill(canvas, color: color);
  return canvas;
}

Future<img.Image?> _opLoadImage(
  Map rawOp,
  String Function(String) resolveValue,
  img.Image? current, {
  Map<String, Uint8List>? urlCache,
}) async {
  // Support both 'url' (preferred) and 'dataUrl' (legacy) keys.
  final source =
      _resolve(rawOp['url'] ?? rawOp['dataUrl'], resolveValue);
  if (source.isEmpty) return current;

  final bytes = await _resolveImageSource(source, urlCache: urlCache);
  if (bytes == null) return current;

  final decoded = img.decodeImage(bytes);
  if (decoded != null) return decoded;

  return current;
}

Future<img.Image?> _opCompositeImage(
  Map rawOp,
  String Function(String) resolveValue,
  img.Image? current, {
  Map<String, Uint8List>? urlCache,
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

  final bytes = await _resolveImageSource(source, urlCache: urlCache);
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
    img.compositeImage(current, overlay, dstX: x, dstY: y);
  }

  return current;
}

img.Image _makeCircular(img.Image src) {
  final size = src.width < src.height ? src.width : src.height;
  final circular = img.Image(width: size, height: size, numChannels: 4);
  final center = size / 2.0;
  final radius = size / 2.0;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = x - center + 0.5;
      final dy = y - center + 0.5;
      final distance = dx * dx + dy * dy;

      if (distance <= radius * radius) {
        circular.setPixel(x, y, src.getPixel(x, y));
      } else {
        circular.setPixel(x, y, img.ColorRgba8(0, 0, 0, 0));
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

  final font = _selectFont(fontSize);
  img.drawString(current, text, font: font, x: x, y: y, color: color);

  return current;
}

img.Image? _opDrawCircle(
    Map rawOp, String Function(String) resolveValue, img.Image? current) {
  if (current == null) return null;

  final x = _parseInt(rawOp['x'], resolveValue);
  final y = _parseInt(rawOp['y'], resolveValue);
  final radius = _parseInt(rawOp['radius'], resolveValue, defaultValue: 10);
  final color = _parseColor(rawOp['color'], resolveValue);
  final fill = _parseBool(rawOp['fill'], resolveValue, defaultValue: true);

  if (fill) {
    img.fillCircle(current, x: x, y: y, radius: radius, color: color);
  } else {
    img.drawCircle(current, x: x, y: y, radius: radius, color: color);
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

  if (fill) {
    img.fillRect(current,
        x1: x, y1: y, x2: x + width, y2: y + height, color: color);
  } else {
    img.drawRect(current,
        x1: x, y1: y, x2: x + width, y2: y + height, color: color);
  }

  return current;
}
