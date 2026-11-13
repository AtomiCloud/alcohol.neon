import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:alcohol_neon/generated/zinc/models/configuration_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_response.dart';
import 'package:alcohol_neon/session/session_cache.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/session_harness.dart';

void main() {
  late Directory dir;
  late SessionCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('session_cache');
    cache = SessionCache(dir: () async => dir);
  });
  tearDown(() => dir.delete(recursive: true));

  final config = ConfigurationPrincipalRes.fromJson({
    'id': 'cfg-1',
    'userId': 'u1',
    'timezone': 'Asia/Singapore',
    'endOfDay': '23:59',
    'defaultCharityId': 'c1',
  });
  final overview = HabitOverviewResponse.fromJson({
    'habits': <Object?>[],
    'totalDebt': '12.50',
    'totalSkip': 20,
    'usedSkip': 3,
  });

  test('round-trips the snapshot for the same user on the same day', () async {
    await cache.saveConfig('u1', config);
    await cache.saveOverview('u1', overview);
    final s = await cache.load('u1');
    expect(s, isNotNull);
    expect(s!.config.timezone, 'Asia/Singapore');
    expect(s.overview.totalDebt, '12.50');
    expect(s.overview.usedSkip, 3);
  });

  test('ignores another user, a missing half, and a previous day', () async {
    await cache.saveConfig('u1', config);
    expect(await cache.load('u1'), isNull, reason: 'no overview yet');
    await cache.saveOverview('u1', overview);
    expect(await cache.load('u2'), isNull);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(await cache.load('u1', now: tomorrow), isNull);
    // A different user's save replaces the file rather than mixing in.
    await cache.saveOverview('u2', overview);
    expect(await cache.load('u2'), isNull, reason: 'u2 has no config');
    expect(await cache.load('u1'), isNull);
  });

  group('bootstrap', () {
    Future<void> turns() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a saved Today is ready before any request returns', () async {
      final held = Completer<http.Response>();
      final h = SessionHarness(
        respond: (r) async =>
            r.url.path.endsWith('/User/Me/All') ? held.future : null,
      );
      h.cache.snapshot = SessionSnapshot(
        config,
        HabitOverviewResponse.fromJson(overviewBody()),
        DateTime.now(),
      );
      final run = h.start();
      await turns();
      expect(h.session.phase, SessionPhase.ready);
      expect(h.session.takeCachedOverview(), isNotNull);
      held.complete(
        jsonResponse({
          'principal': {'emailVerified': true, 'active': true},
        }),
      );
      await run;
      expect(h.session.phase, SessionPhase.ready);
      expect(h.cache.savedConfig?.id, 'cfg1', reason: 'fresh config saved');
      expect(
        h.requests.where((r) => r.url.path.endsWith('/overview')),
        isEmpty,
        reason: 'the dashboard refreshes a saved Today itself',
      );
      h.dispose();
    });

    testWidgets('a zinc request that never answers ends on the error '
        'screen, not the loader', (tester) async {
      // Ernest's "loads forever": a stalled connection kept bootstrap in
      // `bootstrapping` (the launch loader) with no way out.
      final h = SessionHarness(
        respond: (r) async => r.url.path.endsWith('/User/Me/All')
            ? Completer<http.Response>().future
            : null,
      );
      var finished = false;
      h.start().then((_) => finished = true);
      await tester.pump(const Duration(seconds: 25));

      expect(finished, isTrue);
      expect(h.session.phase, SessionPhase.error);
      expect(h.session.error?.type, 'neon:network');
      h.dispose();
    });

    test(
      'offline, the error screen says what to do, not the exception',
      () async {
        final h = SessionHarness(
          respond: (r) async => r.url.path.endsWith('/User/Me/All')
              ? throw const SocketException(
                  "Failed host lookup: 'api.zinc.example'",
                )
              : null,
        );
        await h.start();
        expect(h.session.phase, SessionPhase.error);
        expect(h.session.error?.title, 'Network error');
        expect(
          h.session.error?.displayMessage,
          'Check your connection and try again.',
        );
        h.dispose();
      },
    );

    test(
      'an unreadable answer shows a plain message, not the parse error',
      () async {
        final h = SessionHarness(
          respond: (r) async => r.url.path.endsWith('/User/Me/All')
              ? http.Response('{"principal": ', 200)
              : null,
        );
        await h.start();
        expect(h.session.phase, SessionPhase.error);
        expect(h.session.error?.title, 'Unexpected response');
        expect(
          h.session.error?.displayMessage,
          'Something went wrong on our side. Try again in a moment.',
        );
        h.dispose();
      },
    );

    test('reads and the overview start together, not one by one', () async {
      final held = Completer<http.Response>();
      final h = SessionHarness(
        respond: (r) async =>
            r.url.path.endsWith('/User/Me/All') ? held.future : null,
      );
      final run = h.start();
      await turns();
      final paths = h.requests.map((r) => r.url.path).toList();
      expect(paths.where((p) => p.endsWith('/overview')), hasLength(1));
      expect(paths.where((p) => p.endsWith('/Configuration/me')), hasLength(1));
      expect(paths.where((p) => p.endsWith('/consent')), hasLength(1));
      expect(h.session.phase, SessionPhase.bootstrapping);
      held.complete(
        jsonResponse({
          'principal': {'emailVerified': true, 'active': true},
        }),
      );
      await run;
      expect(h.session.phase, SessionPhase.ready);
      expect(h.session.takeOverviewPrefetch(), isNotNull);
      h.dispose();
    });

    test('first sign-in creates the user, then reads config again', () async {
      var created = false;
      final h = SessionHarness(
        respond: (r) async {
          final path = r.url.path;
          if (path.endsWith('/User/Me/All') && !created) {
            return jsonResponse({'title': 'Not found', 'status': 404}, 404);
          }
          if (r.method == 'POST' && path.endsWith('/User')) {
            created = true;
            return jsonResponse({'emailVerified': true, 'active': true});
          }
          return null;
        },
      );
      await h.start();
      expect(created, isTrue);
      final configReads = h.requests
          .where((r) => r.url.path.endsWith('/Configuration/me'))
          .length;
      expect(configReads, 2);
      expect(h.session.phase, SessionPhase.ready);
      expect(
        h.session.takeOverviewPrefetch(),
        isNull,
        reason: 'the overview from before the user existed is dropped',
      );
      h.dispose();
    });

    group('with the phone in Asia/Tokyo', () {
      final messenger =
          TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
      const channel = MethodChannel('flutter_timezone');
      setUp(() {
        messenger.setMockMethodCallHandler(channel, (call) async {
          return call.method == 'getLocalTimezone' ? 'Asia/Tokyo' : null;
        });
      });
      tearDown(() => messenger.setMockMethodCallHandler(channel, null));

      bool isConfigWrite(http.Request r, String method) =>
          r.method == method && r.url.path.contains('/Configuration');

      test('no configuration: creates one in the phone timezone with no '
          'default charity, then is ready', () async {
        Map<String, Object?>? created;
        final h = SessionHarness(
          respond: (r) async {
            if (isConfigWrite(r, 'POST')) {
              created = jsonDecode(r.body) as Map<String, Object?>;
              return jsonResponse({
                'id': 'cfg-new',
                'timezone': created!['timezone'],
                'defaultCharityId': null,
              });
            }
            if (r.url.path.endsWith('/Configuration/me')) {
              return jsonResponse({'title': 'Not found', 'status': 404}, 404);
            }
            return null;
          },
        );
        await h.start();
        expect(created, {'timezone': 'Asia/Tokyo', 'defaultCharityId': null});
        expect(h.session.phase, SessionPhase.ready);
        expect(h.session.config?.id, 'cfg-new');
        expect(h.session.config?.defaultCharityId, isNull);
        expect(h.cache.savedConfig?.id, 'cfg-new');
        expect(h.requests.where((r) => isConfigWrite(r, 'PUT')), isEmpty);
        h.dispose();
      });

      test('a failed create lands on the error screen, not Today', () async {
        final h = SessionHarness(
          respond: (r) async {
            if (isConfigWrite(r, 'POST')) {
              return jsonResponse({'title': 'Bad Request', 'status': 400}, 400);
            }
            if (r.url.path.endsWith('/Configuration/me')) {
              return jsonResponse({'title': 'Not found', 'status': 404}, 404);
            }
            return null;
          },
        );
        await h.start();
        expect(h.session.phase, SessionPhase.error);
        expect(h.session.error?.status, 400);
        h.dispose();
      });

      test('no default charity still follows the phone timezone', () async {
        Map<String, Object?>? put;
        final h = SessionHarness(
          respond: (r) async {
            if (isConfigWrite(r, 'PUT')) {
              put = jsonDecode(r.body) as Map<String, Object?>;
              return jsonResponse({
                'id': 'cfg1',
                'timezone': put!['timezone'],
                'defaultCharityId': null,
              });
            }
            if (r.url.path.endsWith('/Configuration/me')) {
              return jsonResponse({
                'principal': {
                  'id': 'cfg1',
                  'timezone': 'Asia/Singapore',
                  'defaultCharityId': null,
                },
                'charity': null,
              });
            }
            return null;
          },
        );
        await h.start();
        expect(put, {'timezone': 'Asia/Tokyo', 'defaultCharityId': null});
        expect(h.session.config?.timezone, 'Asia/Tokyo');
        expect(h.session.phase, SessionPhase.ready);
        h.dispose();
      });
    });
  });
}
