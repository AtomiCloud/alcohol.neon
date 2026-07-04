// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'complete_habit_req.g.dart';

@JsonSerializable()
class CompleteHabitReq {
  const CompleteHabitReq({this.notes});

  factory CompleteHabitReq.fromJson(Map<String, Object?> json) =>
      _$CompleteHabitReqFromJson(json);

  final String? notes;

  Map<String, Object?> toJson() => _$CompleteHabitReqToJson(this);
}
