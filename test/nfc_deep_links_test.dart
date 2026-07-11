import 'dart:async';

import 'package:alcohol_neon/features/nfc/habit_schedule.dart';
import 'package:alcohol_neon/features/nfc/nfc_deep_links.dart';
import 'package:flutter_test/flutter_test.dart';

/// NfcDeepLinkService parking/consume semantics (via an injected link stream —
/// no platform channels) and the pure tap-day schedule check.
void main() {
  final base = Uri.parse('https://lazytax.club/t/');
  const tagId = '3f9c2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f';

  group('NfcDeepLinkService', () {
    test('parks the tag id from a /t/{id} link and notifies', () async {
      final links = StreamController<Uri>();
      final svc = NfcDeepLinkService(links: () => links.stream);
      var notified = 0;
      svc.addListener(() => notified++);

      svc.start(base);
      links.add(Uri.parse('https://lazytax.club/t/$tagId'));
      await Future<void>.delayed(Duration.zero);

      expect(svc.pendingTagId, tagId);
      expect(notified, 1);

      expect(svc.consume(), tagId);
      expect(svc.pendingTagId, isNull, reason: 'consume clears the parked id');
      expect(svc.consume(), isNull, reason: 'second consume yields nothing');

      await links.close();
    });

    test('ignores non-tag links (other paths / hosts / bad ids)', () async {
      final links = StreamController<Uri>();
      final svc = NfcDeepLinkService(links: () => links.stream);
      var notified = 0;
      svc.addListener(() => notified++);

      svc.start(base);
      links.add(Uri.parse('https://lazytax.club/billing'));
      links.add(Uri.parse('https://evil.example/t/$tagId'));
      links.add(Uri.parse('https://lazytax.club/t/x')); // too short
      await Future<void>.delayed(Duration.zero);

      expect(svc.pendingTagId, isNull);
      expect(notified, 0);

      await links.close();
    });

    test('a newer link replaces an unconsumed one', () async {
      final links = StreamController<Uri>();
      final svc = NfcDeepLinkService(links: () => links.stream);

      svc.start(base);
      links.add(Uri.parse('https://lazytax.club/t/$tagId'));
      links.add(Uri.parse('https://lazytax.club/t/aaaabbbb-cccc-dddd'));
      await Future<void>.delayed(Duration.zero);

      expect(svc.pendingTagId, 'aaaabbbb-cccc-dddd');

      await links.close();
    });
  });

  group('scheduledOnDate', () {
    test('matches zinc PascalCase day names against the ISO date', () {
      // 2026-07-11 is a Saturday.
      expect(scheduledOnDate(['Saturday'], '2026-07-11'), isTrue);
      expect(scheduledOnDate(['Monday', 'Friday'], '2026-07-11'), isFalse);
      expect(
        scheduledOnDate([
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ], '2026-07-11'),
        isTrue,
      );
    });

    test('empty schedule or malformed date → not scheduled', () {
      expect(scheduledOnDate(const [], '2026-07-11'), isFalse);
      expect(scheduledOnDate(['Saturday'], 'not-a-date'), isFalse);
    });
  });
}
