import 'dart:async';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/core/navigation.dart';
import 'package:alcohol_neon/core/problem.dart';
import 'package:alcohol_neon/features/auth/sign_in_view.dart';
import 'package:alcohol_neon/features/dev/dev_config_view.dart';
import 'package:alcohol_neon/features/nfc/link_tag_flow.dart';
import 'package:alcohol_neon/features/nfc/nfc_deep_links.dart';
import 'package:alcohol_neon/features/nfc/tag_inspector_view.dart';
import 'package:alcohol_neon/features/nfc/tap_complete_view.dart';
import 'package:alcohol_neon/features/root/authed_gate.dart';
import 'package:alcohol_neon/features/root/root_view.dart';
import 'package:alcohol_neon/features/strava/strava_proof_tile.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:alcohol_neon/widgets/glass_list.dart';
import 'package:alcohol_neon/widgets/glass_modal.dart';
import 'package:alcohol_neon/widgets/glass_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

const platforms = [TargetPlatform.iOS, TargetPlatform.android];

Future<void> pump(
  WidgetTester tester,
  SessionHarness h,
  Widget home, {
  TargetPlatform platform = TargetPlatform.android,
  AuthService? auth,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final links = NfcDeepLinkService(links: () => const Stream.empty());
  addTearDown(links.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: h.session),
        ChangeNotifierProvider<AuthService>.value(value: auth ?? h.auth),
        ChangeNotifierProvider<NfcDeepLinkService>.value(value: links),
      ],
      child: MaterialApp(
        theme: AppTheme.light.copyWith(platform: platform),
        navigatorObservers: [routeObserver],
        home: home,
      ),
    ),
  );
  await settle(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });
}

/// Today keeps animating its countdown, so step time instead of settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Iterable<http.Request> calls(SessionHarness h, String method, String path) =>
    h.requests.where((r) => r.method == method && r.url.path.contains(path));

http.Response serverError() =>
    jsonResponse({'title': 'Server error', 'status': 500}, 500);

