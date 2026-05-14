/// Utility to parse BDFD duration strings (e.g. 10s, 1m, 1h, 1d, 1w, 1y).
Duration? parseBdfdDuration(String text) {
  final trimmed = text.trim().toLowerCase();
  if (trimmed.isEmpty) return null;

  final numberPart = RegExp(r'^\d+').stringMatch(trimmed);
  if (numberPart == null) return null;

  final value = int.tryParse(numberPart);
  if (value == null) return null;

  final unit = trimmed.substring(numberPart.length).trim();
  switch (unit) {
    case 's':
    case 'sec':
    case 'seconds':
      return Duration(seconds: value);
    case 'm':
    case 'min':
    case 'minutes':
      return Duration(minutes: value);
    case 'h':
    case 'hour':
    case 'hours':
      return Duration(hours: value);
    case 'd':
    case 'day':
    case 'days':
      return Duration(days: value);
    case 'w':
    case 'week':
    case 'weeks':
      return Duration(days: value * 7);
    case 'y':
    case 'year':
    case 'years':
      return Duration(days: value * 365);
    case 'ms':
    case 'milliseconds':
      return Duration(milliseconds: value);
    default:
      // Default to seconds if no unit provided
      return Duration(seconds: value);
  }
}

/// Formats a duration into a human-readable BDFD-style string.
String formatBdfdDuration(Duration duration) {
  if (duration.inDays >= 365) {
    final years = duration.inDays ~/ 365;
    return '$years Year${years > 1 ? 's' : ''}';
  }
  if (duration.inDays >= 7) {
    final weeks = duration.inDays ~/ 7;
    return '$weeks Week${weeks > 1 ? 's' : ''}';
  }
  if (duration.inDays >= 1) {
    final days = duration.inDays;
    return '$days Day${days > 1 ? 's' : ''}';
  }
  if (duration.inHours >= 1) {
    final hours = duration.inHours;
    return '$hours Hour${hours > 1 ? 's' : ''}';
  }
  if (duration.inMinutes >= 1) {
    final minutes = duration.inMinutes;
    return '$minutes Minute${minutes > 1 ? 's' : ''}';
  }
  final seconds = duration.inSeconds;
  return '$seconds Second${seconds > 1 ? 's' : ''}';
}
