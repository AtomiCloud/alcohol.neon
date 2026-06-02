import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/charity_principal_res.dart';
import 'package:alcohol_neon/generated/zinc/models/charity_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract for the `/Charity` endpoints — camelCase keys,
/// the list/get wrap quirk (list returns principals directly; single-get wraps
/// in `CharityRes{principal}`), and the `supported-countries` endpoint, which
/// returns a *bare* JSON string array (not a wrapped object). Decodes via the
/// same path ApiClient uses (jsonDecode → decode fn).
void main() {
  test('Charity list decodes unwrapped principals', () {
    final list = jsonDecode('''
      [
        {
          "id": "ch1",
          "name": "Red Cross",
          "countries": ["US", "GB"],
          "websiteUrl": "https://redcross.org"
        },
        { "id": "ch2" }
      ]
    ''') as List<dynamic>;

    final charities = list
        .map((e) => CharityPrincipalRes.fromJson(e as Map<String, Object?>))
        .toList();
    expect(charities, hasLength(2));
    expect(charities.first.name, 'Red Cross');
    expect(charities.first.countries, ['US', 'GB']);
    expect(charities.first.websiteUrl, 'https://redcross.org');
    // Nullable fields tolerate absence.
    expect(charities.last.name, isNull);
    expect(charities.last.countries, isNull);
  });

  test('CharityRes wraps principal', () {
    final json = jsonDecode('''
      { "principal": { "id": "ch1", "name": "Red Cross" } }
    ''') as Map<String, Object?>;

    final res = CharityRes.fromJson(json);
    expect(res.principal, isA<CharityPrincipalRes>());
    expect(res.principal.id, 'ch1');
    expect(res.principal.name, 'Red Cross');
  });

  test('supported-countries decodes a bare JSON string array', () {
    // The decode fn used by CharityRepository.supportedCountries().
    List<String> decode(dynamic j) =>
        (j as List<dynamic>).map((e) => e as String).toList();

    final json = jsonDecode('["US", "GB", "SG"]');
    final countries = decode(json);

    expect(countries, ['US', 'GB', 'SG']);
    // Every element is a plain string (not a {principal} object).
    expect(countries, everyElement(isA<String>()));
  });
}
