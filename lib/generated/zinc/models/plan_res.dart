// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'plan_res.g.dart';

@JsonSerializable()
class PlanRes {
  const PlanRes({
    required this.priceCents,
    required this.habitsUnlimited,
    required this.skipsMonthly,
    required this.vacationWindowsYearly,
    required this.freezeBase,
    this.key,
    this.currency,
    this.habitsMax,
  });

  factory PlanRes.fromJson(Map<String, Object?> json) =>
      _$PlanResFromJson(json);

  final String? key;
  final int priceCents;
  final String? currency;
  final int? habitsMax;
  final bool habitsUnlimited;
  final int skipsMonthly;
  final int vacationWindowsYearly;
  final int freezeBase;

  Map<String, Object?> toJson() => _$PlanResToJson(this);
}
