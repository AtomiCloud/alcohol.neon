import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/configuration_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/configuration_res.dart';
import 'package:alcohol_neon/generated/zinc/models/update_configuration_req.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract for the `/Configuration` endpoints — and in
/// particular the wrap/unwrap asymmetry M5 depends on: `GET /Configuration/me`
/// wraps as `ConfigurationRes{principal,charity}`, but `PUT /Configuration/{id}`
/// returns the *flat* `ConfigurationPrincipalRes` directly (no `principal`
/// envelope). Decodes via the same path ApiClient uses (jsonDecode → fromJson).
void main() {
  test('PUT /Configuration/{id} decodes a FLAT ConfigurationPrincipalRes', () {
    // The PUT response shape: principal fields at the top level, NOT wrapped.
    final json =
        jsonDecode('''
      {
        "id": "c1",
        "userId": "u1",
        "timezone": "Asia/Singapore",
        "defaultCharityId": "ch1"
      }
    ''')
            as Map<String, Object?>;

    final res = ConfigurationPrincipalRes.fromJson(json);
    expect(res.id, 'c1');
    expect(res.userId, 'u1');
    expect(res.timezone, 'Asia/Singapore');
    expect(res.defaultCharityId, 'ch1');
  });

  test('GET /Configuration/me wraps principal + charity (camelCase)', () {
    final json =
        jsonDecode('''
      {
        "principal": {
          "id": "c1", "userId": "u1",
          "timezone": "Asia/Singapore", "defaultCharityId": "ch1"
        },
        "charity": { "id": "ch1", "name": "Red Cross" }
      }
    ''')
            as Map<String, Object?>;

    final res = ConfigurationRes.fromJson(json);
    expect(res.principal.timezone, 'Asia/Singapore');
    expect(res.charity.name, 'Red Cross');
  });

  test('UpdateConfigurationReq serialises both fields (camelCase)', () {
    final req = const UpdateConfigurationReq(
      timezone: 'Asia/Singapore',
      defaultCharityId: 'ch1',
    );
    final json = req.toJson();
    expect(json['timezone'], 'Asia/Singapore');
    expect(json['defaultCharityId'], 'ch1');
  });
}
