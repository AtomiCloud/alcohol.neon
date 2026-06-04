// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_payment_intent_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePaymentIntentRes _$CreatePaymentIntentResFromJson(
  Map<String, dynamic> json,
) => CreatePaymentIntentRes(
  amount: (json['amount'] as num).toDouble(),
  paymentIntentId: json['paymentIntentId'] as String?,
  status: json['status'] as String?,
  currency: json['currency'] as String?,
);

Map<String, dynamic> _$CreatePaymentIntentResToJson(
  CreatePaymentIntentRes instance,
) => <String, dynamic>{
  'paymentIntentId': instance.paymentIntentId,
  'status': instance.status,
  'amount': instance.amount,
  'currency': instance.currency,
};
