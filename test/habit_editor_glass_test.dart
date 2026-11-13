import 'dart:convert';

import 'package:alcohol_neon/auth/auth_service.dart';
import 'package:alcohol_neon/core/navigation.dart';
import 'package:alcohol_neon/features/habit/habit_editor_view.dart';
import 'package:alcohol_neon/features/nfc/nfc_deep_links.dart';
import 'package:alcohol_neon/features/root/authed_gate.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:alcohol_neon/widgets/glass_list.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
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

  testWidgets('a stake × is its own button for VoiceOver and TalkBack', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = SessionHarness();
    await h.start();
    await pumpApp(
      tester,
      h,
      const HabitEditorView(),
      platform: TargetPlatform.iOS,
    );
    await tester.tap(find.text('Add a stake'));
    await settle(tester);
    await tester.tap(find.text('Money'));
    await settle(tester);
    await tester.tap(find.text('\$1'));
    await settle(tester);
    await tester.tap(find.text('Set stake'));
    await settle(tester);
    expect(find.text('Money'), findsOneWidget);

    final x = tester.getSemantics(find.byIcon(Icons.close_rounded));
    expect(x.label, 'Remove money stake');
    expect(x.flagsCollection.isButton, isTrue);
    // A screen reader's double-tap on the × removes the stake; it must not
    // run the row's action, which opens the amount keypad.
    tester.semantics.tap(find.semantics.byLabel('Remove money stake'));
    await settle(tester);
    expect(find.text('Set your stake'), findsNothing);
    expect(find.text('Money'), findsNothing);

    await finish(tester, h);
    semantics.dispose();
  });

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

  group('New habit: Tell my friends', () {
    /// zinc for a new habit "h9" with friends mei and sam; [stakePuts]
    /// answers each FriendStake PUT in turn (true = 200, false = 500).
    SessionHarness harness(List<bool> stakePuts) {
      var put = 0;
      return SessionHarness(
        respond: (r) async {
          final path = r.url.path;
          if (r.method == 'POST' && path.endsWith('/Habit/user-1')) {
            return jsonResponse({...habitVersion, 'habitId': 'h9'});
          }
          if (path.endsWith('/Friend/user-1')) {
            return jsonResponse([
              {'userId': 'u-mei', 'username': 'mei'},
              {'userId': 'u-sam', 'username': 'sam'},
            ]);
          }
          if (r.method == 'GET' && path.endsWith('/Habit/user-1/h9')) {
            return jsonResponse({...habitVersion, 'habitId': 'h9'});
          }
          if (r.method == 'GET' && path.endsWith('/FriendStake/user-1/h9')) {
            return jsonResponse({'habitId': 'h9', 'friends': []});
          }
          if (r.method == 'PUT' && path.contains('/FriendStake/')) {
            final ok = put < stakePuts.length && stakePuts[put];
            put++;
            return ok
                ? jsonResponse({'habitId': 'h9', 'friends': []})
                : jsonResponse({'title': 'Server error', 'status': 500}, 500);
          }
          return null;
        },
      );
    }

    /// Opens Add a stake and picks [kind] from the type list.
    Future<void> addStake(WidgetTester tester, String kind) async {
      await tester.scrollUntilVisible(
        find.text('Add a stake'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Add a stake'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kind));
      await tester.pumpAndSettle();
    }

    Iterable<http.Request> calls(SessionHarness h, String method, String p) =>
        h.requests.where((r) => r.method == method && r.url.path.endsWith(p));

    /// Opens New habit from a page, names it, picks mei, and taps Create.
    Future<void> createWithMei(
      WidgetTester tester,
      SessionHarness h,
      TargetPlatform platform,
    ) async {
      await h.start();
      await pumpApp(
        tester,
        h,
        Builder(
          builder: (context) => Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => const HabitEditorView(),
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
      await tester.enterText(find.byType(TextField).first, 'Evening walk');
      await addStake(tester, 'Tell my friends');
      await tester.tap(find.text('mei'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(GlassButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('friends told if you miss'), findsOneWidget);
      await tester.tap(find.text('Create habit'));
      await settle(tester);
    }

    for (final platform in platforms) {
      testWidgets('${platform.name}: Create saves the picked friends on the '
          'new habit', (tester) async {
        final h = harness([true]);
        await createWithMei(tester, h, platform);

        expect(calls(h, 'POST', '/Habit/user-1'), hasLength(1));
        final put = calls(h, 'PUT', '/FriendStake/user-1/h9').single;
        expect(jsonDecode(put.body), {
          'friendUserIds': ['u-mei'],
        });
        expect(find.byType(HabitEditorView), findsNothing);
        await finish(tester, h);
      });

      testWidgets('${platform.name}: when friends fail to save, Try again '
          'saves them without creating the habit twice', (tester) async {
        final h = harness([false, true]);
        await createWithMei(tester, h, platform);

        expect(
          find.text('Habit created, but friends weren’t saved'),
          findsOneWidget,
        );
        await tester.tap(find.text('Try again'));
        await settle(tester);

        expect(calls(h, 'PUT', '/FriendStake/user-1/h9'), hasLength(2));
        expect(calls(h, 'POST', '/Habit/user-1'), hasLength(1));
        expect(find.byType(HabitEditorView), findsNothing);
        await finish(tester, h);
      });

      testWidgets('${platform.name}: Not now opens the new habit to retry '
          'friends there', (tester) async {
        final h = harness([false]);
        await createWithMei(tester, h, platform);

        await tester.tap(find.text('Not now'));
        await settle(tester);

        expect(
          find.textContaining('your friends aren’t set up'),
          findsOneWidget,
        );
        expect(find.text('Edit habit'), findsWidgets);
        await tester.scrollUntilVisible(
          find.text('Add a stake'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Add a stake'), findsOneWidget);
        expect(calls(h, 'POST', '/Habit/user-1'), hasLength(1));
        await finish(tester, h);
      });

      testWidgets('${platform.name}: Add a stake lists the stake types first; '
          'only Money opens the amount input', (tester) async {
        final h = harness(const []);
        await h.start();
        await pumpApp(tester, h, const HabitEditorView(), platform: platform);
        await tester.scrollUntilVisible(
          find.text('Add a stake'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Add a stake'));
        await tester.pumpAndSettle();

        expect(find.text('Money'), findsOneWidget);
        expect(find.text('Tell my friends'), findsOneWidget);
        expect(find.text('Set stake'), findsNothing);

        await tester.tap(find.text('Money'));
        await tester.pumpAndSettle();
        expect(find.text('Set stake'), findsOneWidget);
        await finish(tester, h);
      });

      testWidgets('${platform.name}: a new habit saves with money and '
          'friends', (tester) async {
        final base = harness([true]);
        final h = SessionHarness(
          respond: (r) async {
            if (r.url.path.endsWith('/consent')) {
              return jsonResponse({'hasPaymentConsent': true});
            }
            return base.respond!(r);
          },
        );
        await h.start();
        await pumpApp(tester, h, const HabitEditorView(), platform: platform);
        await tester.enterText(find.byType(TextField).first, 'Evening walk');
        await addStake(tester, 'Money');
        await tester.tap(find.text('\$5'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set stake'));
        await tester.pumpAndSettle();
        await addStake(tester, 'Tell my friends');
        await tester.tap(find.text('mei'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(GlassButton, 'Save'));
        await tester.pumpAndSettle();

        expect(find.text('USD 5.00'), findsOneWidget);
        expect(find.text('Add a stake'), findsNothing);
        await tester.tap(find.text('Create habit'));
        await settle(tester);

        final post = calls(h, 'POST', '/Habit/user-1').single;
        final body = jsonDecode(post.body) as Map<String, Object?>;
        expect(double.parse(body['stake']! as String), 5);
        expect(body['charityId'], 'ch1');
        final put = calls(h, 'PUT', '/FriendStake/user-1/h9').single;
        expect(jsonDecode(put.body), {
          'friendUserIds': ['u-mei'],
        });
        await finish(tester, h);
        base.dispose();
      });

      testWidgets('${platform.name}: Edit shows an existing money stake and '
          'friends as their own rows', (tester) async {
        final h = SessionHarness(
          respond: (r) async {
            final path = r.url.path;
            if (path.endsWith('/Habit/user-1/h1')) {
              return jsonResponse({...habitVersion, 'stake': '5'});
            }
            if (path.endsWith('/FriendStake/user-1/h1')) {
              return jsonResponse({
                'habitId': 'h1',
                'friends': [
                  {'userId': 'u-mei', 'username': 'mei'},
                ],
              });
            }
            return null;
          },
        );
        await h.start();
        await pumpApp(
          tester,
          h,
          const HabitEditorView(habitId: 'h1'),
          platform: platform,
        );
        await tester.scrollUntilVisible(
          find.text('Tell my friends'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.widgetWithText(GlassRow, 'Money'), findsOneWidget);
        expect(find.text('USD 5.00'), findsOneWidget);
        expect(
          find.widgetWithText(GlassRow, 'Tell my friends'),
          findsOneWidget,
        );
        expect(find.text('mei'), findsOneWidget);
        // Both types are on the habit, so there's nothing left to add.
        expect(find.text('Add a stake'), findsNothing);
        await finish(tester, h);
      });
    }
  });
}
