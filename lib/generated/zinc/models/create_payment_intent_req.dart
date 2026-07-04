// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_payment_intent_req.g.dart';

@JsonSerializable()
class CreatePaymentIntentReq {
  const CreatePaymentIntentReq({
    required this.amount,
    this.currency,
    this.description,
  });

  factory CreatePaymentIntentReq.fromJson(Map<String, Object?> json) =>
      _$CreatePaymentIntentReqFromJson(json);

  final double amount;
  final String? currency;
  final String? description;

  Map<String, Object?> toJson() => _$CreatePaymentIntentReqToJson(this);
}
