import 'dart:async';
import 'dart:convert';

import 'package:alcohol_neon/core/navigation.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_view.dart';
import 'package:alcohol_neon/features/habit/habit_editor_view.dart';
import 'package:alcohol_neon/features/nfc/nfc_deep_links.dart';
import 'package:alcohol_neon/features/onboarding/onboarding_view.dart';
import 'package:alcohol_neon/features/onboarding/timezone_picker.dart';
import 'package:alcohol_neon/features/settings/settings_view.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

Future<void> pumpScreen(
  WidgetTester tester,
  SessionHarness harness,
  Widget screen, {
  NfcDeepLinkService? links,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: harness.session),
        if (links != null)
          ChangeNotifierProvider<NfcDeepLinkService>.value(value: links),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        navigatorObservers: [routeObserver],
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  const timezoneChannel = MethodChannel('flutter_timezone');

  setUpAll(loadHarnessConfig);
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'LazyTax',
      packageName: 'cloud.atomi.pichu.alcohol.neon.app',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    messenger.setMockMethodCallHandler(timezoneChannel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(timezoneChannel, null));

  for (final edit in [true, false]) {
    testWidgets(
      'habit ${edit ? 'edit keeps its zone' : 'create uses account default'}',
      (tester) async {
        final h = SessionHarness();
        await h.start();
        await pumpScreen(
          tester,
          h,
          HabitEditorView(habitId: edit ? 'h1' : null),
        );
        if (!edit) {
          await tester.enterText(
            find.byType(TextField).first,
            'Read a chapter',
          );
        }
        final save = find.text(edit ? 'Save changes' : 'Create habit');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final request = h.requests.singleWhere(
          (r) =>
              r.method == (edit ? 'PUT' : 'POST') &&
              r.url.path.contains('/Habit/'),
        );
        expect(
          jsonDecode(request.body)['timezone'],
          edit ? 'America/New_York' : 'Asia/Singapore',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        h.dispose();
      },
    );
  }

  testWidgets('edit never replaces a missing habit zone with account default', (
    tester,
  ) async {
    final h = SessionHarness(
      respond: (r) async =>
          r.url.path.contains('/Habit/') && r.url.path.endsWith('/h1')
          ? jsonResponse({...habitVersion, 'timezone': null})
          : null,
    );
    await h.start();
    await pumpScreen(tester, h, const HabitEditorView(habitId: 'h1'));
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Reload the habit before saving.'), findsOneWidget);
    expect(h.requests.where((r) => r.method == 'PUT'), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  for (final empty in [false, true]) {
    testWidgets(
      'onboarding preserves detected zone when timezone list ${empty ? 'is empty' : 'fails'}',
      (tester) async {
        messenger.setMockMethodCallHandler(timezoneChannel, (call) async {
          if (call.method == 'getLocalTimezone') return 'Asia/Tokyo';
          if (empty) return <String>[];
          throw PlatformException(code: 'unavailable');
        });
        final h = SessionHarness();
        await h.start();
        await pumpScreen(tester, h, const OnboardingView());
        expect(find.text('Asia/Tokyo'), findsOneWidget);
        expect(find.text(timezoneDiscoveryNotice), findsOneWidget);
        await tester.tap(find.text('Timezone'));
        await tester.pumpAndSettle();
        final picker = tester.widget<TimezonePicker>(
          find.byType(TimezonePicker),
        );
        expect(picker.timezones.length, greaterThan(400));
        expect(picker.selected, 'Asia/Tokyo');
        await tester.pumpWidget(const SizedBox.shrink());
        h.dispose();
      },
    );
  }

  testWidgets(
    'onboarding fallback is searchable and retry preserves selection',
    (tester) async {
      final h = SessionHarness();
      await h.start();
      await pumpScreen(tester, h, const OnboardingView());
      expect(find.text(timezoneDiscoveryNotice), findsOneWidget);
      await tester.tap(find.text('Timezone'));
      await tester.pumpAndSettle();
      final picker = tester.widget<TimezonePicker>(find.byType(TimezonePicker));
      expect(picker.timezones.length, greaterThan(400));
      expect(
        picker.timezones,
        containsAll(['Asia/Tokyo', 'America/New_York', 'UTC']),
      );
      await tester.enterText(find.byType(TextField), 'New_York');
      await tester.pumpAndSettle();
      await tester.tap(find.text('America/New York'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry timezone discovery'));
      await tester.pumpAndSettle();
      expect(find.text('America/New York'), findsOneWidget);

      messenger.setMockMethodCallHandler(timezoneChannel, (call) async {
        return call.method == 'getLocalTimezone'
            ? 'Asia/Tokyo'
            : ['Asia/Tokyo'];
      });
      await tester.tap(find.text('Retry timezone discovery'));
      await tester.pumpAndSettle();
      expect(find.text('America/New York'), findsOneWidget);
      expect(find.text(timezoneDiscoveryNotice), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  testWidgets(
    'Settings fallback keeps saved zone and explains its limited scope',
    (tester) async {
      final h = SessionHarness();
      await h.start();
      await pumpScreen(tester, h, const SettingsView());
      expect(find.text('Asia/Singapore'), findsOneWidget);
      expect(find.text(timezoneDiscoveryNotice), findsOneWidget);
      expect(
        find.textContaining('Sets when each habit day ends'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Save changes'), 250);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(find.text('Timezone'), -250);
      await tester.tap(find.text('Retry timezone discovery'));
      await tester.pumpAndSettle();
      expect(find.text('Asia/Singapore'), findsOneWidget);
      await tester.tap(find.text('Timezone'));
      await tester.pumpAndSettle();
      final picker = tester.widget<TimezonePicker>(find.byType(TimezonePicker));
      expect(picker.timezones.length, greaterThan(400));
      expect(picker.selected, 'Asia/Singapore');
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asia/Tokyo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry timezone discovery'));
      await tester.pumpAndSettle();
      expect(find.text('Asia/Tokyo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  for (final skip in [false, true]) {
    testWidgets(
      '${skip ? 'skip' : 'completion'} stays settled after overview failure; Retry only fetches',
      (tester) async {
        var overviewCalls = 0;
        var recover = false;
        final h = SessionHarness(
          respond: (r) async {
            if (!r.url.path.endsWith('/overview')) return null;
            overviewCalls++;
            if (overviewCalls == 1) return jsonResponse(overviewBody());
            return recover
                ? jsonResponse(overviewBody(skip ? 'skip' : 'succeeded'))
                : jsonResponse({'title': 'Offline', 'status': 503}, 503);
          },
        );
        await h.start();
        await pumpScreen(tester, h, const DashboardView());
        await tester.tap(find.text(skip ? 'Skip' : 'Complete'));
        await tester.pumpAndSettle();
        expect(find.text('Could not refresh the dashboard'), findsOneWidget);
        expect(
          find.textContaining('do not submit the action again'),
          findsOneWidget,
        );
        final status = find.text(skip ? 'Skipped today' : 'Completed today');
        await tester.ensureVisible(status);
        expect(status, findsOneWidget);
        expect(find.text('Complete'), findsNothing);
        expect(find.text('Skip'), findsNothing);
        // Even another failed refresh must not re-enable the successful action.
        await tester.ensureVisible(find.text('Retry'));
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(status, findsOneWidget);
        recover = true;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(find.text('Could not refresh the dashboard'), findsNothing);
        expect(status, findsOneWidget);
        expect(
          h.requests.where(
            (r) => r.method == 'POST' && r.url.path.contains('/executions'),
          ),
          hasLength(1),
        );
        expect(overviewCalls, 4);
        await tester.pumpWidget(const SizedBox.shrink());
        h.dispose();
      },
    );
  }

  testWidgets('failed completion stays actionable and shows action error', (
    tester,
  ) async {
    final h = SessionHarness(
      respond: (r) async => r.method == 'POST'
          ? jsonResponse({'title': 'Try later', 'status': 503}, 503)
          : null,
    );
    await h.start();
    await pumpScreen(tester, h, const DashboardView());
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.text('Try later'), findsOneWidget);
    expect(find.text('Complete'), findsOneWidget);
    expect(find.text('Completed today'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  testWidgets(
    'warm NFC completion refreshes mounted dashboard on route return',
    (tester) async {
      var completed = false;
      var overviewCalls = 0;
      final stream = StreamController<Uri>();
      final links = NfcDeepLinkService(links: () => stream.stream)
        ..start(Uri.parse('https://t.test/t/'));
      addTearDown(() async {
        links.dispose();
        await stream.close();
      });
      final h = SessionHarness(
        respond: (r) async {
          if (r.url.path.contains('/NfcTag/')) {
            return jsonResponse({
              'tag': {'id': 'tag12345678', 'userId': 'user-1', 'habitId': 'h1'},
              'habitVersion': habitVersion,
              'today': '09-11-2026',
            });
          }
          if (r.method == 'POST' && r.url.path.contains('/executions')) {
            completed = true;
          }
          if (r.url.path.endsWith('/overview')) {
            overviewCalls++;
            return jsonResponse(
              overviewBody(completed ? 'succeeded' : 'not_applicable'),
            );
          }
          return null;
        },
      );
      await h.start();
      await pumpScreen(
        tester,
        h,
        const NfcTapListener(child: DashboardView()),
        links: links,
      );
      expect(find.text('Complete'), findsOneWidget);
      stream.add(Uri.parse('https://t.test/t/tag12345678'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Done!'), findsOneWidget);
      await tester.tap(find.text('Back to dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Completed today'), findsOneWidget);
      expect(find.text('Complete'), findsNothing);
      expect(overviewCalls, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );
}
