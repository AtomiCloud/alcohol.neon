import 'package:alcohol_neon/core/problem.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the error-display rule: zinc can send RFC 7807 problems whose
/// `detail` is an EMPTY string (e.g. TierInsufficient before it grew a default
/// detail). An empty string is non-null, so `detail ?? title` renders invisible
/// text — [Problem.displayMessage] must fall back to the title instead.
void main() {
  group('Problem.displayMessage', () {
    test('returns the detail when it carries real text', () {
      const p = Problem(
        type: 'about:blank',
        title: 'Tier Insufficient',
        status: 400,
        detail: 'Your free plan allows up to 2 habits.',
      );
      expect(p.displayMessage, 'Your free plan allows up to 2 habits.');
    });

    test('falls back to the title when detail is null', () {
      const p = Problem(type: 'about:blank', title: 'Error', status: 500);
      expect(p.displayMessage, 'Error');
    });

    test('falls back to the title when detail is an empty string', () {
      const p = Problem(
        type:
            'https://api.zinc.alcohol.pichu.cluster.atomi.cloud'
            '/docs/pichu/alcohol/zinc/main/v1/tier_insufficient',
        title: 'Tier Insufficient',
        status: 400,
        detail: '',
      );
      expect(p.displayMessage, 'Tier Insufficient');
    });

    test('falls back to the title when detail is only whitespace', () {
      const p = Problem(
        type: 'about:blank',
        title: 'Error',
        status: 400,
        detail: '   ',
      );
      expect(p.displayMessage, 'Error');
    });

    test('trims surrounding whitespace from a real detail', () {
      const p = Problem(
        type: 'about:blank',
        title: 'Error',
        status: 400,
        detail: '  Something went wrong.  ',
      );
      expect(p.displayMessage, 'Something went wrong.');
    });
  });
}
