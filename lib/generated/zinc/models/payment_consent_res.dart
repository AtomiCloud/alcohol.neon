// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'payment_consent_res.g.dart';

@JsonSerializable()
class PaymentConsentRes {
  const PaymentConsentRes({
    required this.hasPaymentConsent,
    this.consentId,
    this.status,
  });
  
  factory PaymentConsentRes.fromJson(Map<String, Object?> json) => _$PaymentConsentResFromJson(json);
  
  final bool hasPaymentConsent;
  final String? consentId;
  final String? status;

  Map<String, Object?> toJson() => _$PaymentConsentResToJson(this);
}
