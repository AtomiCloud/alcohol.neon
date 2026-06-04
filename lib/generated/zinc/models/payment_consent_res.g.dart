// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_consent_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentConsentRes _$PaymentConsentResFromJson(Map<String, dynamic> json) =>
    PaymentConsentRes(
      hasPaymentConsent: json['hasPaymentConsent'] as bool,
      consentId: json['consentId'] as String?,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$PaymentConsentResToJson(PaymentConsentRes instance) =>
    <String, dynamic>{
      'hasPaymentConsent': instance.hasPaymentConsent,
      'consentId': instance.consentId,
      'status': instance.status,
    };
