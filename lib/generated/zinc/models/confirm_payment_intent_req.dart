// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'confirm_payment_intent_req.g.dart';

@JsonSerializable()
class ConfirmPaymentIntentReq {
  const ConfirmPaymentIntentReq({this.paymentConsentId});

  factory ConfirmPaymentIntentReq.fromJson(Map<String, Object?> json) =>
      _$ConfirmPaymentIntentReqFromJson(json);

  final String? paymentConsentId;

  Map<String, Object?> toJson() => _$ConfirmPaymentIntentReqToJson(this);
}