Map<String, Object?> resolution() => {
  'tag': {'id': 'tag-1', 'userId': 'user-1', 'habitId': 'h1'},
  'habitVersion': {
    ...habitVersion,
    'daysOfWeek': [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
  },
  'today': '12-11-2026',
  'todayExecution': null,
};

class FailedAuth extends HarnessAuth {
  FailedAuth(super.client);
  @override
  AuthStatus get status => AuthStatus.failed;
  @override
  Problem? get lastError =>
      Problem.local('Sign-in failed', detail: 'The browser was closed.');
}

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  const timezoneChannel = MethodChannel('flutter_timezone');
  const nfcChannel = MethodChannel('plugins.flutter.io/nfc_manager');

  /// Answers "is NFC available?"; tests hold it open to keep a scan running.
  Future<bool> Function() nfcAvailable = () async => false;

  setUpAll(loadHarnessConfig);
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'LazyTax',
      packageName: 'cloud.atomi.pichu.alcohol.neon.app',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    nfcAvailable = () async => false;
    messenger.setMockMethodCallHandler(timezoneChannel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    messenger.setMockMethodCallHandler(nfcChannel, (call) async {
      if (call.method == 'Nfc#isAvailable') return nfcAvailable();
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(timezoneChannel, null);
    messenger.setMockMethodCallHandler(nfcChannel, null);
  });

  group('NFC', () {
    for (final platform in platforms) {
      testWidgets('${platform.name}: NFC tags is a glass page whose Scan '
          'button docks at the bottom and reports a failed scan as a banner', (
        tester,
      ) async {
        final h = SessionHarness();
        await h.start();
        await pump(tester, h, const TagInspectorView(), platform: platform);

        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(GlassPage), findsOneWidget);
        expect(find.widgetWithText(GlassButton, 'Scan a tag'), findsOneWidget);
        expect(find.text('What does this tag do?'), findsOneWidget);

        await tester.tap(find.text('Scan a tag'));
        await settle(tester);
        expect(
          find.widgetWithText(GlassBanner, 'NFC is not available'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(GlassButton, 'Scan another tag'),
          findsOneWidget,
        );
      });
    }

    testWidgets('a tag tap completes the habit and says so on a glass card', (
      tester,
    ) async {
      final h = SessionHarness(
        respond: (r) async =>
            r.method == 'GET' && r.url.path.contains('/NfcTag/')
            ? jsonResponse(resolution())
            : null,
      );
      await h.start();
      await pump(tester, h, const TapCompleteView(tagId: 'tag-1'));

      expect(calls(h, 'POST', '/v1/executions'), hasLength(1));
      expect(find.byType(AppBar), findsNothing);
      expect(find.widgetWithText(GlassMessage, 'Done!'), findsOneWidget);
      expect(
        find.widgetWithText(GlassButton, 'Back to dashboard'),
        findsOneWidget,
      );
    });

    testWidgets('an unknown tag offers Try again, which resolves it again', (
      tester,
    ) async {
      final h = SessionHarness();
      await h.start();
      await pump(tester, h, const TapCompleteView(tagId: 'tag-1'));

      expect(find.widgetWithText(GlassMessage, 'Unknown tag'), findsOneWidget);
      expect(calls(h, 'GET', '/NfcTag/'), hasLength(1));
      await tester.tap(find.widgetWithText(GlassButton, 'Try again'));
      await settle(tester);
      expect(calls(h, 'GET', '/NfcTag/'), hasLength(2));
    });

    testWidgets('linking a tag scans in a glass sheet that only the scan '
        'closes, then reports the outcome as a glass toast', (tester) async {
      final available = Completer<bool>();
      nfcAvailable = () => available.future;
      final h = SessionHarness();
      await h.start();
      await pump(
        tester,
        h,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: GlassButton(
                label: 'Link',
                onPressed: () => runLinkTagFlow(
                  context,
                  habitId: 'h1',
                  habitName: 'Read a chapter',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Link'));
      await settle(tester);
      expect(find.text('Hold your phone near the NFC tag…'), findsOneWidget);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, Colors.transparent);
      expect(sheet.enableDrag, isFalse);
      await tester.tapAt(const Offset(195, 40));
      await settle(tester);
      expect(find.text('Hold your phone near the NFC tag…'), findsOneWidget);

      available.complete(false);
      await settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
      final toast = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(toast.shape, isA<StadiumBorder>());
      expect(find.textContaining('cannot scan NFC tags'), findsOneWidget);
    });
  });

  group('editor tiles', () {
    testWidgets('the Strava tile is a glass row whose Retry reloads', (
      tester,
    ) async {
      var fail = false;
      final h = SessionHarness(
        respond: (r) async => fail ? serverError() : null,
      );
      await h.start();
      fail = true;
      await pump(
        tester,
        h,
        const Scaffold(
          body: Column(children: [StravaProofTile(habitId: 'h1')]),
        ),
      );

      expect(find.byType(ListTile), findsNothing);
      expect(find.widgetWithText(GlassRow, 'Complete with Strava'), findsOne);
      final retry = find.widgetWithText(GlassTextButton, 'Retry');
      expect(retry, findsOne);

      final before = h.requests.length;
      await tester.tap(retry);
      await settle(tester);
      expect(h.requests.length, greaterThan(before));
    });
  });

  group('Today', () {
    testWidgets('with no habits, Create a habit is the glass button', (
      tester,
    ) async {
      final h = SessionHarness(
        respond: (r) async => r.url.path.endsWith('/overview')
            ? jsonResponse({...overviewBody(), 'habits': <Object>[]})
            : null,
      );
      await pump(tester, h, const AuthedGate());

      expect(
        find.widgetWithText(GlassMessage, 'Make your first habit'),
        findsOneWidget,
      );
      expect(find.widgetWithText(GlassButton, 'Create a habit'), findsOne);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('a failed load shows a glass card whose Retry reloads', (
      tester,
    ) async {
      final h = SessionHarness(
        respond: (r) async =>
            r.url.path.endsWith('/overview') ? serverError() : null,
      );
      await pump(tester, h, const AuthedGate());

      expect(
        find.widgetWithText(GlassMessage, 'Could not load Today'),
        findsOneWidget,
      );
      final before = calls(h, 'GET', '/overview').length;
      await tester.tap(find.widgetWithText(GlassButton, 'Retry'));
      await settle(tester);
      expect(calls(h, 'GET', '/overview').length, before + 1);
    });
  });

  group('launch screens', () {
    testWidgets('sign-in sits on the glass backdrop with a glass button', (
      tester,
    ) async {
      final h = SessionHarness();
      await pump(tester, h, const SignInView());
      expect(find.byType(FilledButton), findsNothing);
      expect(find.widgetWithText(GlassButton, 'Sign in'), findsOneWidget);
    });

    testWidgets('a failed sign-in offers Try again on a glass card', (
      tester,
    ) async {
      final h = SessionHarness();
      await pump(tester, h, const RootView(), auth: FailedAuth(h.client));
      expect(
        find.widgetWithText(GlassMessage, 'Sign-in failed'),
        findsOneWidget,
      );
      expect(find.text('The browser was closed.'), findsOneWidget);
      expect(find.widgetWithText(GlassButton, 'Try again'), findsOneWidget);
    });

    testWidgets('a failed session start offers Try again and Sign out', (
      tester,
    ) async {
      final h = SessionHarness(
        respond: (r) async =>
            r.url.path.endsWith('/User/Me/All') ? serverError() : null,
      );
      await pump(tester, h, const AuthedGate());

      expect(find.widgetWithText(GlassMessage, 'Server error'), findsOne);
      expect(find.widgetWithText(GlassButton, 'Try again'), findsOneWidget);
      await tester.tap(find.widgetWithText(GlassTextButton, 'Sign out'));
      await settle(tester);
      expect(h.auth.status, AuthStatus.unauthenticated);
    });
  });

  testWidgets('Android dialogs and the time picker sit on the glass sheet '
      'surface', (tester) async {
    final h = SessionHarness();
    late BuildContext ctx;
    await pump(
      tester,
      h,
      Scaffold(
        body: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    Color? dialogColor() => tester
        .widget<Material>(
          find
              .descendant(
                of: find.byType(Dialog),
                matching: find.byType(Material),
              )
              .first,
        )
        .color;
    const sheet = Color(0xF7F2F2F7); // the light glass sheet

    unawaited(
      showGlassConfirm(
        ctx,
        title: 'Remove?',
        message: 'Sure?',
        confirmLabel: 'Remove',
      ),
    );
    await tester.pumpAndSettle();
    expect(dialogColor(), sheet);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    unawaited(
      showTimePicker(
        context: ctx,
        initialTime: const TimeOfDay(hour: 21, minute: 0),
      ),
    );
    await tester.pumpAndSettle();
    expect(dialogColor(), sheet);
  });

  group('developer menu', () {
    for (final platform in platforms) {
      final ios = platform == TargetPlatform.iOS;
      testWidgets('${platform.name}: the password is asked in a glass sheet, '
          'the menu is a glass page, and Reset asks first', (tester) async {
        final h = SessionHarness();
        await pump(
          tester,
          h,
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: GlassButton(
                  label: 'Open',
                  onPressed: () => openDevConfig(context),
                ),
              ),
            ),
          ),
          platform: platform,
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('Developer access'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'iitm');
        await tester.tap(find.widgetWithText(GlassButton, 'Enter'));
        // The menu reads its saved overrides from disk before it shows.
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DevConfigView), findsOneWidget);
        expect(find.byType(AppBar), findsNothing);
        expect(find.byType(GlassPage), findsOneWidget);
        expect(find.widgetWithText(GlassButton, 'Save'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Reset overrides'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(DevConfigView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Reset overrides'));
        await tester.pumpAndSettle();
        expect(
          find.byType(ios ? CupertinoActionSheet : AlertDialog),
          findsOneWidget,
        );
        expect(find.text('Reset overrides?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Reset overrides?'), findsNothing);
      });
    }
  });
}
