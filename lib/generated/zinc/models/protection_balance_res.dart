// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'protection_balance_res.g.dart';

@JsonSerializable()
class ProtectionBalanceRes {
  const ProtectionBalanceRes({
    required this.balance,
    required this.cap,
    this.userId,
  });
  
  factory ProtectionBalanceRes.fromJson(Map<String, Object?> json) => _$ProtectionBalanceResFromJson(json);
  
  final String? userId;
  final int balance;
  final int cap;

  Map<String, Object?> toJson() => _$ProtectionBalanceResToJson(this);
}
