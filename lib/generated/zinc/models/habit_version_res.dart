// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'habit_version_res.g.dart';

@JsonSerializable()
class HabitVersionRes {
  const HabitVersionRes({
    required this.id,
    required this.habitId,
    required this.version,
    required this.charityId,
    this.task,
    this.daysOfWeek,
    this.notificationTime,
    this.stake,
    this.ratio,
    this.timezone,
  });
  
  factory HabitVersionRes.fromJson(Map<String, Object?> json) => _$HabitVersionResFromJson(json);
  
  final String id;
  final String habitId;
  final int version;
  final String? task;
  final List<String>? daysOfWeek;
  final String? notificationTime;
  final String? stake;
  final String? ratio;
  final String charityId;
  final String? timezone;

  Map<String, Object?> toJson() => _$HabitVersionResToJson(this);
}
