// The Appearance choice in Profile: System follows the phone, Light and Dark
// override it at once, and the choice is saved on the device.
import 'dart:io';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/features/profile/profile_view.dart';
import 'package:alcohol_neon/features/root/root_view.dart';
import 'package:alcohol_neon/main.dart' show AlcoholNeonApp;
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/appearance_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

Future<SessionHarness> _pumpApp(
  WidgetTester tester, {
  required Brightness phone,
}) async {
  tester.platformDispatcher.platformBrightnessTestValue = phone;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
  final harness = SessionHarness();
  addTearDown(harness.dispose);
  // Loading keeps RootView on the loader, so no session bootstrap runs.
  harness.auth.status = AuthStatus.loading;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: harness.auth),
        ChangeNotifierProvider<SessionController>.value(value: harness.session),
      ],
      child: const AlcoholNeonApp(),
    ),
  );
  await tester.pump();
  return harness;
}

/// Lets MaterialApp's theme cross-fade finish (the loader never settles).
Future<void> _settleTheme(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Brightness _appBrightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(RootView))).brightness;

void main() {
  setUpAll(loadHarnessConfig);
  tearDown(() => AppearanceSetting.instance.value = ThemeMode.system);

  testWidgets('System follows the phone', (tester) async {
    await _pumpApp(tester, phone: Brightness.dark);
    expect(_appBrightness(tester), Brightness.dark);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await _settleTheme(tester);
    expect(_appBrightness(tester), Brightness.light);
  });

  testWidgets('Light makes the app light on a dark phone, Dark the reverse', (
    tester,
  ) async {
    AppearanceSetting.instance.value = ThemeMode.light;
    await _pumpApp(tester, phone: Brightness.dark);
    expect(_appBrightness(tester), Brightness.light);

    AppearanceSetting.instance.value = ThemeMode.dark;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await _settleTheme(tester);
    expect(_appBrightness(tester), Brightness.dark);
  });

  testWidgets('choosing Light in Profile applies at once', (tester) async {
    await _pumpApp(tester, phone: Brightness.dark);
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .push(MaterialPageRoute(builder: (_) => const ProfileView()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final light = find.text('Light');
    await tester.scrollUntilVisible(
      light,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(light);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(AppearanceSetting.instance.value, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byType(ProfileView))).brightness,
      Brightness.light,
    );
  });

  group('persistence', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('appearance'));
    tearDown(() => dir.deleteSync(recursive: true));

    AppearanceSetting launch() => AppearanceSetting(directory: () async => dir);

    test('the choice survives a restart', () async {
      await launch().set(ThemeMode.light);

      final relaunched = launch();
      await relaunched.load();
      expect(relaunched.value, ThemeMode.light);

      await relaunched.set(ThemeMode.dark);
      final again = launch();
      await again.load();
      expect(again.value, ThemeMode.dark);
    });

    test('defaults to System with nothing saved or a corrupt file', () async {
      final fresh = launch();
      await fresh.load();
      expect(fresh.value, ThemeMode.system);

      File('${dir.path}/appearance.json').writeAsStringSync('{not json');
      final corrupt = launch();
      await corrupt.load();
      expect(corrupt.value, ThemeMode.system);
    });
  });
}
