import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/habit_execution_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract `ExecutionRepository` decodes — camelCase keys,
/// required `paymentProcessed` bool, and nullable fields. Decodes via the same
/// path ApiClient uses (jsonDecode → model.fromJson).
void main() {
  test('HabitExecutionRes decodes required + optional fields (camelCase)', () {
    final json =
        jsonDecode('''
      {
        "id": "e1",
        "habitVersionId": "hv1",
        "date": "2026-06-02",
        "status": "completed",
        "completedAt": "2026-06-02T08:30:00Z",
        "notes": "done early",
        "paymentProcessed": true
      }
    ''')
            as Map<String, Object?>;

    final res = HabitExecutionRes.fromJson(json);
    expect(res.id, 'e1');
    expect(res.habitVersionId, 'hv1');
    expect(res.status, 'completed');
    expect(res.paymentProcessed, isTrue);
  });

  test('HabitExecutionRes decodes with nulls; list decodes unwrapped', () {
    final list =
        jsonDecode('''
      [
        { "id": "e1", "habitVersionId": "hv1", "paymentProcessed": false },
        {
          "id": "e2", "habitVersionId": "hv2",
          "status": "skipped", "paymentProcessed": false
        }
      ]
    ''')
            as List<dynamic>;

    final executions = list
        .map((e) => HabitExecutionRes.fromJson(e as Map<String, Object?>))
        .toList();
    expect(executions, hasLength(2));
    expect(executions.first.date, isNull);
    expect(executions.first.paymentProcessed, isFalse);
    expect(executions.last.status, 'skipped');
  });
}
