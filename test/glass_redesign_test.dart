import 'dart:convert';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/features/dev/dev_config_view.dart';
import 'package:alcohol_neon/features/profile/profile_view.dart';
import 'package:alcohol_neon/features/settings/settings_view.dart';
import 'package:alcohol_neon/features/settings/timezone_picker.dart';
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
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

const platforms = [TargetPlatform.iOS, TargetPlatform.android];

/// zinc that echoes every `PUT /Configuration` back as the saved principal.
Future<http.Response?> echoConfig(http.Request r) async {
  if (r.method == 'PUT' && r.url.path.contains('/Configuration/')) {
    return jsonResponse({'id': 'cfg1', ...jsonDecode(r.body) as Map});
  }
  if (r.url.path.endsWith('/Charity')) {
    return jsonResponse([
      {'id': 'ch2', 'name': 'Furkids'},
    ]);
  }
  return null;
}

Iterable<http.Request> configPuts(SessionHarness h) => h.requests.where(
  (r) => r.method == 'PUT' && r.url.path.contains('/Configuration/'),
);

Future<void> pumpApp(
  WidgetTester tester,
  Widget home, {
  required TargetPlatform platform,
  SessionHarness? harness,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final app = MaterialApp(
    theme: AppTheme.light.copyWith(platform: platform),
    home: home,
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
  await tester.pumpAndSettle();
}

Future<void> tearDownHarness(WidgetTester tester, SessionHarness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  h.dispose();
}

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

  group('shared glass pieces', () {
    for (final platform in platforms) {
      final ios = platform == TargetPlatform.iOS;

      testWidgets('${platform.name}: a row shrinks while pressed, with no '
          'ripple, and has a chevron only on iOS', (tester) async {
        var taps = 0;
        await pumpApp(
          tester,
          Scaffold(
            body: GlassRow(title: 'Strava', onTap: () => taps++),
          ),
          platform: platform,
        );
        expect(
          find.byIcon(Icons.chevron_right_rounded),
          ios ? findsOneWidget : findsNothing,
        );
        expect(find.byType(InkWell), findsNothing);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Strava')),
        );
        await tester.pump(const Duration(milliseconds: 150));
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          lessThan(1),
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, 1);
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          1,
        );
      });

      testWidgets('${platform.name}: back still works once the title has '
          'folded into the bar', (tester) async {
        await pumpApp(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => GlassPage(
                      title: 'Settings',
                      children: [
                        for (var i = 0; i < 30; i++) GlassRow(title: 'Row $i'),
                      ],
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          platform: platform,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.drag(find.text('Row 3'), const Offset(0, -500));
        await tester.pumpAndSettle();
        await tester.tap(
          ios ? find.bySemanticsLabel('Back') : find.byTooltip('Back'),
        );
        await tester.pumpAndSettle();
        expect(find.byType(GlassPage), findsNothing);
      });

      testWidgets('${platform.name}: a modal opens as a '
          '${ios ? 'page sheet with Cancel' : 'full-screen page with close'}', (
        tester,
      ) async {
        await pumpApp(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showGlassModal<void>(
                  context,
                  (_) => const GlassPage(
                    title: 'New habit',
                    modal: true,
                    children: [Text('form')],
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
          platform: platform,
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('form'), findsOneWidget);
        final route = ModalRoute.of(tester.element(find.text('form')))!;
        if (ios) {
          expect(route, isA<CupertinoSheetRoute<void>>());
          expect(find.byIcon(Icons.close_rounded), findsNothing);
          await tester.tap(find.text('Cancel'));
        } else {
          expect(route, isA<MaterialPageRoute<void>>());
          expect((route as MaterialPageRoute).fullscreenDialog, isTrue);
          expect(find.text('Cancel'), findsNothing);
          await tester.tap(find.byIcon(Icons.close_rounded));
        }
        await tester.pumpAndSettle();
        expect(find.text('form'), findsNothing);
      });
    }
  });

  group('Settings saves each change right away', () {
    testWidgets('Follow phone saves as soon as it is switched, with no Save '
        'button', (tester) async {
      final h = SessionHarness(respond: echoConfig);
      await h.start();
      await pumpApp(
        tester,
        const SettingsView(),
        platform: TargetPlatform.android,
        harness: h,
      );
      expect(find.text('Timezone'), findsWidgets);
      expect(find.text('Follow phone'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);

      // While following the phone, the timezone can't be picked by hand.
      await tester.tap(find.text('Timezone').last);
      await tester.pumpAndSettle();
      expect(find.byType(TimezonePicker), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(h.timezonePreference.followPhone, isFalse);
      expect(h.session.followPhoneTimezone, isFalse);
      await tearDownHarness(tester, h);
    });

    for (final platform in platforms) {
      final ios = platform == TargetPlatform.iOS;
      testWidgets('${platform.name}: a hand-picked timezone asks first with '
          '${ios ? 'an action sheet' : 'a dialog'}, and only Change saves', (
        tester,
      ) async {
        final h = SessionHarness(respond: echoConfig, followPhone: false);
        await h.start();
        await pumpApp(
          tester,
          const SettingsView(),
          platform: platform,
          harness: h,
        );

        Future<void> pickTokyo() async {
          await tester.tap(find.text('Timezone').last);
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'Tokyo');
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('Asia/Tokyo')));
          await tester.pumpAndSettle();
        }

        await pickTokyo();
        expect(find.text('Change timezone to Tokyo?'), findsOneWidget);
        expect(
          find.byType(CupertinoActionSheet),
          ios ? findsOneWidget : findsNothing,
        );
        expect(find.byType(AlertDialog), ios ? findsNothing : findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(configPuts(h), isEmpty);
        expect(find.text('Singapore'), findsOneWidget);

        await pickTokyo();
        await tester.tap(find.text('Change'));
        await tester.pumpAndSettle();
        expect(configPuts(h), hasLength(1));
        expect(jsonDecode(configPuts(h).single.body), {
          'timezone': 'Asia/Tokyo',
          'defaultCharityId': 'ch1',
        });
        expect(find.text('Tokyo'), findsOneWidget);
        expect(find.text('Timezone changed to Tokyo'), findsOneWidget);
        await tearDownHarness(tester, h);
      });
    }

    testWidgets('picking a default charity saves it straight away', (
      tester,
    ) async {
      final h = SessionHarness(respond: echoConfig);
      await h.start();
      await pumpApp(
        tester,
        const SettingsView(),
        platform: TargetPlatform.iOS,
        harness: h,
      );
      await tester.tap(find.text('Red Cross'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Furkids'));
      await tester.pumpAndSettle();
      expect(jsonDecode(configPuts(h).single.body), {
        'timezone': 'Asia/Singapore',
        'defaultCharityId': 'ch2',
      });
      expect(find.text('Furkids'), findsOneWidget);
      await tearDownHarness(tester, h);
    });
  });

  group('Profile', () {
    testWidgets('groups its places with a one-line description each, and has '
        'no test notification', (tester) async {
      final h = SessionHarness();
      await h.start();
      await pumpApp(
        tester,
        const ProfileView(),
        platform: TargetPlatform.android,
        harness: h,
      );
      for (final (group, title, description) in [
        (
          'Checking off',
          'Strava',
          'Habits tick themselves off from your activities',
        ),
        ('Stakes', 'Friends', 'Who hears when you miss'),
        ('Breaks', 'Vacations', 'Pause every habit for a date range'),
        ('Account', 'Settings', 'Timezone, default charity and card'),
      ]) {
        await tester.scrollUntilVisible(find.text(description), 200);
        expect(find.text(group), findsOneWidget);
        expect(find.text(title), findsOneWidget);
        expect(find.text(description), findsOneWidget);
      }
      await tester.scrollUntilVisible(find.text('Sign out'), 200);
      expect(find.text('Send test notification'), findsNothing);
      await tearDownHarness(tester, h);
    });

    testWidgets('seven taps on the name open the developer menu, which has '
        'Send test notification', (tester) async {
      final h = SessionHarness();
      await h.start();
      await pumpApp(
        tester,
        const ProfileView(),
        platform: TargetPlatform.android,
        harness: h,
      );
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.text('User'));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'iitm');
      await tester.tap(find.text('Enter'));
      // The dev menu reads its saved overrides from disk before it shows.
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DevConfigView), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Send test notification'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(DevConfigView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Send test notification'), findsOneWidget);
      await tearDownHarness(tester, h);
    });

    testWidgets('iOS: Delete account confirms with an action sheet', (
      tester,
    ) async {
      final h = SessionHarness();
      await h.start();
      await pumpApp(
        tester,
        const ProfileView(),
        platform: TargetPlatform.iOS,
        harness: h,
      );
      await tester.scrollUntilVisible(find.text('Delete account'), 200);
      await tester.ensureVisible(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoActionSheet), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(h.requests.where((r) => r.method == 'DELETE'), isEmpty);
      await tearDownHarness(tester, h);
    });
  });
}
