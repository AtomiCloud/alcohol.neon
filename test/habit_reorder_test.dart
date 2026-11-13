import 'dart:async';
import 'dart:convert';

import 'package:alcohol_neon/core/navigation.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_controller.dart';
import 'package:alcohol_neon/features/dashboard/dashboard_view.dart';
import 'package:alcohol_neon/features/dashboard/today_layout.dart';
import 'package:alcohol_neon/features/dashboard/today_plan.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_habit_res.dart';
import 'package:alcohol_neon/services/widget_service.dart';
import 'package:alcohol_neon/session/session_controller.dart';
import 'package:alcohol_neon/theme/app_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'support/session_harness.dart';

const platforms = [TargetPlatform.iOS, TargetPlatform.android];

/// The ticket's example: A, B and C open, X done, Y resting today.
const _names = {
  'A': 'Alpha',
  'X': 'X-ray',
  'B': 'Bravo',
  'Y': 'Yankee',
  'C': 'Charlie',
};

Map<String, Object?> _habit(String id, int? sortOrder, {String? deadlineUtc}) =>
    {
      'id': id,
      'name': _names[id],
      'enabled': true,
      'timezone': 'Asia/Singapore',
      'days': List.filled(7, id != 'Y'),
      'stake': {'amount': 0, 'currency': 'USD'},
      'version': {'id': 'v-$id', 'version': 1, 'isActive': true},
      'timeLeftToEodMinutes': 600,
      'todayDeadlineUtc': ?deadlineUtc,
      'sortOrder': ?sortOrder,
      'status': {
        'currentStreak': 0,
        'maxStreak': 0,
        'isCompleteToday': id == 'X',
        'today': '09-11-2026',
        'todayStatus': id == 'X' ? 'succeeded' : 'not_applicable',
        'week': <String, Object?>{},
      },
    };

/// A fake zinc that keeps one habit order: the overview lists habits in it
/// with their `sortOrder`, and `PUT …/order` replaces it. [failWith] makes the
/// PUT fail; [hold] keeps PUTs waiting until completed.
class _Zinc {
  _Zinc({this.sortOrder = true, this.alphaFirst = false});
  final bool sortOrder;

  /// Alpha's check ends first (Next up), the others share a later deadline.
  final bool alphaFirst;
  var order = ['A', 'X', 'B', 'Y', 'C'];
  int? failWith;
  Completer<void>? hold;
  final puts = <List<String>>[];
  var overviews = 0;

  Map<String, Object?> overview() => {
    'usedSkip': 0,
    'totalSkip': 3,
    'habits': [
      for (final (i, id) in order.indexed)
        _habit(
          id,
          sortOrder ? i : null,
          deadlineUtc: _inHours(alphaFirst && id == 'A' ? 2 : 5),
        ),
    ],
  };

  Future<http.Response?> respond(http.Request r) async {
    if (r.url.path.endsWith('/overview')) {
      overviews++;
      return jsonResponse(overview());
    }
    if (r.method == 'PUT' && r.url.path.endsWith('/order')) {
      final ids = ((jsonDecode(r.body) as Map)['habitIds'] as List)
          .cast<String>();
      puts.add(ids);
      await hold?.future;
      final fail = failWith;
      if (fail != null) {
        return jsonResponse({'title': 'Nope', 'status': fail}, fail);
      }
      order = ids;
      return jsonResponse({'habitIds': ids});
    }
    return null;
  }
}

String _inHours(int h) =>
    DateTime.now().toUtc().add(Duration(hours: h)).toIso8601String();

List<String?> _ids(List<TodayItem> items) => [
  for (final i in items) i.habit.id,
];

