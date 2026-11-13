import 'dart:convert';

import 'package:alcohol_neon/core/problem.dart';
import 'package:alcohol_neon/data/habit_repository.dart';
import 'package:alcohol_neon/generated/zinc/models/habit_overview_response.dart';
import 'package:alcohol_neon/networking/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/session_harness.dart';

/// A repository on a fake zinc whose overview pages [habits] like the real
/// one (20 when no Limit is sent). [respond] can override a request.
(HabitRepository, List<http.Request>) pagedRepo(
  List<Map<String, Object?>> habits, {
  http.Response? Function(http.Request)? respond,
}) {
  final requests = <http.Request>[];
  final client = MockClient((r) async {
    requests.add(r);
    return respond?.call(r) ??
        jsonResponse({
          ...pagedOverview(r, habits).bodyJson,
          'usedSkip': 2,
          'totalSkip': 5,
          'totalDebt': '7.00',
        });
  });
  final api = ApiClient(
    baseUrl: Uri.parse('https://zinc.test'),
    tokenProvider: () async => 'token',
    client: client,
  );
  return (HabitRepository(api), requests);
}

extension on http.Response {
  Map<String, Object?> get bodyJson => jsonDecode(body) as Map<String, Object?>;
}

Future<HabitOverviewResponse> okOverview(HabitRepository repo) async =>
    switch (await repo.overview('user-1')) {
      Ok(:final value) => value,
      Err(:final problem) => fail('overview failed: ${problem.title}'),
    };

List<String?> ids(HabitOverviewResponse o) => [for (final h in o.habits!) h.id];

String pageQuery(http.Request r) =>
    'Limit=${r.url.queryParameters['Limit']}&Skip=${r.url.queryParameters['Skip']}';

