// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'confirm_payment_intent_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfirmPaymentIntentRes _$ConfirmPaymentIntentResFromJson(
  Map<String, dynamic> json,
) => ConfirmPaymentIntentRes(
  amount: (json['amount'] as num).toDouble(),
  paymentIntentId: json['paymentIntentId'] as String?,
  status: json['status'] as String?,
  currency: json['currency'] as String?,
);

Map<String, dynamic> _$ConfirmPaymentIntentResToJson(
  ConfirmPaymentIntentRes instance,
) => <String, dynamic>{
  'paymentIntentId': instance.paymentIntentId,
  'status': instance.status,
  'amount': instance.amount,
  'currency': instance.currency,
};
