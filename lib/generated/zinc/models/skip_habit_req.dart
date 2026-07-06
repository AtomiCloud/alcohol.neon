// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'skip_habit_req.g.dart';

@JsonSerializable()
class SkipHabitReq {
  const SkipHabitReq({this.notes});

  factory SkipHabitReq.fromJson(Map<String, Object?> json) =>
      _$SkipHabitReqFromJson(json);

  final String? notes;

  Map<String, Object?> toJson() => _$SkipHabitReqToJson(this);
}
