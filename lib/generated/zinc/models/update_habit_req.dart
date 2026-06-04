// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_habit_req.g.dart';

@JsonSerializable()
class UpdateHabitReq {
  const UpdateHabitReq({
    required this.charityId,
    required this.enabled,
    this.task,
    this.daysOfWeek,
    this.notificationTime,
    this.stake,
    this.timezone,
  });
  
  factory UpdateHabitReq.fromJson(Map<String, Object?> json) => _$UpdateHabitReqFromJson(json);
  
  final String? task;
  final List<String>? daysOfWeek;
  final String? notificationTime;
  final String? stake;
  final String charityId;
  final bool enabled;
  final String? timezone;

  Map<String, Object?> toJson() => _$UpdateHabitReqToJson(this);
}
