import 'dart:convert';

import 'package:alcohol_neon/data/nfc_tag_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract `NfcTagRepository` decodes (camelCase keys,
/// nested generated models, nullable todayExecution). Decodes via the same
/// path ApiClient uses (jsonDecode → model.fromJson).
void main() {
  test('NfcTagRes decodes required + optional fields', () {
    final json =
        jsonDecode('''
      {
        "id": "3f9c2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f",
        "userId": "user-1",
        "habitId": "h1",
        "claimedAt": "2026-07-11T09:00:00.000Z"
      }
    ''')
            as Map<String, Object?>;

    final res = NfcTagRes.fromJson(json);
    expect(res.id, '3f9c2b7e-1a2b-4c3d-8e9f-0a1b2c3d4e5f');
    expect(res.userId, 'user-1');
    expect(res.habitId, 'h1');
    expect(res.claimedAt, isNotNull);
  });

  test('NfcTagResolutionRes decodes with todayExecution', () {
    final json =
        jsonDecode('''
      {
        "tag": { "id": "tag-12345678", "userId": "user-1", "habitId": "h1" },
        "habitVersion": {
          "id": "hv1", "habitId": "h1", "version": 2,
          "task": "Eat medicine",
          "daysOfWeek": ["Monday", "Tuesday"],
          "notificationTime": "21:00:00",
          "stake": "5.00", "ratio": "100.0",
          "charityId": "c1", "timezone": "Asia/Singapore"
        },
        "today": "2026-07-11",
        "todayExecution": {
          "id": "e1", "habitVersionId": "hv1", "date": "2026-07-11",
          "status": "succeeded", "paymentProcessed": false
        }
      }
    ''')
            as Map<String, Object?>;

    final res = NfcTagResolutionRes.fromJson(json);
    expect(res.tag.habitId, 'h1');
    expect(res.habitVersion.id, 'hv1');
    expect(res.habitVersion.task, 'Eat medicine');
    expect(res.today, '2026-07-11');
    expect(res.todayExecution?.status, 'succeeded');
  });

  test(
    'NfcTagResolutionRes decodes with null todayExecution (not acted yet)',
    () {
      final json =
          jsonDecode('''
      {
        "tag": { "id": "tag-12345678", "userId": "user-1", "habitId": "h1" },
        "habitVersion": {
          "id": "hv1", "habitId": "h1", "version": 1,
          "charityId": "c1"
        },
        "today": "2026-07-11",
        "todayExecution": null
      }
    ''')
              as Map<String, Object?>;

      final res = NfcTagResolutionRes.fromJson(json);
      expect(res.todayExecution, isNull);
    },
  );
}
