import 'dart:convert';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/core/navigation.dart';
import 'package:alcohol_neon/features/habit/habit_editor_view.dart';
import 'package:alcohol_neon/features/nfc/nfc_deep_links.dart';
import 'package:alcohol_neon/features/root/authed_gate.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

const platforms = [TargetPlatform.iOS, TargetPlatform.android];

Future<void> pumpApp(
  WidgetTester tester,
  SessionHarness h,
  Widget home, {
  required TargetPlatform platform,
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
        ChangeNotifierProvider<AuthService>.value(value: h.auth),
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
}

/// Today keeps animating its countdown, so step time instead of settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> finish(WidgetTester tester, SessionHarness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  h.dispose();
}

ModalRoute<dynamic> editorRoute(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.byType(HabitEditorView)))!;

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

  for (final platform in platforms) {
    final ios = platform == TargetPlatform.iOS;

    testWidgets('${platform.name}: Today opens New habit as '
        '${ios ? 'a page sheet' : 'a full-screen page'}, and a habit pushed', (
      tester,
    ) async {
      final h = SessionHarness();
      await pumpApp(tester, h, const AuthedGate(), platform: platform);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await settle(tester);
      final create = editorRoute(tester);
      if (ios) {
        expect(create, isA<CupertinoSheetRoute<bool>>());
        await tester.tap(find.text('Cancel'));
      } else {
        expect((create as MaterialPageRoute).fullscreenDialog, isTrue);
        await tester.tap(find.byIcon(Icons.close_rounded));
      }
      await settle(tester);
      expect(find.byType(HabitEditorView), findsNothing);

      await tester.tap(find.text('Read a chapter').first);
      await settle(tester);
      final edit = editorRoute(tester);
      expect(edit, isA<MaterialPageRoute<bool>>());
      expect((edit as MaterialPageRoute).fullscreenDialog, isFalse);
      await finish(tester, h);
    });

    testWidgets('${platform.name}: the reminder opens '
        '${ios ? 'a time wheel' : 'the Material time picker'}', (tester) async {
      final h = SessionHarness();
      await h.start();
      await pumpApp(tester, h, const HabitEditorView(), platform: platform);
      await tester.tap(find.text('Remind me at'));
      await tester.pumpAndSettle();
      expect(
        find.byType(CupertinoDatePicker),
        ios ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(TimePickerDialog),
        ios ? findsNothing : findsOneWidget,
      );
      await finish(tester, h);
    });
  }

  testWidgets('day toggles and Pause save with the habit', (tester) async {
    final h = SessionHarness();
    await h.start();
    await pumpApp(
      tester,
      h,
      const HabitEditorView(habitId: 'h1'),
      platform: TargetPlatform.android,
    );
    expect(find.textContaining('Mon · reminder at'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Wed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mon, Wed · reminder at'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Pause this habit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    final put = h.requests.singleWhere(
      (r) => r.method == 'PUT' && r.url.path.contains('/Habit/'),
    );
    final body = jsonDecode(put.body) as Map<String, Object?>;
    expect(body['daysOfWeek'], ['Monday', 'Wednesday']);
    expect(body['enabled'], isFalse);
    await finish(tester, h);
  });

  testWidgets('iOS: Delete habit asks with an action sheet first', (
    tester,
  ) async {
    final h = SessionHarness();
    await h.start();
    await pumpApp(
      tester,
      h,
      const HabitEditorView(habitId: 'h1'),
      platform: TargetPlatform.iOS,
    );
    await tester.scrollUntilVisible(
      find.text('Delete habit'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete habit'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoActionSheet), findsOneWidget);
    expect(h.requests.where((r) => r.method == 'DELETE'), isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text('Delete habit'),
      ),
    );
    await tester.pumpAndSettle();
    expect(h.requests.where((r) => r.method == 'DELETE'), hasLength(1));
    await finish(tester, h);
  });
}
