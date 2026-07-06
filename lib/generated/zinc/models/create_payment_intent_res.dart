// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_payment_intent_res.g.dart';

@JsonSerializable()
class CreatePaymentIntentRes {
  const CreatePaymentIntentRes({
    required this.amount,
    this.paymentIntentId,
    this.status,
    this.currency,
  });

  factory CreatePaymentIntentRes.fromJson(Map<String, Object?> json) =>
      _$CreatePaymentIntentResFromJson(json);

  final String? paymentIntentId;
  final String? status;
  final double amount;
  final String? currency;

  Map<String, Object?> toJson() => _$CreatePaymentIntentResToJson(this);
}