/// Guards the zinc `HabitOverviewResponse` JSON contract the habit repository
/// depends on — camelCase keys and the nested habit/stake/status/charity
/// shapes. Decodes via the same path ApiClient uses (jsonDecode →
/// model.fromJson).
void main() {
  test('HabitOverviewResponse decodes skip budget + nested habit', () {
    final json =
        jsonDecode('''
      {
        "usedSkip": 1,
        "totalSkip": 3,
        "totalDebt": "12.50",
        "habits": [
          {
            "id": "h1",
            "name": "Morning run",
            "notificationTime": "07:00",
            "timezone": "Asia/Singapore",
            "days": [true, false, true, false, true, false, false],
            "stake": { "amount": 5.0, "currency": "SGD" },
            "enabled": true,
            "charity": { "id": "ch1", "name": "Red Cross", "url": "https://x" },
            "status": {
              "currentStreak": 4,
              "maxStreak": 9,
              "isCompleteToday": false,
              "today": "02-06-2026",
              "todayStatus": "skip",
              "week": {
                "monday": "complete",
                "start": "2026-06-01",
                "end": "2026-06-07"
              }
            },
            "timeLeftToEodMinutes": 120,
            "version": { "id": "v1", "version": 2, "isActive": true },
            "totalDebt": "5.00",
            "sortOrder": 3
          }
        ]
      }
    ''')
            as Map<String, Object?>;

    final res = HabitOverviewResponse.fromJson(json);
    expect(res.usedSkip, 1);
    expect(res.totalSkip, 3);
    expect(res.totalDebt, '12.50');

    final habit = res.habits!.single;
    expect(habit.name, 'Morning run');
    expect(habit.stake.amount, 5.0);
    expect(habit.enabled, isTrue);
    expect(habit.charity?.name, 'Red Cross');
    expect(habit.status.currentStreak, 4);
    expect(habit.status.isCompleteToday, isFalse);
    expect(habit.status.today, '02-06-2026');
    expect(habit.status.todayStatus, 'skip');
    expect(habit.status.week.monday, 'complete');
    expect(habit.timeLeftToEodMinutes, 120);
    expect(habit.version.version, 2);
    expect(habit.version.isActive, isTrue);
    expect(habit.sortOrder, 3);
  });

  test('an overview habit without sortOrder (older zinc) decodes', () {
    final res = HabitOverviewResponse.fromJson({
      'usedSkip': 0,
      'totalSkip': 3,
      'habits': [
        {
          'id': 'h1',
          'enabled': true,
          'stake': {'amount': 0},
          'status': {
            'currentStreak': 0,
            'maxStreak': 0,
            'isCompleteToday': false,
            'week': <String, Object?>{},
          },
          'timeLeftToEodMinutes': 60,
          'version': {'id': 'v1', 'version': 1, 'isActive': true},
        },
      ],
    });
    expect(res.habits!.single.sortOrder, isNull);
  });

  test(
    'reorder PUTs the ids to the order route and reads the saved order',
    () async {
      late http.Request sent;
      final repo = HabitRepository(
        ApiClient(
          baseUrl: Uri.parse('https://zinc.test'),
          tokenProvider: () async => 'token',
          client: MockClient((r) async {
            sent = r;
            return http.Response(
              jsonEncode({
                'habitIds': ['b', 'a', 'c'],
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
      );
      final res = await repo.reorder('user-1', ['b', 'a']);
      expect(sent.method, 'PUT');
      expect(sent.url.path, '/api/v1.0/Habit/user-1/order');
      expect(jsonDecode(sent.body), {
        'habitIds': ['b', 'a'],
      });
      expect(
        switch (res) {
          Ok(:final value) => value.habitIds,
          Err() => null,
        },
        ['b', 'a', 'c'],
      );
    },
  );

  test('HabitOverviewResponse decodes with no habits', () {
    final json =
        jsonDecode('''
      { "usedSkip": 0, "totalSkip": 5 }
    ''')
            as Map<String, Object?>;

    final res = HabitOverviewResponse.fromJson(json);
    expect(res.usedSkip, 0);
    expect(res.totalSkip, 5);
    expect(res.habits, isNull);
    expect(res.totalDebt, isNull);
  });

  group('overview loads every habit, 100 per page', () {
    test('25 habits: all 25, not zinc\'s default 20', () async {
      final (repo, _) = pagedRepo(manyHabits(25));
      final o = await okOverview(repo);
      expect(ids(o), [for (var i = 1; i <= 25; i++) 'h$i']);
    });

    test('3 habits: exactly one request, with Limit=100', () async {
      final (repo, requests) = pagedRepo(manyHabits(3));
      expect(ids(await okOverview(repo)), ['h1', 'h2', 'h3']);
      expect(requests.map(pageQuery), ['Limit=100&Skip=0']);
    });

    test('105 habits: two pages, in order, totals from the first', () async {
      var page = 0;
      final (repo, requests) = pagedRepo(
        manyHabits(105),
        // Later pages carry different totals; only the first page's count.
        respond: (r) => page++ == 0
            ? null
            : jsonResponse({
                ...pagedOverview(r, manyHabits(105)).bodyJson,
                'usedSkip': 9,
                'totalSkip': 9,
                'totalDebt': '99.00',
              }),
      );
      final o = await okOverview(repo);
      expect(requests.map(pageQuery), [
        'Limit=100&Skip=0',
        'Limit=100&Skip=100',
      ]);
      expect(ids(o), [for (var i = 1; i <= 105; i++) 'h$i']);
      expect((o.usedSkip, o.totalSkip, o.totalDebt), (2, 5, '7.00'));
    });

    test('exactly 100 habits: a second, empty page ends it', () async {
      final (repo, requests) = pagedRepo(manyHabits(100));
      expect(await okOverview(repo).then((o) => o.habits!.length), 100);
      expect(requests, hasLength(2));
    });

    test('a failed second page fails the call, not 100 habits', () async {
      final (repo, _) = pagedRepo(
        manyHabits(150),
        respond: (r) => r.url.queryParameters['Skip'] == '100'
            ? jsonResponse({'title': 'Server broke', 'status': 500}, 500)
            : null,
      );
      final res = await repo.overview('user-1');
      expect(res, isA<Err<HabitOverviewResponse>>());
      expect((res as Err).problem.status, 500);
    });

    test('a habit repeated on the second page appears once', () async {
      final habits = manyHabits(101);
      final (repo, _) = pagedRepo(
        habits,
        // zinc before the reorder release has no fixed order across pages.
        respond: (r) => r.url.queryParameters['Skip'] == '100'
            ? jsonResponse({
                ...overviewBody(),
                'habits': [habits[42], habits[100]],
              })
            : null,
      );
      final o = await okOverview(repo);
      expect(ids(o), [for (var i = 1; i <= 101; i++) 'h$i']);
    });

    test('a server that ignores Skip does not loop forever', () async {
      final habits = manyHabits(100);
      final (repo, requests) = pagedRepo(
        habits,
        respond: (r) => jsonResponse({...overviewBody(), 'habits': habits}),
      );
      expect(await okOverview(repo).then((o) => o.habits!.length), 100);
      expect(requests, hasLength(2));
    });
  });
}
