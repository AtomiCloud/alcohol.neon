import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/cause_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/cause_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract for the `/Causes` endpoints — camelCase keys and
/// the wrap/unwrap quirks (the list returns principals directly; the single-get
/// wraps in `CauseRes{principal}`). Decodes via the same path ApiClient uses
/// (jsonDecode → model.fromJson).
void main() {
  test('Cause list decodes unwrapped principals', () {
    final list =
        jsonDecode('''
      [
        { "id": "c1", "key": "education", "name": "Education" },
        { "id": "c2", "key": "health" }
      ]
    ''')
            as List<dynamic>;

    final causes = list
        .map((e) => CausePrincipalRes.fromJson(e as Map<String, Object?>))
        .toList();
    expect(causes, hasLength(2));
    expect(causes.first.key, 'education');
    expect(causes.first.name, 'Education');
    expect(causes.last.name, isNull);
  });

  test('CauseRes wraps principal', () {
    final json =
        jsonDecode('''
      {
        "principal": { "id": "c1", "key": "education", "name": "Education" }
      }
    ''')
            as Map<String, Object?>;

    final res = CauseRes.fromJson(json);
    expect(res.principal, isA<CausePrincipalRes>());
    expect(res.principal.id, 'c1');
    expect(res.principal.name, 'Education');
  });
}
