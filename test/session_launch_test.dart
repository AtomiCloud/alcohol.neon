import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:alcohol_neon/generated/zinc/models/configuration_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_response.dart';
import 'package:alcohol_neon/session/session_cache.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/features/root/root_view.dart';
import 'package:alcohol_neon/features/nfc/nfc_deep_links.dart';
import 'package:alcohol_neon/main.dart';
import 'package:alcohol_neon/theme/appearance_setting.dart';
import 'package:alcohol_neon/widgets/app_loader.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

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

  group('launch branding', () {
    setUpAll(loadHarnessConfig);
    tearDown(() => AppearanceSetting.instance.value = ThemeMode.system);

    Finder logo() => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.width == 128 &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName == 'assets/brand/logo.png',
    );

    Future<void> pumpLaunch(
      WidgetTester tester,
      SessionHarness h, {
      Brightness phone = Brightness.light,
      ThemeMode saved = ThemeMode.system,
      bool reducedMotion = false,
    }) async {
      tester.platformDispatcher.platformBrightnessTestValue = phone;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reducedMotion);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      addTearDown(h.dispose);
      AppearanceSetting.instance.value = saved;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthService>.value(value: h.auth),
            ChangeNotifierProvider<SessionController>.value(value: h.session),
            ChangeNotifierProvider(create: (_) => NfcDeepLinkService()),
          ],
          child: const RepaintBoundary(
            key: ValueKey('launch-frame'),
            child: AlcoholNeonApp(),
          ),
        ),
      );
      // Image decoding is real I/O. Keep it outside the deterministic clock
      // used below to assert the 180ms transition (no wall-time sleeps).
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/brand/logo.png'),
          tester.element(find.byType(RootView)),
        ),
      );
      await tester.runAsync(
        () => AssetLottie('assets/animations/loading.json').load(),
      );
      await tester.pump();
      await tester.pump();
    }

    for (final phone in Brightness.values) {
      testWidgets('ColdLaunchLoading_FirstFrameShowsBrandLogo ${phone.name}', (
        tester,
      ) async {
        final h = SessionHarness()..auth.status = AuthStatus.loading;
        await pumpLaunch(tester, h, phone: phone);
        expect(logo(), findsOneWidget);
        expect(tester.getSize(logo()), const Size(128, 128));
        expect(
          tester.getCenter(logo()),
          tester.getCenter(find.byType(RootView)),
        );
        expect(find.bySemanticsLabel('Loading LazyTax'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 90));
        expect(logo(), findsOneWidget, reason: 'fade is still in progress');
        await tester.pump(const Duration(milliseconds: 90));
        expect(logo(), findsNothing);
        expect(find.byType(AppLoader), findsOneWidget);
      });

      testWidgets(
        'LaunchThemeMismatch_BridgesSystemToSavedTheme ${phone.name}',
        (tester) async {
          final h = SessionHarness()..auth.status = AuthStatus.loading;
          final saved = phone == Brightness.dark
              ? ThemeMode.light
              : ThemeMode.dark;
          await pumpLaunch(tester, h, phone: phone, saved: saved);
          final background = tester.widget<ColoredBox>(
            find
                .descendant(
                  of: find.byType(RootView),
                  matching: find.byType(ColoredBox),
                )
                .first,
          );
          expect(
            background.color,
            phone == Brightness.dark
                ? const Color(0xFF0A0A0A)
                : const Color(0xFFF2F2F7),
          );
          await tester.pump(const Duration(milliseconds: 180));
          expect(logo(), findsNothing);
          expect(
            Theme.of(tester.element(find.byType(AppLoader))).brightness,
            phone == Brightness.dark ? Brightness.light : Brightness.dark,
          );
        },
      );
    }

    testWidgets('ColdLaunchLoading_FadeThroughNeverOverlapsArtworks', (
      tester,
    ) async {
      final h = SessionHarness()..auth.status = AuthStatus.loading;
      await pumpLaunch(tester, h);
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('launch-frame')),
      );
      Future<Uint8List> pixels() => tester
          .runAsync(() async {
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            image.dispose();
            return bytes;
          })
          .then((value) => value!);

      Future<bool> paintsPixels(Finder artwork, Uint8List frame) async {
        // Hide only this artwork at the same animation clock, then compare
        // rendered pixels. A mounted but transparent artwork must paint none.
        RenderObject? parent = tester.renderObject(artwork);
        while (parent != null && parent is! RenderOpacity) {
          parent = parent.parent;
        }
        final opacity = parent! as RenderOpacity;
        final original = opacity.opacity;
        opacity.opacity = 0;
        tester.binding.rootPipelineOwner.flushCompositingBits();
        tester.binding.rootPipelineOwner.flushPaint();
        final hidden = await pixels();
        opacity.opacity = original;
        tester.binding.rootPipelineOwner.flushCompositingBits();
        tester.binding.rootPipelineOwner.flushPaint();
        return !listEquals(frame, hidden);
      }

      var previousMs = 0;
      final backdropPixels = <List<int>>[];
      for (final ms in [45, 89, 90, 91, 135, 180]) {
        await tester.pump(Duration(milliseconds: ms - previousMs));
        previousMs = ms;
        final frame = await pixels();
        if (ms < 180) {
          expect(
            await paintsPixels(logo(), frame),
            ms < 90,
            reason: '$ms ms logo',
          );
        } else {
          expect(logo(), findsNothing);
        }
        expect(
          await paintsPixels(find.byType(AppLoader), frame),
          ms > 90,
          reason: '$ms ms Lottie',
        );
        final sample = (10 * boundary.size.width.round() + 10) * 4;
        backdropPixels.add(frame.sublist(sample, sample + 3));
      }
      expect(backdropPixels[0], isNot(backdropPixels[2]));
      expect(backdropPixels[2], isNot(backdropPixels[4]));
      expect(backdropPixels[4], isNot(backdropPixels[5]));
    });

    testWidgets('AuthToBootstrap_DoesNotReplayBrandBridge', (tester) async {
      final held = Completer<http.Response>();
      final h = SessionHarness(
        respond: (r) async =>
            r.url.path.endsWith('/User/Me/All') ? held.future : null,
      )..auth.status = AuthStatus.loading;
      await pumpLaunch(tester, h);
      expect(logo(), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 180));
      expect(logo(), findsNothing);
      expect(find.byType(AppLoader), findsOneWidget);
      h.auth.status = AuthStatus.authenticated;
      h.auth.notifyListeners();
      await tester.pump();
      await tester.pump();
      expect(logo(), findsNothing);
      expect(find.byType(AppLoader), findsOneWidget);
      held.complete(jsonResponse({'title': 'Offline', 'status': 503}, 503));
      await tester.pump();
      await tester.pump();
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(AppLoader), findsNothing);
      expect(logo(), findsNothing);
    });

    testWidgets('ReducedMotion_SkipsBridgeAnimation', (tester) async {
      final h = SessionHarness()..auth.status = AuthStatus.loading;
      await pumpLaunch(tester, h, reducedMotion: true);
      expect(logo(), findsNothing);
      expect(find.byType(AppLoader), findsOneWidget);
    });

    for (final elapsedMs in [45, 135]) {
      testWidgets('ReadySignIn_CancelsBridge at $elapsedMs ms', (tester) async {
        final h = SessionHarness()..auth.status = AuthStatus.loading;
        await pumpLaunch(tester, h);
        await tester.pump(Duration(milliseconds: elapsedMs));
        h.auth.status = AuthStatus.unauthenticated;
        h.auth.notifyListeners();
        await tester.pump();
        expect(find.text('Sign in'), findsOneWidget);
        expect(logo(), findsNothing);
        expect(find.byType(AppLoader), findsNothing);
      });
    }

    for (final elapsedMs in [60, 135]) {
      testWidgets('BootstrapFailure_ShowsRetryNotSplash at $elapsedMs ms', (
        tester,
      ) async {
        final first = Completer<http.Response>();
        final retry = Completer<http.Response>();
        var attempts = 0;
        final h = SessionHarness(
          respond: (r) async {
            if (!r.url.path.endsWith('/User/Me/All')) return null;
            return ++attempts == 1 ? first.future : retry.future;
          },
        );
        await pumpLaunch(tester, h);
        await tester.pump(Duration(milliseconds: elapsedMs));
        expect(logo(), findsOneWidget);
        first.complete(jsonResponse({'title': 'Offline', 'status': 503}, 503));
        await tester.pump();
        await tester.pump();
        expect(find.text('Try again'), findsOneWidget);
        expect(logo(), findsNothing);
        expect(find.byType(AppLoader), findsNothing);
        await tester.tap(find.text('Try again'));
        await tester.pump();
        expect(logo(), findsNothing, reason: 'retry is not a cold launch');
        expect(find.byType(AppLoader), findsOneWidget);
        retry.complete(jsonResponse({'title': 'Offline', 'status': 503}, 503));
        await tester.pump();
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('SignedOut_DoesNotWaitForBrandAnimation or replay on resume', (
      tester,
    ) async {
      final h = SessionHarness()..auth.status = AuthStatus.unauthenticated;
      await pumpLaunch(tester, h);
      expect(find.text('Sign in'), findsOneWidget);
      expect(logo(), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Sign in'), findsOneWidget);
      expect(logo(), findsNothing);
    });

    testWidgets('SavedToday_DoesNotWaitForBrandAnimation', (tester) async {
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
      await pumpLaunch(tester, h);
      await tester.pump();
      await tester.pump();
      expect(find.text('Read a chapter'), findsWidgets);
      expect(find.bySemanticsLabel('Loading LazyTax'), findsNothing);
      held.complete(
        jsonResponse({
          'principal': {'active': true, 'emailVerified': true},
        }),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('LaterPageLoading_DoesNotReplayLogo', (tester) async {
      final h = SessionHarness()..auth.status = AuthStatus.unauthenticated;
      await pumpLaunch(tester, h);
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(MaterialPageRoute(builder: (_) => const GlassLoadingScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(logo(), findsNothing);
      expect(find.byType(AppLoader), findsOneWidget);
    });
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

  test('an overview saved by the previous version (no sortOrder) still '
      'loads, so Today opens at once', () async {
    final habit = (overviewBody()['habits'] as List).single as Map;
    expect(habit.containsKey('sortOrder'), isFalse);
    await File('${dir.path}/session_cache.json').writeAsString(
      jsonEncode({
        'userId': 'u1',
        'config': config.toJson(),
        'overview': overviewBody(),
        'savedAt': DateTime.now().toIso8601String(),
      }),
    );
    final s = await cache.load('u1');
    expect(s, isNotNull);
    expect(s!.overview.habits!.single.name, 'Read a chapter');
    expect(s.overview.habits!.single.sortOrder, isNull);
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
