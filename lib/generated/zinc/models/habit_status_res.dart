// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'week_status_res.dart';

part 'habit_status_res.g.dart';

@JsonSerializable()
class HabitStatusRes {
  const HabitStatusRes({
    required this.currentStreak,
    required this.maxStreak,
    required this.isCompleteToday,
    required this.week,
  });
  
  factory HabitStatusRes.fromJson(Map<String, Object?> json) => _$HabitStatusResFromJson(json);
  
  final int currentStreak;
  final int maxStreak;
  final bool isCompleteToday;
  final WeekStatusRes week;

  Map<String, Object?> toJson() => _$HabitStatusResToJson(this);
}
