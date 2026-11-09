import 'dart:convert';

import 'package:alcohol_neon/core/problem.dart';
import 'package:alcohol_neon/data/config_repository.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/session/timezone_preference.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/session_harness.dart';

/// Follow-the-phone: the pure decision (only sync when the preference is on
/// and the phone reports a different timezone than Configuration.Timezone),
/// and the session wiring that PUTs it through the real repositories.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('follow ON + different timezone → sync', () {
    expect(
      shouldSyncTimezone(
        followPhone: true,
        deviceTimezone: 'Europe/London',
        configuredTimezone: 'Asia/Singapore',
      ),
      isTrue,
    );
  });

  test('follow ON + no configured timezone → sync', () {
    expect(
      shouldSyncTimezone(
        followPhone: true,
        deviceTimezone: 'Europe/London',
        configuredTimezone: null,
      ),
      isTrue,
    );
  });

  test('same timezone → no sync', () {
    expect(
      shouldSyncTimezone(
        followPhone: true,
        deviceTimezone: 'Asia/Singapore',
        configuredTimezone: 'Asia/Singapore',
      ),
      isFalse,
    );
  });

  test('follow OFF (manual override) → never sync', () {
    expect(
      shouldSyncTimezone(
        followPhone: false,
        deviceTimezone: 'Europe/London',
        configuredTimezone: 'Asia/Singapore',
      ),
      isFalse,
    );
  });

  test('phone reports no timezone → no sync', () {
    for (final device in [null, '']) {
      expect(
        shouldSyncTimezone(
          followPhone: true,
          deviceTimezone: device,
          configuredTimezone: 'Asia/Singapore',
        ),
        isFalse,
      );
    }
  });

  group('timezoneSettledMessage', () {
    TimezoneSettledCheck day(String habitId, DateTime date, String status) =>
        TimezoneSettledCheck(habitId: habitId, date: date, status: status);
    final tuesday = DateTime(2026, 1, 6);
    final wednesday = DateTime(2026, 1, 7);

    test('nothing settled → no message', () {
      expect(timezoneSettledMessage('Asia/Singapore', []), isNull);
    });

    test('one sentence per day, in date order, worst status per day', () {
      expect(
        timezoneSettledMessage('America/Los_Angeles', [
          day('h1', wednesday, 'vacation'),
          day('h1', tuesday, 'frozen'),
          day('h2', tuesday, 'missed'),
        ]),
        'Your timezone changed to Los Angeles. '
        'Tuesday had already ended there and no freeze was left, so it was missed. '
        'Wednesday had already ended there, so your vacation covered it.',
      );
    });

    test('a freeze', () {
      expect(
        timezoneSettledMessage('Asia/Singapore', [
          day('h1', tuesday, 'frozen'),
        ]),
        'Your timezone changed to Singapore. '
        'Tuesday had already ended there, so a freeze covered it.',
      );
    });
  });

  group('session', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const timezoneChannel = MethodChannel('flutter_timezone');

    setUpAll(loadHarnessConfig);
    setUp(() {
      // The phone is in Tokyo; the harness config says Asia/Singapore.
      messenger.setMockMethodCallHandler(
        timezoneChannel,
        (_) async => 'Asia/Tokyo',
      );
    });
    tearDown(() => messenger.setMockMethodCallHandler(timezoneChannel, null));

    List<http.Request> puts(SessionHarness h) =>
        h.requests.where((r) => r.method == 'PUT').toList();

    SessionHarness harness({bool followPhone = true, int putStatus = 200}) =>
        SessionHarness(
          followPhone: followPhone,
          respond: (r) async {
            if (r.method != 'PUT') return null;
            if (putStatus != 200) {
              return jsonResponse({'title': 'Down', 'status': putStatus}, 500);
            }
            final body = jsonDecode(r.body) as Map<String, Object?>;
            return jsonResponse({'id': 'cfg1', 'userId': 'user-1', ...body});
          },
        );

    test(
      'bootstrap moves the config to the phone, charity unchanged',
      () async {
        final h = harness();
        await h.start();
        expect(h.session.phase, SessionPhase.ready);
        final put = puts(h).single;
        expect(put.url.path, '/api/v1.0/Configuration/cfg1');
        expect(jsonDecode(put.body), {
          'timezone': 'Asia/Tokyo',
          'defaultCharityId': 'ch1',
        });
        expect(h.session.config?.timezone, 'Asia/Tokyo');
        expect(h.session.config?.defaultCharityId, 'ch1');
        // Already in step: a resume sync is a no-op.
        expect(await h.session.syncDeviceTimezone(), isFalse);
        expect(puts(h), hasLength(1));
        h.dispose();
      },
    );

    test('manual override (follow OFF) never PUTs', () async {
      final h = harness(followPhone: false);
      await h.start();
      expect(h.session.followPhoneTimezone, isFalse);
      expect(await h.session.syncDeviceTimezone(), isFalse);
      expect(puts(h), isEmpty);
      expect(h.session.config?.timezone, 'Asia/Singapore');
      h.dispose();
    });

    test('turning follow back ON persists and syncs immediately', () async {
      final h = harness(followPhone: false);
      await h.start();
      expect(await h.session.setFollowPhoneTimezone(true), isA<Ok<void>>());
      expect(h.timezonePreference.followPhone, isTrue);
      expect(h.session.config?.timezone, 'Asia/Tokyo');
      expect(puts(h), hasLength(1));
      await h.session.setFollowPhoneTimezone(false);
      expect(h.timezonePreference.followPhone, isFalse);
      expect(h.session.config?.timezone, 'Asia/Tokyo');
      h.dispose();
    });

    test('days the sync settled are told once', () async {
      final h = SessionHarness(
        respond: (r) async {
          if (r.method != 'PUT') return null;
          final body = jsonDecode(r.body) as Map<String, Object?>;
          return jsonResponse({
            'id': 'cfg1',
            'userId': 'user-1',
            ...body,
            'settledChecks': [
              {'habitId': 'h1', 'date': '06-01-2026', 'status': 'frozen'},
            ],
          });
        },
      );
      await h.start();
      expect(h.session.config?.timezone, 'Asia/Tokyo');
      expect(
        h.session.takeTimezoneNotice(),
        'Your timezone changed to Tokyo. '
        'Tuesday had already ended there, so a freeze covered it.',
      );
      expect(h.session.takeTimezoneNotice(), isNull);
      h.dispose();
    });

    test('a sync that settled nothing has no notice', () async {
      final h = harness();
      await h.start();
      expect(h.session.config?.timezone, 'Asia/Tokyo');
      expect(h.session.takeTimezoneNotice(), isNull);
      h.dispose();
    });

    test('a failed PUT keeps the config and does not block the app', () async {
      final h = harness(putStatus: 500);
      await h.start();
      expect(h.session.phase, SessionPhase.ready);
      expect(h.session.config?.timezone, 'Asia/Singapore');
      expect(puts(h), hasLength(1));
      h.dispose();
    });
  });
}
