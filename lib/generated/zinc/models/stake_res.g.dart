// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stake_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StakeRes _$StakeResFromJson(Map<String, dynamic> json) => StakeRes(
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String?,
);

Map<String, dynamic> _$StakeResToJson(StakeRes instance) => <String, dynamic>{
  'amount': instance.amount,
  'currency': instance.currency,
};
