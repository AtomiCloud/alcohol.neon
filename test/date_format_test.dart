import 'package:alcohol_neon/core/date_format.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc date contract: `dd-MM-yyyy` (NOT ISO). These are the exact
/// strings vacation start/end dates are sent and received as.
void main() {
  group('formatStandardDate', () {
    test('formats as dd-MM-yyyy with zero padding', () {
      expect(formatStandardDate(DateTime(2026, 6, 1)), '01-06-2026');
      expect(formatStandardDate(DateTime(2026, 12, 25)), '25-12-2026');
    });

    test('is NOT ISO yyyy-MM-dd', () {
      final s = formatStandardDate(DateTime(2026, 6, 1));
      expect(s.startsWith('2026'), isFalse);
      expect(s, '01-06-2026');
    });
  });

  group('tryParseStandardDate', () {
    test('parses a valid dd-MM-yyyy string', () {
      final d = tryParseStandardDate('25-12-2026');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 12);
      expect(d.day, 25);
    });

    test('round-trips with formatStandardDate', () {
      const s = '07-03-2027';
      expect(formatStandardDate(tryParseStandardDate(s)!), s);
    });

    test('returns null for null / malformed / ISO input', () {
      expect(tryParseStandardDate(null), isNull);
      expect(tryParseStandardDate(''), isNull);
      expect(tryParseStandardDate('2026-06-01'), isNull); // ISO is rejected
      expect(tryParseStandardDate('01/06/2026'), isNull);
      expect(tryParseStandardDate('not-a-date'), isNull);
    });

    test('returns null for out-of-range or overflowing dates', () {
      expect(tryParseStandardDate('32-01-2026'), isNull);
      expect(tryParseStandardDate('01-13-2026'), isNull);
      expect(tryParseStandardDate('31-02-2026'), isNull); // Feb 31 overflows
    });
  });
}
