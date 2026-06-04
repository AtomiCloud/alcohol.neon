// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_payment_intent_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreatePaymentIntentReq _$CreatePaymentIntentReqFromJson(
  Map<String, dynamic> json,
) => CreatePaymentIntentReq(
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String?,
  description: json['description'] as String?,
);

Map<String, dynamic> _$CreatePaymentIntentReqToJson(
  CreatePaymentIntentReq instance,
) => <String, dynamic>{
  'amount': instance.amount,
  'currency': instance.currency,
  'description': instance.description,
};
