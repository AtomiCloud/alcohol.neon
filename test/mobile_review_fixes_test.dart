import 'dart:async';
import 'dart:convert';

import 'package:alcohol_neon/core/navigation.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_view.dart';
import 'package:alcohol_neon/features/habit/habit_editor_view.dart';
import 'package:alcohol_neon/features/nfc/nfc_deep_links.dart';
import 'package:alcohol_neon/features/root/authed_gate.dart';
import 'package:alcohol_neon/features/settings/timezone_picker.dart';
import 'package:alcohol_neon/features/settings/settings_view.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:alcohol_neon/widgets/glass_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

/// zinc for a user whose configuration has no default charity yet: every
/// `PUT /Configuration` echoes its body back as the saved principal.
Future<http.Response?> noDefaultCharity(http.Request r) async {
  final path = r.url.path;
  if (path.endsWith('/Configuration/me')) {
    return jsonResponse({
      'principal': {
        'id': 'cfg1',
        'timezone': 'Asia/Singapore',
        'defaultCharityId': null,
      },
      'charity': null,
    });
  }
  if (r.method == 'PUT' && path.contains('/Configuration/')) {
    return jsonResponse({'id': 'cfg1', ...jsonDecode(r.body) as Map});
  }
  return null;
}

Map<String, Object?> bodyOf(SessionHarness h, String method, String part) =>
    jsonDecode(
          h.requests
              .singleWhere(
                (r) => r.method == method && r.url.path.contains(part),
              )
              .body,
        )
        as Map<String, Object?>;

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

  testWidgets(
    'first launch with no configuration opens Today to make a habit',
    (tester) async {
      var configured = false;
      final h = SessionHarness(
        respond: (r) async {
          final path = r.url.path;
          if (r.method == 'POST' && path.endsWith('/Configuration')) {
            configured = true;
            return jsonResponse({'id': 'cfg-new', 'timezone': 'UTC'});
          }
          if (path.endsWith('/Configuration/me') && !configured) {
            return jsonResponse({'title': 'Not found', 'status': 404}, 404);
          }
          if (path.endsWith('/overview')) {
            return jsonResponse({...overviewBody(), 'habits': <Object?>[]});
          }
          return null;
        },
      );
      final links = NfcDeepLinkService(links: () => const Stream.empty());
      addTearDown(links.dispose);
      await pumpScreen(tester, h, const AuthedGate(), links: links);
      expect(configured, isTrue);
      expect(find.text('Make your first habit'), findsOneWidget);
      expect(
        find.text(
          'Choose what to do and on which days. Your timezone already '
          'follows your phone.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    },
  );

  testWidgets('a habit with no stake asks for no charity and saves none', (
    tester,
  ) async {
    final h = SessionHarness(respond: noDefaultCharity);
    await h.start();
    await pumpScreen(tester, h, const HabitEditorView());
    expect(find.byIcon(Icons.volunteer_activism), findsNothing);
    expect(
      find.text(
        'Nothing happens yet when you miss a day. Add money, friends or both.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField).first, 'Read a chapter');
    await tester.ensureVisible(find.text('Create habit'));
    await tester.tap(find.text('Create habit'));
    await tester.pumpAndSettle();
    final body = bodyOf(h, 'POST', '/Habit/');
    expect(body['stake'], '0');
    expect(body.containsKey('charityId'), isTrue);
    expect(body['charityId'], isNull);
    expect(
      h.requests.where(
        (r) => r.method == 'PUT' && r.url.path.contains('/Configuration/'),
      ),
      isEmpty,
      reason: 'no charity, so the default stays unset',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  for (final hasDefault in [false, true]) {
    testWidgets(
      hasDefault
          ? 'picking another charity keeps the existing default'
          : 'the first charity picked for a stake becomes the default',
      (tester) async {
        final h = SessionHarness(
          respond: (r) async {
            final path = r.url.path;
            if (path.endsWith('/consent')) {
              return jsonResponse({'hasPaymentConsent': true});
            }
            if (path.contains('/Habit/') && path.endsWith('/h1')) {
              return jsonResponse({
                ...habitVersion,
                'stake': '5',
                'charityId': null,
              });
            }
            if (path.endsWith('/Charity')) {
              return jsonResponse([
                {'id': 'ch2', 'name': 'Furkids'},
              ]);
            }
            return hasDefault ? null : noDefaultCharity(r);
          },
        );
        await h.start();
        await pumpScreen(tester, h, const HabitEditorView(habitId: 'h1'));
        final hint =
            'A charity is only needed because there’s money at stake. Your '
            'first one is remembered for next time.';
        expect(find.text(hint), hasDefault ? findsNothing : findsOneWidget);
        if (hasDefault) {
          // The habit has no charity yet, so the default fills the row.
          expect(find.text('Red Cross'), findsOneWidget);
        } else {
          await tester.scrollUntilVisible(
            find.text('Save changes'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(find.text('Save changes'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save changes'));
          await tester.pumpAndSettle();
          expect(
            find.text('Choose a charity'),
            findsNWidgets(2),
            reason: 'the charity row and the save error',
          );
          expect(h.requests.where((r) => r.method == 'PUT'), isEmpty);
        }

        final charityRow = find.byIcon(Icons.volunteer_activism);
        await tester.scrollUntilVisible(
          charityRow,
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(charityRow);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Furkids'));
        await tester.pumpAndSettle();
        // The row is just the charity's name, with no "Charity" label.
        expect(
          find.descendant(
            of: find.ancestor(of: charityRow, matching: find.byType(GlassRow)),
            matching: find.byType(Text),
          ),
          findsOneWidget,
        );
        expect(find.text('Furkids'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Save changes'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('Save changes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();

        expect(bodyOf(h, 'PUT', '/Habit/')['charityId'], 'ch2');
        final configPuts = h.requests.where(
          (r) => r.method == 'PUT' && r.url.path.contains('/Configuration/'),
        );
        if (hasDefault) {
          expect(configPuts, isEmpty);
          expect(h.session.config?.defaultCharityId, 'ch1');
        } else {
          expect(bodyOf(h, 'PUT', '/Configuration/'), {
            'timezone': 'Asia/Singapore',
            'defaultCharityId': 'ch2',
          });
          expect(h.session.config?.defaultCharityId, 'ch2');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        h.dispose();
      },
    );
  }

  group('proof chosen in New habit is set up after Create', () {
    SessionHarness proofHarness({int bindStatus = 200}) => SessionHarness(
      respond: (r) async {
        final path = r.url.path;
        if (r.method == 'POST' && path.endsWith('/Habit/user-1')) {
          return jsonResponse({...habitVersion, 'habitId': 'h-new'});
        }
        if (path.contains('/Habit/') && path.endsWith('/h-new')) {
          return jsonResponse({...habitVersion, 'habitId': 'h-new'});
        }
        if (path.endsWith('/Proof/plugins')) {
          return jsonResponse([
            {
              'key': 'strava',
              'name': 'Strava',
              'version': 1,
              'alwaysBound': false,
              'settingsSchema': jsonEncode({
                'properties': {
                  'sportTypes': {
                    'items': {
                      'enum': ['Run', 'Ride'],
                    },
                  },
                },
              }),
            },
          ]);
        }
        if (path.endsWith('/Strava/user-1')) {
          return jsonResponse({'connected': true});
        }
        if (r.method == 'PUT' && path.endsWith('/Proof/user-1/h-new')) {
          return bindStatus == 200
              ? jsonResponse({
                  'habitId': 'h-new',
                  'pluginKey': 'strava',
                  'pluginVersion': 1,
                  'settings': jsonDecode(r.body)['settings'],
                })
              : jsonResponse({'title': 'Try later', 'status': 503}, 503);
        }
        return null;
      },
    );

    /// Opens New habit from a launcher, so its pop result can be read.
    Future<List<bool?>> openNewHabit(
      WidgetTester tester,
      SessionHarness h,
    ) async {
      final results = <bool?>[];
      await pumpScreen(
        tester,
        h,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const HabitEditorView()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Evening run');
      return results;
    }

    Future<void> pickRun(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Complete with Strava'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Complete with Strava'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Strava'));
      await tester.pumpAndSettle();
    }

    Future<void> create(WidgetTester tester, {bool settle = true}) async {
      await tester.scrollUntilVisible(
        find.text('Create habit'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Create habit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create habit'));
      if (settle) {
        await tester.pumpAndSettle();
        return;
      }
      // Create's spinner keeps running while the NFC sheet is open.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('Strava binds the new habit with the picked activities', (
      tester,
    ) async {
      final h = proofHarness();
      await h.start();
      final results = await openNewHabit(tester, h);
      await pickRun(tester);
      expect(
        h.requests.where((r) => r.url.path.contains('/Proof/user-1/')),
        isEmpty,
        reason: 'nothing is bound before the habit exists',
      );
      await create(tester);
      expect(bodyOf(h, 'PUT', '/Proof/user-1/h-new'), {
        'pluginKey': 'strava',
        'settings': jsonEncode({
          'sportTypes': ['Run'],
        }),
      });
      expect(results, [true]);
      expect(find.text('New habit'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    });

    testWidgets('a failed Strava bind keeps the habit and reopens it to edit', (
      tester,
    ) async {
      final h = proofHarness(bindStatus: 503);
      await h.start();
      final results = await openNewHabit(tester, h);
      await pickRun(tester);
      await create(tester);
      expect(results, [true], reason: 'Today reloads: the habit exists');
      expect(
        tester.widget<HabitEditorView>(find.byType(HabitEditorView)).isEdit,
        isTrue,
      );
      expect(
        find.text(
          '“Evening run” is created, but Strava isn’t set up. Try again here.',
        ),
        findsOneWidget,
      );
      expect(
        h.requests.where((r) => r.method == 'DELETE'),
        isEmpty,
        reason: 'the create is not undone',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    });

    testWidgets('NFC asks to scan after Create, and Not now skips it', (
      tester,
    ) async {
      final h = proofHarness();
      await h.start();
      final results = await openNewHabit(tester, h);
      await tester.scrollUntilVisible(
        find.text('NFC tag'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('NFC tag'));
      await tester.pumpAndSettle();
      expect(find.text('Scan it after Create'), findsOneWidget);
      await create(tester, settle: false);
      expect(find.text('Link an NFC tag to “Evening run”'), findsOneWidget);
      expect(results, isEmpty, reason: 'still on the editor while it asks');
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(results, [true]);
      expect(find.text('Edit habit'), findsNothing);
      expect(find.textContaining('isn’t set up'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    });
  });

  testWidgets('Settings shows no default charity and saves a timezone alone', (
    tester,
  ) async {
    final h = SessionHarness(respond: noDefaultCharity, followPhone: false);
    await h.start();
    await pumpScreen(tester, h, const SettingsView());
    expect(find.textContaining('None yet'), findsOneWidget);
    await tester.tap(find.text('Timezone').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Tokyo');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('Asia/Tokyo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    expect(bodyOf(h, 'PUT', '/Configuration/'), {
      'timezone': 'Asia/Tokyo',
      'defaultCharityId': null,
    });
    await tester.pumpWidget(const SizedBox.shrink());
    h.dispose();
  });

  testWidgets(
    'Settings fallback keeps saved zone and explains its limited scope',
    (tester) async {
      final h = SessionHarness(respond: noDefaultCharity, followPhone: false);
      await h.start();
      await pumpScreen(tester, h, const SettingsView());
      expect(find.text('Singapore'), findsOneWidget);
      expect(find.text(timezoneDiscoveryNotice), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Singapore'), findsOneWidget);
      await tester.tap(find.text('Timezone').last);
      await tester.pumpAndSettle();
      final picker = tester.widget<TimezonePicker>(find.byType(TimezonePicker));
      expect(picker.timezones.length, greaterThan(400));
      expect(picker.selected, 'Asia/Singapore');
      await tester.enterText(find.byType(TextField), 'Tokyo');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('Asia/Tokyo')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Tokyo'), findsOneWidget);
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
