// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'stake_res.g.dart';

@JsonSerializable()
class StakeRes {
  const StakeRes({required this.amount, this.currency});

  factory StakeRes.fromJson(Map<String, Object?> json) =>
      _$StakeResFromJson(json);

  final double amount;
  final String? currency;

  Map<String, Object?> toJson() => _$StakeResToJson(this);
}
