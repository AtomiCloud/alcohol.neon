// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_habit_req.g.dart';

@JsonSerializable()
class CreateHabitReq {
  const CreateHabitReq({
    required this.charityId,
    this.task,
    this.daysOfWeek,
    this.notificationTime,
    this.stake,
    this.timezone,
  });

  factory CreateHabitReq.fromJson(Map<String, Object?> json) =>
      _$CreateHabitReqFromJson(json);

  final String? task;
  final List<String>? daysOfWeek;
  final String? notificationTime;
  final String? stake;
  final String charityId;
  final String? timezone;

  Map<String, Object?> toJson() => _$CreateHabitReqToJson(this);
}
