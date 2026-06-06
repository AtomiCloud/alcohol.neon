import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/protection_balance_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract for the protection balance — camelCase keys,
/// optional `userId`, required int `balance`/`cap`. Decodes via the same path
/// ApiClient uses (jsonDecode → model.fromJson).
void main() {
  test('ProtectionBalanceRes decodes balance + cap (camelCase)', () {
    final json =
        jsonDecode('''
      {
        "userId": "u1",
        "balance": 3,
        "cap": 5
      }
    ''')
            as Map<String, Object?>;

    final res = ProtectionBalanceRes.fromJson(json);
    expect(res.userId, 'u1');
    expect(res.balance, 3);
    expect(res.cap, 5);
  });

  test('ProtectionBalanceRes tolerates absent userId', () {
    final json =
        jsonDecode('''
      { "balance": 0, "cap": 5 }
    ''')
            as Map<String, Object?>;

    final res = ProtectionBalanceRes.fromJson(json);
    expect(res.userId, isNull);
    expect(res.balance, 0);
    expect(res.cap, 5);
  });
}