void main() {
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;
  const timezoneChannel = MethodChannel('flutter_timezone');
  const widgetChannel = MethodChannel('home_widget');
  late Map<String, Object?> widgetData;

  setUpAll(loadHarnessConfig);
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'LazyTax',
      packageName: 'cloud.atomi.pichu.alcohol.neon.app',
      version: '1',
      buildNumber: '1',
      buildSignature: '',
    );
    widgetData = {};
    messenger.setMockMethodCallHandler(timezoneChannel, (_) async {
      throw PlatformException(code: 'unavailable');
    });
    messenger.setMockMethodCallHandler(widgetChannel, (call) async {
      final args = call.arguments;
      if (call.method == 'saveWidgetData' && args is Map) {
        widgetData[args['id'] as String] = args['data'];
      }
      return true;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(timezoneChannel, null);
    messenger.setMockMethodCallHandler(widgetChannel, null);
    TodayLayoutSetting.instance.value = TodayLayout.nextUp;
  });

  group('widget payload', () {
    HabitOverviewHabitRes habit(
      String id,
      int sortOrder, {
      bool done = false,
    }) => HabitOverviewHabitRes.fromJson({
      ..._habit(id, sortOrder, deadlineUtc: '2099-01-01T12:00:00Z'),
      'name': id,
      'status': {
        'currentStreak': 0,
        'maxStreak': 0,
        'isCompleteToday': done,
        'today': '09-11-2026',
        'todayStatus': done ? 'succeeded' : 'not_applicable',
        'week': <String, Object?>{},
      },
    });

    test('open habits soonest first, ties in the saved order, then done', () {
      final plan = buildTodayPlan(
        [
          habit('Apple', 2),
          habit('Zebra', 0),
          habit('done-late', 4, done: true),
          habit('Mango', 1),
          habit('done-early', 3, done: true),
        ],
        todayStatus: (h) => h.status.todayStatus,
        loadedAt: DateTime(2026, 11, 9),
      );
      final items =
          widgetSchedule(plan, DateTime(2026, 11, 9))['items'] as List;
      expect(
        [for (final i in items) (i as Map)['name']],
        ['Zebra', 'Mango', 'Apple', 'done-early', 'done-late'],
      );
    });
  });

  group('DashboardController.reorder', () {
    Future<(SessionHarness, DashboardController)> ready(_Zinc zinc) async {
      final h = SessionHarness(respond: zinc.respond);
      await h.start();
      final c = DashboardController(h.session);
      await c.load();
      return (h, c);
    }

    test('shows the new order at once and sends the full order', () async {
      final zinc = _Zinc()..hold = Completer();
      final (h, c) = await ready(zinc);
      expect(c.canReorder, isTrue);

      c.reorder(['C', 'A', 'B']);
      expect(_ids(c.plan.todo), ['C', 'A', 'B'], reason: 'before the PUT');
      await pumpEventQueue();
      expect(zinc.puts, [
        ['C', 'X', 'A', 'Y', 'B'],
      ], reason: 'X and Y keep their places');

      zinc.hold!.complete();
      await pumpEventQueue();
      expect(_ids(c.plan.todo), ['C', 'A', 'B'], reason: 'after the reload');
      expect(zinc.overviews, 2);
      h.dispose();
    });

    test('a failed save restores the order and shows the banner', () async {
      final zinc = _Zinc()..failWith = 503;
      final (h, c) = await ready(zinc);
      c.reorder(['C', 'A', 'B']);
      await pumpEventQueue();
      expect(_ids(c.plan.todo), ['A', 'B', 'C']);
      expect(
        c.actionError?.displayMessage,
        "Couldn't save the new order. Try again.",
      );
      expect(zinc.overviews, 1, reason: 'no reload after a 503');
      h.dispose();
    });

    test('a 400 restores the order and reloads', () async {
      final zinc = _Zinc()..failWith = 400;
      final (h, c) = await ready(zinc);
      c.reorder(['C', 'A', 'B']);
      await pumpEventQueue();
      expect(_ids(c.plan.todo), ['A', 'B', 'C']);
      expect(c.actionError, isNotNull);
      expect(zinc.overviews, 2);
      h.dispose();
    });

    test('after a save, the widget gets the new order', () async {
      final zinc = _Zinc();
      final (h, c) = await ready(zinc);
      await pumpEventQueue();
      List<Object?> names() => [
        for (final i
            in (jsonDecode(widgetData['today_schedule'] as String)
                    as Map)['items']
                as List)
          (i as Map)['name'],
      ];
      expect(names(), ['Alpha', 'Bravo', 'Charlie', 'X-ray']);

      c.reorder(['C', 'A', 'B']);
      await pumpEventQueue();
      expect(names(), ['Charlie', 'Alpha', 'Bravo', 'X-ray']);
      h.dispose();
    });

    test(
      'drops during a save send one more PUT, with the latest order',
      () async {
        final zinc = _Zinc()..hold = Completer();
        final (h, c) = await ready(zinc);
        c.reorder(['C', 'A', 'B']);
        await pumpEventQueue();
        c.reorder(['B', 'C', 'A']);
        c.reorder(['A', 'C', 'B']);
        expect(_ids(c.plan.todo), ['A', 'C', 'B']);
        expect(zinc.puts, hasLength(1), reason: 'one PUT at a time');

        zinc.hold!.complete();
        await pumpEventQueue();
        expect(zinc.puts, [
          ['C', 'X', 'A', 'Y', 'B'],
          ['A', 'X', 'C', 'Y', 'B'],
        ]);
        expect(_ids(c.plan.todo), ['A', 'C', 'B']);
        h.dispose();
      },
    );

    test(
      'older zinc (no sortOrder): reorder is off and sends nothing',
      () async {
        final zinc = _Zinc(sortOrder: false);
        final (h, c) = await ready(zinc);
        expect(c.canReorder, isFalse);
        c.reorder(['C', 'A', 'B']);
        await pumpEventQueue();
        expect(_ids(c.plan.todo), ['A', 'B', 'C']);
        expect(zinc.puts, isEmpty);
        h.dispose();
      },
    );
  });

  group('Today drag', () {
    Future<SessionHarness> pumpToday(
      WidgetTester tester,
      _Zinc zinc,
      TargetPlatform platform, {
      TodayLayout layout = TodayLayout.nextUp,
    }) async {
      TodayLayoutSetting.instance.value = layout;
      final h = SessionHarness(respond: zinc.respond);
      await h.start();
      tester.view.physicalSize = const Size(390, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionController>.value(
          value: h.session,
          child: MaterialApp(
            theme: AppTheme.light.copyWith(platform: platform),
            navigatorObservers: [routeObserver],
            home: const DashboardView(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return h;
    }

    /// Long-press [name]'s row, then drag it so its centre lands on [to].
    Future<void> drag(WidgetTester tester, String name, Offset to) async {
      final from = tester.getCenter(find.text(name));
      final g = await tester.startGesture(from);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      final steps = 10;
      for (var i = 0; i < steps; i++) {
        await g.moveBy((to - from) / steps.toDouble());
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await tester.pumpAndSettle();
    }

    double y(WidgetTester tester, String name) =>
        tester.getCenter(find.text(name)).dy;

    Future<void> done(WidgetTester tester, SessionHarness h) async {
      await tester.pumpWidget(const SizedBox.shrink());
      h.dispose();
    }

    for (final platform in platforms) {
      group(platform.name, () {
        testWidgets('Next up: drag the last Later today row to the top', (
          tester,
        ) async {
          final zinc = _Zinc(alphaFirst: true);
          final h = await pumpToday(tester, zinc, platform);
          expect(find.text('Later today'), findsOneWidget);
          expect(y(tester, 'Bravo'), lessThan(y(tester, 'Charlie')));

          await drag(tester, 'Charlie', tester.getTopLeft(find.text('Bravo')));
          expect(y(tester, 'Charlie'), lessThan(y(tester, 'Bravo')));
          expect(zinc.puts, [
            ['A', 'X', 'C', 'Y', 'B'],
          ]);
          // Next up is still the soonest deadline.
          expect(find.text('Next up'), findsOneWidget);
          expect(y(tester, 'Alpha'), lessThan(y(tester, 'Charlie')));
          await done(tester, h);
        });

        testWidgets('Progress: open rows reorder; a drop past done lands '
            'as the last open row', (tester) async {
          final zinc = _Zinc();
          final h = await pumpToday(
            tester,
            zinc,
            platform,
            layout: TodayLayout.progressList,
          );
          await drag(
            tester,
            'Alpha',
            tester.getBottomLeft(find.text('X-ray')) + const Offset(0, 30),
          );
          expect(zinc.puts, [
            ['B', 'X', 'C', 'Y', 'A'],
          ]);
          expect(y(tester, 'Bravo'), lessThan(y(tester, 'Charlie')));
          expect(y(tester, 'Charlie'), lessThan(y(tester, 'Alpha')));
          expect(y(tester, 'Alpha'), lessThan(y(tester, 'X-ray')));
          await done(tester, h);
        });

        testWidgets('a failed save puts the row back and shows the banner', (
          tester,
        ) async {
          final zinc = _Zinc(alphaFirst: true)..failWith = 503;
          final h = await pumpToday(tester, zinc, platform);
          await drag(tester, 'Charlie', tester.getTopLeft(find.text('Bravo')));
          expect(zinc.puts, hasLength(1));
          expect(y(tester, 'Bravo'), lessThan(y(tester, 'Charlie')));
          expect(
            find.text("Couldn't save the new order. Try again."),
            findsOneWidget,
          );
          await done(tester, h);
        });

        testWidgets('older zinc: a long-press drag moves nothing', (
          tester,
        ) async {
          final zinc = _Zinc(sortOrder: false, alphaFirst: true);
          final h = await pumpToday(tester, zinc, platform);
          await drag(tester, 'Charlie', tester.getTopLeft(find.text('Bravo')));
          expect(y(tester, 'Bravo'), lessThan(y(tester, 'Charlie')));
          expect(zinc.puts, isEmpty);
          await done(tester, h);
        });

        testWidgets('VoiceOver and TalkBack can move a row up', (tester) async {
          final semantics = tester.ensureSemantics();
          final zinc = _Zinc(alphaFirst: true);
          final h = await pumpToday(tester, zinc, platform);
          final moveUp = CustomSemanticsAction.getIdentifier(
            const CustomSemanticsAction(label: 'Move up'),
          );
          final node = tester.getSemantics(find.text('Charlie'));
          expect(node.getSemanticsData().customSemanticsActionIds, [moveUp]);
          node.owner!.performAction(
            node.id,
            SemanticsAction.customAction,
            moveUp,
          );
          await tester.pumpAndSettle();
          expect(zinc.puts, [
            ['A', 'X', 'C', 'Y', 'B'],
          ]);
          expect(y(tester, 'Charlie'), lessThan(y(tester, 'Bravo')));
          await done(tester, h);
          semantics.dispose();
        });
      });
    }
  });
}
