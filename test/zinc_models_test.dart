import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/charity_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/configuration_res.dart';
import 'package:alcohol_neon/generated/zinc/models/user_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/user_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract we depend on for M1 — camelCase keys and the
/// wrap/unwrap quirks (single-gets wrap in `…Res{principal}`; the charity list
/// returns principals directly). Decodes via the same path ApiClient uses
/// (jsonDecode → model.fromJson).
void main() {
  test('ConfigurationRes decodes principal + charity (camelCase)', () {
    final json = jsonDecode('''
      {
        "principal": {
          "id": "c1", "userId": "u1",
          "timezone": "Asia/Singapore", "defaultCharityId": "ch1"
        },
        "charity": { "id": "ch1", "name": "Red Cross", "countries": ["SG"] }
      }
    ''') as Map<String, Object?>;

    final res = ConfigurationRes.fromJson(json);
    expect(res.principal.timezone, 'Asia/Singapore');
    expect(res.principal.defaultCharityId, 'ch1');
    expect(res.charity.name, 'Red Cross');
    expect(res.charity.countries, contains('SG'));
  });

  test('Charity list decodes unwrapped principals', () {
    final list = jsonDecode('''
      [
        { "id": "ch1", "name": "A", "countries": ["SG", "MY"], "logoUrl": "x" },
        { "id": "ch2", "name": "B" }
      ]
    ''') as List<dynamic>;

    final charities = list
        .map((e) => CharityPrincipalRes.fromJson(e as Map<String, Object?>))
        .toList();
    expect(charities, hasLength(2));
    expect(charities.first.name, 'A');
    expect(charities.first.countries, ['SG', 'MY']);
    expect(charities.last.logoUrl, isNull);
  });

  test('UserRes wraps principal; required bools decode', () {
    final json = jsonDecode('''
      {
        "principal": {
          "id": "u1", "username": "bob", "email": "b@x.io",
          "emailVerified": true, "active": true
        }
      }
    ''') as Map<String, Object?>;

    final res = UserRes.fromJson(json);
    expect(res.principal, isA<UserPrincipalRes>());
    expect(res.principal.username, 'bob');
    expect(res.principal.emailVerified, isTrue);
    expect(res.principal.active, isTrue);
  });
}
