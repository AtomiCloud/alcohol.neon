import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/vacation_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract for `VacationRes` — camelCase keys, required
/// `id`, nullable date/timezone fields. Decodes via the same path ApiClient
/// uses (jsonDecode → model.fromJson).
void main() {
  test('VacationRes decodes camelCase fields (dd-MM-yyyy dates)', () {
    // zinc serialises dates as dd-MM-yyyy (Utils.StandardDateFormat), NOT ISO.
    final json = jsonDecode('''
      {
        "id": "v1",
        "userId": "u1",
        "startDate": "01-06-2026",
        "endDate": "10-06-2026",
        "timezone": "Asia/Singapore",
        "createdAt": "2026-05-01T00:00:00Z"
      }
    ''') as Map<String, Object?>;

    final res = VacationRes.fromJson(json);
    expect(res.id, 'v1');
    expect(res.userId, 'u1');
    expect(res.startDate, '01-06-2026');
    expect(res.endDate, '10-06-2026');
    expect(res.timezone, 'Asia/Singapore');
  });

  test('VacationRes list decodes; optionals may be null', () {
    final list = jsonDecode('''
      [
        { "id": "v1", "startDate": "01-06-2026" },
        { "id": "v2" }
      ]
    ''') as List<dynamic>;

    final vacations = list
        .map((e) => VacationRes.fromJson(e as Map<String, Object?>))
        .toList();
    expect(vacations, hasLength(2));
    expect(vacations.first.id, 'v1');
    expect(vacations.first.startDate, '01-06-2026');
    expect(vacations.last.endDate, isNull);
    expect(vacations.last.timezone, isNull);
  });
}
