import 'dart:convert';

import 'package:alcohol_neon/generated/zinc/models/payment_consent_res.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the zinc JSON contract for the `/Payment` consent flow — camelCase
/// keys, the required `hasPaymentConsent` bool, and the nullable consent fields.
/// Decodes via the same path ApiClient uses (jsonDecode → model.fromJson).
void main() {
  test('PaymentConsentRes decodes an active consent (camelCase)', () {
    final json =
        jsonDecode('''
      {
        "hasPaymentConsent": true,
        "consentId": "cst_123",
        "status": "VERIFIED"
      }
    ''')
            as Map<String, Object?>;

    final res = PaymentConsentRes.fromJson(json);
    expect(res.hasPaymentConsent, isTrue);
    expect(res.consentId, 'cst_123');
    expect(res.status, 'VERIFIED');
  });

  test('PaymentConsentRes decodes "no consent" with null optionals', () {
    final json =
        jsonDecode('{ "hasPaymentConsent": false }') as Map<String, Object?>;

    final res = PaymentConsentRes.fromJson(json);
    expect(res.hasPaymentConsent, isFalse);
    expect(res.consentId, isNull);
    expect(res.status, isNull);
  });
}
