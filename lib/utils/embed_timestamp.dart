/// Parses embed timestamp values from config (ISO8601, epoch, or runtime sentinels).
DateTime? parseEmbedTimestamp(String raw) {
  final v = raw.trim();
  if (v.isEmpty) return null;
  if (v == 'now' || v == 'current') return DateTime.now().toUtc();

  final n = int.tryParse(v);
  if (n != null) {
    // 10 digits = seconds, 13+ = milliseconds (e.g. resolved ((timestamp))).
    return n < 1000000000000
        ? DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true)
        : DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
  }

  final iso = DateTime.tryParse(v);
  if (iso != null) return iso.toUtc();

  return null;
}
