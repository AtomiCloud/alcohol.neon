import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/habit_overview_response.dart';
import 'package:flutter_test/flutter_test.dart';

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
              "week": {
                "monday": "complete",
                "start": "2026-06-01",
                "end": "2026-06-07"
              }
            },
            "timeLeftToEodMinutes": 120,
            "version": { "id": "v1", "version": 2, "isActive": true },
            "totalDebt": "5.00"
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
    expect(habit.charity.name, 'Red Cross');
    expect(habit.status.currentStreak, 4);
    expect(habit.status.isCompleteToday, isFalse);
    expect(habit.status.week.monday, 'complete');
    expect(habit.timeLeftToEodMinutes, 120);
    expect(habit.version.version, 2);
    expect(habit.version.isActive, isTrue);
  });

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
}
