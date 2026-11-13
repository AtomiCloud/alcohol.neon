import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Tristate;

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/core/date_format.dart';
import 'package:alcohol_neon/core/problem.dart';
import 'package:alcohol_neon/data/subscription_repository.dart';
import 'package:alcohol_neon/features/charity/charity_picker.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_controller.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_view.dart';
import 'package:alcohol_neon/features/dashboard/today_layout.dart';
import 'package:alcohol_neon/features/payment/consent_service.dart';
import 'package:alcohol_neon/features/payment/payment_consent_collector.dart';
import 'package:alcohol_neon/features/settings/settings_view.dart';
import 'package:alcohol_neon/features/settings/timezone_picker.dart';
import 'package:alcohol_neon/features/subscription/subscription_controller.dart';
import 'package:alcohol_neon/features/subscription/subscription_view.dart';
import 'package:alcohol_neon/features/vacation/vacation_controller.dart';
import 'package:alcohol_neon/features/vacation/vacation_create_view.dart';
import 'package:alcohol_neon/features/vacation/vacation_list_view.dart';
import 'package:alcohol_neon/generated/zinc/models/charity_principal_res.dart';
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:alcohol_neon/services/storefront_service.dart';
import 'package:alcohol_neon/services/widget_service.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:alcohol_neon/widgets/glass_list.dart';
import 'package:alcohol_neon/widgets/glass_modal.dart';
import 'package:alcohol_neon/widgets/glass_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

const platforms = [TargetPlatform.iOS, TargetPlatform.android];

