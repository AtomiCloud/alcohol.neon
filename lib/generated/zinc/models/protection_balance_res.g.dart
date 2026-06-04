// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protection_balance_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProtectionBalanceRes _$ProtectionBalanceResFromJson(
  Map<String, dynamic> json,
) => ProtectionBalanceRes(
  balance: (json['balance'] as num).toInt(),
  cap: (json['cap'] as num).toInt(),
  userId: json['userId'] as String?,
);

Map<String, dynamic> _$ProtectionBalanceResToJson(
  ProtectionBalanceRes instance,
) => <String, dynamic>{
  'userId': instance.userId,
  'balance': instance.balance,
  'cap': instance.cap,
};
