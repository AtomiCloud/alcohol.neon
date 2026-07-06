// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'habit_overview_habit_res.dart';

part 'habit_overview_response.g.dart';

@JsonSerializable()
class HabitOverviewResponse {
  const HabitOverviewResponse({
    required this.usedSkip,
    required this.totalSkip,
    this.habits,
    this.totalDebt,
  });

  factory HabitOverviewResponse.fromJson(Map<String, Object?> json) =>
      _$HabitOverviewResponseFromJson(json);

  final List<HabitOverviewHabitRes>? habits;
  final String? totalDebt;
  final int usedSkip;
  final int totalSkip;

  Map<String, Object?> toJson() => _$HabitOverviewResponseToJson(this);
}