/// Pumps a home page with an Open button that pushes [page], so the page can
/// pop a result. Returns what it popped through [result].
Future<void> pumpPushed(
  WidgetTester tester,
  WidgetBuilder page, {
  required TargetPlatform platform,
  SessionHarness? harness,
  void Function(Object?)? result,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = MaterialApp(
    theme: AppTheme.light.copyWith(platform: platform),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              final r = await Navigator.of(
                context,
              ).push<Object?>(MaterialPageRoute(builder: page));
              result?.call(r);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    harness == null
        ? app
        : MultiProvider(
            providers: [
              ChangeNotifierProvider<SessionController>.value(
                value: harness.session,
              ),
              ChangeNotifierProvider<AuthService>.value(value: harness.auth),
            ],
            child: app,
          ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> tearDownHarness(WidgetTester tester, SessionHarness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  h.dispose();
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

Map<String, Object?> _vacation(String id, int fromDays, int toDays) => {
  'id': id,
  'startDate': formatStandardDate(_today().add(Duration(days: fromDays))),
  'endDate': formatStandardDate(_today().add(Duration(days: toDays))),
  'timezone': 'Asia/Singapore',
};

Iterable<http.Request> _calls(SessionHarness h, String method, String path) =>
    h.requests.where((r) => r.method == method && r.url.path.endsWith(path));

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  const timezoneChannel = MethodChannel('flutter_timezone');

  setUpAll(loadHarnessConfig);
  setUp(() {
    messenger.setMockMethodCallHandler(timezoneChannel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(timezoneChannel, null));

  group('Vacations', () {
    // One on now, one coming up, one long past.
    Future<http.Response?> vacations(http.Request r) async {
      if (r.method == 'GET' && r.url.path.endsWith('/Vacation/user-1')) {
        return jsonResponse([
          _vacation('v1', -2, 3),
          _vacation('v2', 30, 34),
          _vacation('v3', -60, -56),
        ]);
      }
      if (r.method == 'DELETE') return http.Response('', 204);
      return null;
    }

    for (final platform in platforms) {
      final ios = platform == TargetPlatform.iOS;

      testWidgets('${platform.name}: the active vacation leads, past ones '
          'fold away, and scheduling is a ${ios ? 'bar +' : 'floating +'}', (
        tester,
      ) async {
        final h = SessionHarness(respond: vacations);
        await h.start();
        await pumpPushed(
          tester,
          (_) => const VacationListView(),
          platform: platform,
          harness: h,
        );

        expect(find.text('On vacation now'), findsOneWidget);
        expect(find.text('4 days left'), findsOneWidget);
        expect(find.text('End today'), findsOneWidget);
        expect(find.text('Coming up'), findsOneWidget);
        // Past vacations stay folded until asked for.
        expect(find.text('1 past vacation'), findsOneWidget);
        expect(find.text('3 – 7 Aug'), findsNothing);
        await tester.tap(find.text('1 past vacation'));
        await tester.pumpAndSettle();
        expect(find.text('1 past vacation'), findsNothing);
        expect(find.text('Hide'), findsOneWidget);

        expect(
          find.widgetWithIcon(GlassIconButton, Icons.add_rounded),
          ios ? findsOneWidget : findsNothing,
        );
        expect(
          find.byType(FloatingActionButton),
          ios ? findsNothing : findsOneWidget,
        );
        await tearDownHarness(tester, h);
      });

      testWidgets('${platform.name}: swiping an upcoming vacation asks, then '
          'deletes it', (tester) async {
        final h = SessionHarness(respond: vacations);
        await h.start();
        await pumpPushed(
          tester,
          (_) => const VacationListView(),
          platform: platform,
          harness: h,
        );

        await tester.drag(
          find.byKey(const ValueKey('vacation-v2')),
          const Offset(-600, 0),
        );
        await tester.pumpAndSettle();
        expect(find.text('Delete this vacation?'), findsOneWidget);
        expect(_calls(h, 'DELETE', '/v2'), isEmpty);
        await tester.tap(
          ios
              ? find.widgetWithText(CupertinoActionSheetAction, 'Delete')
              : find.widgetWithText(TextButton, 'Delete'),
        );
        await tester.pumpAndSettle();
        expect(_calls(h, 'DELETE', '/Vacation/user-1/v2'), hasLength(1));
        await tearDownHarness(tester, h);
      });
    }

    testWidgets('android: pressing and holding a vacation also deletes it', (
      tester,
    ) async {
      final h = SessionHarness(respond: vacations);
      await h.start();
      await pumpPushed(
        tester,
        (_) => const VacationListView(),
        platform: TargetPlatform.android,
        harness: h,
      );
      await tester.longPress(find.byKey(const ValueKey('vacation-v2')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(_calls(h, 'DELETE', '/Vacation/user-1/v2'), hasLength(1));
      await tearDownHarness(tester, h);
    });

    for (final platform in platforms) {
      testWidgets('${platform.name}: scheduling picks the first and last day '
          'on the page calendar', (tester) async {
        final h = SessionHarness(
          respond: (r) async {
            if (r.url.path.endsWith('/Vacation/user-1')) {
              return r.method == 'POST'
                  ? jsonResponse({'id': 'v9', ...jsonDecode(r.body) as Map})
                  : jsonResponse(<Object>[]);
            }
            return null;
          },
        );
        await h.start();
        final controller = VacationController(h.session);
        Object? popped;
        await pumpPushed(
          tester,
          (_) => ChangeNotifierProvider.value(
            value: controller,
            child: const VacationCreateView(),
          ),
          platform: platform,
          harness: h,
          result: (r) => popped = r,
        );

        final button = find.widgetWithText(GlassButton, 'Schedule vacation');
        expect(tester.widget<GlassButton>(button).onPressed, isNull);

        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('10'));
        await tester.pumpAndSettle();
        expect(find.text('Now tap the last day.'), findsOneWidget);
        await tester.tap(find.text('12'));
        await tester.pumpAndSettle();
        expect(find.text('3 days'), findsOneWidget);

        await tester.tap(button);
        await tester.pumpAndSettle();
        final next = DateTime(_today().year, _today().month + 1);
        final body =
            jsonDecode(_calls(h, 'POST', '/Vacation/user-1').single.body)
                as Map;
        expect(body['startDate'], formatStandardDate(next.copyWith(day: 10)));
        expect(body['endDate'], formatStandardDate(next.copyWith(day: 12)));
        expect(popped, true);
        controller.dispose();
        await tearDownHarness(tester, h);
      });
    }
  });

  group('Subscription', () {
    final plans = [
      {
        'key': 'pro',
        'priceCents': 500,
        'habitsUnlimited': true,
        'skipsMonthly': 5,
        'vacationWindowsYearly': 4,
        'freezeBase': 1,
      },
      {
        'key': 'free',
        'priceCents': 0,
        'habitsMax': 3,
        'habitsUnlimited': false,
        'skipsMonthly': 2,
        'vacationWindowsYearly': 1,
        'freezeBase': 0,
      },
    ];

    Future<void> pump(WidgetTester tester, String variant) async {
      final c = SubscriptionController(
        repository: SubscriptionRepository(
          ApiClient(
            baseUrl: Uri.parse('https://zinc.test'),
            tokenProvider: () async => 'token',
            client: MockClient(
              (req) async => http.Response(
                jsonEncode(
                  req.url.path.endsWith('/plans')
                      ? plans
                      : {'variant': variant, 'tier': 'free'},
                ),
                200,
                headers: {'content-type': 'application/json'},
              ),
            ),
          ),
        ),
        storefront: _Storefront(),
        userId: 'user-1',
        launcher: (_) async => true,
      );
      addTearDown(c.dispose);
      await c.load();
      await tester.pumpWidget(
        MaterialApp(home: SubscriptionView(controller: c)),
      );
      await tester.pump();
    }

    testWidgets('lists what the plan includes and, where allowed, what the '
        'next plan adds', (tester) async {
      await pump(tester, 'subscribe');
      expect(find.text('Free includes'), findsOneWidget);
      expect(find.text('Up to 3 habits'), findsOneWidget);
      expect(find.text('2 skips each month'), findsOneWidget);
      expect(find.text('1 vacation each year'), findsOneWidget);
      expect(find.text('Pro adds'), findsOneWidget);
      expect(find.text('Unlimited habits'), findsOneWidget);
      expect(find.text('5 skips each month'), findsOneWidget);
      expect(find.text('4 vacations each year'), findsOneWidget);
      expect(
        find.widgetWithText(GlassButton, 'Subscribe on the web'),
        findsOneWidget,
      );
    });

    testWidgets('a restricted storefront shows only its own plan', (
      tester,
    ) async {
      await pump(tester, 'neutral');
      expect(find.text('Free includes'), findsOneWidget);
      expect(find.text('Up to 3 habits'), findsOneWidget);
      expect(find.text('Pro adds'), findsNothing);
      expect(find.text('Unlimited habits'), findsNothing);
      expect(find.byType(GlassButton), findsNothing);
    });
  });

  group('Charity picker', () {
    Future<http.Response?> charities(http.Request r) async {
      final path = r.url.path;
      if (path.endsWith('/Charity/supported-countries')) {
        return jsonResponse(['SG', 'US']);
      }
      if (path.endsWith('/Charity')) {
        return jsonResponse([
          {
            'id': 'ch1',
            'name': 'Red Cross',
            'countries': ['SG'],
          },
          {
            'id': 'ch2',
            'name': 'Furkids',
            'countries': ['SG'],
          },
        ]);
      }
      if (path.endsWith('/Charity/ch2')) {
        return jsonResponse({
          'principal': {
            'id': 'ch2',
            'name': 'Furkids',
            'mission': 'Rescues and rehomes cats in Singapore.',
          },
        });
      }
      return null;
    }

    for (final platform in platforms) {
      testWidgets('${platform.name}: marks the current charity, and its info '
          'button lets you read one before choosing it', (tester) async {
        final h = SessionHarness(respond: charities);
        await h.start();
        Object? picked;
        await pumpPushed(
          tester,
          (_) => CharityPicker(
            repository: h.session.charities,
            causeRepository: h.session.causes,
            selectedId: 'ch1',
          ),
          platform: platform,
          harness: h,
          result: (r) => picked = r,
        );

        expect(find.text('Selected · SG'), findsOneWidget);
        await tester.tap(find.byTooltip('About Furkids'));
        await tester.pumpAndSettle();
        expect(
          find.text('Rescues and rehomes cats in Singapore.'),
          findsOneWidget,
        );
        await tester.tap(
          find.widgetWithText(GlassButton, 'Choose this charity'),
        );
        await tester.pumpAndSettle();
        expect((picked as CharityPrincipalRes?)?.id, 'ch2');
        await tearDownHarness(tester, h);
      });
    }

    testWidgets('the Country pill opens a sheet that filters the search', (
      tester,
    ) async {
      final h = SessionHarness(respond: charities);
      await h.start();
      await pumpPushed(
        tester,
        (_) => CharityPicker(repository: h.session.charities),
        platform: TargetPlatform.android,
        harness: h,
      );
      await tester.tap(find.text('Country: Any'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('US'));
      await tester.pumpAndSettle();
      expect(find.text('Country: US'), findsOneWidget);
      expect(
        _calls(h, 'GET', '/Charity').last.url.queryParameters['Country'],
        'US',
      );
      await tearDownHarness(tester, h);
    });
  });

  testWidgets('the timezone list groups cities by region and searches them', (
    tester,
  ) async {
    Object? picked;
    await pumpPushed(
      tester,
      (_) => const TimezonePicker(
        timezones: [
          'America/Argentina/Buenos_Aires',
          'America/New_York',
          'Asia/Singapore',
          'Asia/Tokyo',
          'UTC',
        ],
        selected: 'Asia/Tokyo',
      ),
      platform: TargetPlatform.iOS,
      result: (r) => picked = r,
    );
    for (final region in ['America', 'Asia', 'Other']) {
      expect(find.text(region), findsOneWidget);
    }
    expect(find.text('Buenos Aires'), findsOneWidget);
    expect(find.text('Argentina'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('Asia/Tokyo')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'new york');
    await tester.pumpAndSettle();
    expect(find.text('Asia'), findsNothing);
    await tester.tap(find.text('New York'));
    await tester.pumpAndSettle();
    expect(picked, 'America/New_York');
  });

  testWidgets('an open glass sheet repaints when the phone switches to light '
      'mode', (tester) async {
    final mode = ValueNotifier(ThemeMode.dark);
    await tester.pumpWidget(
      ValueListenableBuilder(
        valueListenable: mode,
        builder: (_, m, _) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: m,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showGlassSheet<void>(context, (_) => const Text('Sheet')),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // The nearest ancestor that paints a colour behind the sheet's content.
    Color? surface() {
      for (final w in tester.widgetList(
        find.ancestor(
          of: find.text('Sheet'),
          matching: find.byWidgetPredicate((_) => true),
        ),
      )) {
        final color = switch (w) {
          Material(:final color) => color,
          DecoratedBox(decoration: BoxDecoration(:final color)) => color,
          _ => null,
        };
        if (color != null && color.a > 0) return color;
      }
      return null;
    }

    expect(surface(), const Color(0xF51C1C1E));
    mode.value = ThemeMode.light;
    await tester.pumpAndSettle();
    expect(surface(), const Color(0xF7F2F2F7));
  });

  group('Payment consent', () {
    setUp(() {
      messenger.setMockMethodCallHandler(
        timezoneChannel,
        (call) async => call.method == 'getLocalTimezone'
            ? 'Asia/Singapore'
            : ['Asia/Singapore'],
      );
    });

    Future<void> settings(WidgetTester tester, SessionHarness h) => pumpPushed(
      tester,
      (_) => const SettingsView(),
      platform: TargetPlatform.android,
      harness: h,
    );

    for (final failure in ['404', '401', '500', 'decode', 'network']) {
      testWidgets(
        'ConsentStatusFailure_ShowsRetryNotEmptyOrVerified: $failure',
        (tester) async {
          var failing = true;
          final h = SessionHarness(
            respond: (r) async {
              if (!r.url.path.endsWith('/consent') || !failing) return null;
              if (failure == 'network') throw http.ClientException('offline');
              if (failure == 'decode') {
                return jsonResponse({'unexpected': true});
              }
              final status = int.parse(failure);
              return jsonResponse({
                'title': 'Unavailable',
                'status': status,
              }, status);
            },
          );
          await h.start();
          await settings(tester, h);
          expect(find.text('Card status unavailable'), findsOneWidget);
          expect(find.text('No card on file'), findsNothing);
          expect(find.text('Card on file'), findsNothing);
          expect(find.text('Retry'), findsOneWidget);
          expect(find.text('Follow phone'), findsOneWidget);
          failing = false;
          await tester.ensureVisible(find.text('Retry'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(find.text('No card on file'), findsOneWidget);
          expect(find.text('Add card'), findsOneWidget);
          expect(_calls(h, 'PUT', '/Payment/user-1/customers'), isEmpty);
          expect(_calls(h, 'GET', '/Payment/user-1/client-secret'), isEmpty);
          await tearDownHarness(tester, h);
        },
      );
    }

    testWidgets('ConsentStatus_IncompleteShowsFinishSetup', (tester) async {
      final h = SessionHarness(
        respond: (r) async => r.url.path.endsWith('/consent')
            ? jsonResponse({
                'hasPaymentConsent': false,
                'consentId': 'incomplete',
                'status': 'PENDING',
              })
            : null,
      );
      await h.start();
      await settings(tester, h);
      expect(find.text('Card setup incomplete'), findsOneWidget);
      expect(find.text('Finish setup to use money stakes.'), findsOneWidget);
      await tester.ensureVisible(find.text('Finish setup'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish setup'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Add a card to stake'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      await tearDownHarness(tester, h);
    });

    testWidgets(
      'large-text card status and explainer actions stay accessible',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final semantics = tester.ensureSemantics();
        final h = SessionHarness(
          respond: (r) async => r.url.path.endsWith('/consent')
              ? jsonResponse({'hasPaymentConsent': false, 'status': 'PENDING'})
              : null,
        );
        await h.start();
        await settings(tester, h);
        await tester.scrollUntilVisible(
          find.text('Finish setup'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        final title = tester.renderObject<RenderParagraph>(
          find.text('Card setup incomplete'),
        );
        expect(title.didExceedMaxLines, isFalse);
        final button = tester.getSemantics(
          find.widgetWithText(GlassButton, 'Finish setup'),
        );
        expect(button.flagsCollection.isButton, isTrue);
        expect(button.flagsCollection.isEnabled, Tristate.isTrue);
        await tester.tap(find.text('Finish setup'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Continue'));
        await tester.pump();
        final continueButton = tester.getSemantics(
          find.widgetWithText(GlassButton, 'Continue'),
        );
        expect(continueButton.flagsCollection.isButton, isTrue);
        expect(continueButton.flagsCollection.isEnabled, Tristate.isTrue);
        await tester.ensureVisible(find.text('Not now'));
        await tester.pump();
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
        expect(find.text('Card setup incomplete'), findsOneWidget);
        expect(_calls(h, 'PUT', '/Payment/user-1/customers'), isEmpty);
        await tearDownHarness(tester, h);
        semantics.dispose();
      },
    );

    testWidgets('SettingsFalseStatus_ReplacesStaleVerifiedSessionBeforeSetup', (
      tester,
    ) async {
      var verified = true;
      final h = SessionHarness(
        respond: (r) async => r.url.path.endsWith('/consent')
            ? jsonResponse({'hasPaymentConsent': verified})
            : null,
      );
      await h.start();
      expect(h.session.hasPaymentConsent, isTrue);
      verified = false;
      await settings(tester, h);
      await tester.ensureVisible(find.text('Add card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add card'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Add a card to stake'), findsOneWidget);
      expect(find.text('Card added'), findsNothing);
      expect(h.session.hasPaymentConsent, isFalse);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text('Payment setup cancelled'), findsNothing);
      expect(find.text('Add card'), findsOneWidget);
      expect(_calls(h, 'PUT', '/Payment/user-1/customers'), isEmpty);
      await tearDownHarness(tester, h);
    });

    testWidgets('RemoveThenRefreshFailure_ShowsUnknownNotVerified', (
      tester,
    ) async {
      var removed = false;
      final h = SessionHarness(
        respond: (r) async {
          if (!r.url.path.endsWith('/consent')) return null;
          if (r.method == 'DELETE') {
            removed = true;
            return http.Response('', 204);
          }
          return removed
              ? jsonResponse({'title': 'Offline', 'status': 503}, 503)
              : jsonResponse({'hasPaymentConsent': true});
        },
      );
      await h.start();
      await settings(tester, h);
      await tester.ensureVisible(find.text('Remove card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove card'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove card'));
      await tester.pumpAndSettle();
      expect(find.text('Card status unavailable'), findsOneWidget);
      expect(find.text('Card on file'), findsNothing);
      expect(find.text('Card removed'), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      expect(h.session.hasPaymentConsent, isFalse);
      await tearDownHarness(tester, h);
    });

    testWidgets(
      'status loading keeps other Settings usable and has no action',
      (tester) async {
        final pending = Completer<http.Response>();
        var loading = false;
        final h = SessionHarness(
          respond: (r) async => loading && r.url.path.endsWith('/consent')
              ? pending.future
              : null,
        );
        await h.start();
        loading = true;
        // pumpAndSettle cannot settle the loading indicator.
        await tester.pumpWidget(
          ChangeNotifierProvider<SessionController>.value(
            value: h.session,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const SettingsView(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Checking card status…'), findsOneWidget);
        expect(find.text('Follow phone'), findsOneWidget);
        expect(find.text('Add card'), findsNothing);
        expect(find.text('Remove card'), findsNothing);
        pending.complete(jsonResponse({'hasPaymentConsent': false}));
        await tester.pumpAndSettle();
        expect(find.text('No card on file'), findsOneWidget);
        await tearDownHarness(tester, h);
      },
    );

    for (final outcome in ['success', 'cancelled', 'failed']) {
      testWidgets('Settings native $outcome: only confirmed GET saves a card', (
        tester,
      ) async {
        const channel = MethodChannel(
          'airwallex_payment_flutter',
          JSONMethodCodec(),
        );
        final sheet = Completer<Map<String, String>>();
        var forms = 0;
        var polling = false;
        var reads = 0;
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method != 'presentCardPaymentFlow') return null;
          forms++;
          final result = await sheet.future;
          if (outcome == 'failed') {
            throw PlatformException(
              code: 'failed',
              message: 'Please try again.',
            );
          }
          return result;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final h = SessionHarness(
          respond: (r) async {
            if (r.url.path.endsWith('/customers')) {
              return jsonResponse({'customerId': 'customer'});
            }
            if (r.url.path.endsWith('/client-secret')) {
              return jsonResponse({
                'customerId': 'customer',
                'clientSecret': 'fake-secret',
              });
            }
            if (r.url.path.endsWith('/consent') && polling) {
              reads++;
              if (reads == 2) return jsonResponse({'status': 503}, 503);
              // A redundant read after the verifying response would erase it.
              return jsonResponse({
                'hasPaymentConsent': reads == 3,
                'consentId': reads == 3 ? 'verified' : null,
              });
            }
            return null;
          },
        );
        await h.start();
        await settings(tester, h);
        await tester.ensureVisible(find.text('Add card'));
        await tester.pumpAndSettle();
        final addCard = tester.getCenter(find.text('Add card'));
        await tester.tapAt(addCard);
        await tester.tapAt(addCard);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(ConsentExplainer), findsOneWidget);
        expect(_calls(h, 'PUT', '/Payment/user-1/customers'), isEmpty);
        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(forms, 1);
        expect(find.text('Card added'), findsNothing);
        expect(h.session.hasPaymentConsent, isFalse);
        polling = true;
        sheet.complete({'status': outcome});
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        if (outcome == 'success') {
          expect(find.text('Confirming your card…'), findsOneWidget);
          expect(find.text('Card added'), findsNothing);
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pumpAndSettle();
        if (outcome == 'success') {
          expect(find.text('Card on file'), findsOneWidget);
          expect(find.text('Card added'), findsOneWidget);
          expect(h.session.consent?.consentId, 'verified');
        } else {
          expect(find.text('No card on file'), findsOneWidget);
          expect(find.text('Add card'), findsOneWidget);
          expect(find.text('Card added'), findsNothing);
          expect(find.text('Payment setup cancelled'), findsNothing);
          expect(
            find.text('Please try again.'),
            outcome == 'failed' ? findsOneWidget : findsNothing,
          );
        }
        expect(_calls(h, 'PUT', '/Payment/user-1/customers'), hasLength(1));
        expect(
          h.requests.where((r) => r.url.path.contains('/intent')),
          isEmpty,
        );
        expect(
          h.requests.where((r) => r.url.query.contains('subscription')),
          isEmpty,
        );
        await tearDownHarness(tester, h);
      });
    }

    Future<http.Response?> customer(http.Request r) async {
      if (r.url.path.endsWith('/Payment/user-1/customers')) {
        return jsonResponse({'customerId': 'c1', 'clientSecret': 's1'});
      }
      return null;
    }

    testWidgets(
      'confirmation times out at two minutes without claiming success',
      (tester) async {
        final h = SessionHarness(respond: customer);
        await h.start();
        final service = ConsentService(
          h.session,
          now: tester.binding.clock.now,
          collectorFactory: () =>
              _Collector(result: ConsentCollectResult.success()),
        );
        Result<void>? result;
        await pumpPushed(
          tester,
          (_) => Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async =>
                    result = await service.ensureConsent(context),
                child: const Text('Stake'),
              ),
            ),
          ),
          platform: TargetPlatform.android,
          harness: h,
        );
        await tester.tap(find.text('Stake'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pump();
        for (var i = 0; i < 119; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(result, isNull);
        expect(find.text('Confirming your card…'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(result, isA<Err<void>>());
        expect(
          (result as Err<void>).problem.title,
          'Payment setup is taking longer than expected',
        );
        expect(h.session.hasPaymentConsent, isFalse);
        expect(find.text('Confirming your card…'), findsNothing);
        await tearDownHarness(tester, h);
      },
    );

    for (final continueOn in [false, true]) {
      testWidgets(
        'the glass sheet explains the card; '
        '${continueOn ? 'Continue opens the card form' : 'Not now cancels'}',
        (tester) async {
          final h = SessionHarness(respond: customer);
          await h.start();
          final collector = _Collector();
          final service = ConsentService(
            h.session,
            collectorFactory: () => collector,
          );
          Result<void>? result;
          await pumpPushed(
            tester,
            (_) => Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async =>
                        result = await service.ensureConsent(context),
                    child: const Text('Stake'),
                  ),
                ),
              ),
            ),
            platform: TargetPlatform.iOS,
            harness: h,
          );
          await tester.tap(find.text('Stake'));
          await tester.pumpAndSettle();

          expect(find.text('Add a card to stake'), findsOneWidget);
          expect(find.text('Charged only when you miss'), findsOneWidget);
          expect(find.text('Kept by Airwallex'), findsOneWidget);
          // Looking at or declining the explanation must not create anything.
          expect(_calls(h, 'PUT', '/Payment/user-1/customers'), isEmpty);
          expect(_calls(h, 'GET', '/Payment/user-1/client-secret'), isEmpty);
          await tester.tap(
            continueOn
                ? find.widgetWithText(GlassButton, 'Continue')
                : find.text('Not now'),
          );
          await tester.pumpAndSettle();

          expect(collector.calls, continueOn ? 1 : 0);
          expect(
            _calls(h, 'PUT', '/Payment/user-1/customers'),
            hasLength(continueOn ? 1 : 0),
          );
          expect(result, isA<Err<void>>());
          await tearDownHarness(tester, h);
        },
      );
    }
  });

  group('Today with more than 20 habits', () {
    // zinc sends 20 habits unless asked for more.
    test('the plan and the widget payload count all 25', () async {
      final h = SessionHarness(habits: manyHabits(25));
      await h.start();
      final c = DashboardController(h.session);
      await c.load();
      expect(c.plan.scheduled, 25);
      expect(widgetSchedule(c.plan, DateTime.now())['total'], 25);
      c.dispose();
      h.dispose();
    });

    for (final platform in platforms) {
      for (final layout in TodayLayout.values) {
        testWidgets('${platform.name}, ${layout.name}: Today shows the 21st '
            'habit after scrolling', (tester) async {
          TodayLayoutSetting.instance.value = layout;
          addTearDown(
            () => TodayLayoutSetting.instance.value = TodayLayout.nextUp,
          );
          final h = SessionHarness(habits: manyHabits(25));
          await h.start();
          await pumpPushed(
            tester,
            (_) => const DashboardView(),
            platform: platform,
            harness: h,
          );

          await tester.scrollUntilVisible(
            find.text('Habit 21'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.text('Habit 21'), findsOneWidget);
          if (layout == TodayLayout.nextUp) {
            expect(find.text('0/25'), findsOneWidget);
          }
          await tearDownHarness(tester, h);
        });
      }
    }
  });
}

class _Storefront implements StorefrontService {
  @override
  Future<StorefrontInfo> resolve() async =>
      const StorefrontInfo(platform: 'ios', countryCode: 'US');
}

/// Airwallex's card form, which the user closes.
class _Collector implements PaymentConsentCollector {
  _Collector({this.result});
  final ConsentCollectResult? result;
  int calls = 0;
  @override
  Future<ConsentCollectResult> collect({
    required String? customerId,
    required String? clientSecret,
  }) async {
    calls++;
    return result ?? ConsentCollectResult.cancelled();
  }
}
