import 'package:bot_creator_shared/utils/embed_timestamp.dart';
import 'package:test/test.dart';

void main() {
  group('parseEmbedTimestamp', () {
    test('returns null for empty input', () {
      expect(parseEmbedTimestamp(''), isNull);
      expect(parseEmbedTimestamp('   '), isNull);
    });

    test('resolves now and current sentinels', () {
      final before = DateTime.now().toUtc();
      final now = parseEmbedTimestamp('now');
      final current = parseEmbedTimestamp('current');
      final after = DateTime.now().toUtc();

      expect(now, isNotNull);
      expect(current, isNotNull);
      expect(now!.isBefore(after) || now.isAtSameMomentAs(after), isTrue);
      expect(now.isAfter(before) || now.isAtSameMomentAs(before), isTrue);
      expect(current!.isBefore(after) || current.isAtSameMomentAs(after), isTrue);
    });

    test('parses ISO8601 strings', () {
      final parsed = parseEmbedTimestamp('2026-03-30T12:00:00Z');
      expect(parsed, DateTime.utc(2026, 3, 30, 12));
    });

    test('parses unix seconds', () {
      final parsed = parseEmbedTimestamp('1700000000');
      expect(parsed, DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true));
    });

    test('parses unix milliseconds', () {
      final parsed = parseEmbedTimestamp('1700000000000');
      expect(parsed, DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true));
    });
  });
}
