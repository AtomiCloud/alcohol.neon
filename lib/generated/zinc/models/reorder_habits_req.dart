// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'reorder_habits_req.g.dart';

@JsonSerializable()
class ReorderHabitsReq {
  const ReorderHabitsReq({this.habitIds});

  factory ReorderHabitsReq.fromJson(Map<String, Object?> json) =>
      _$ReorderHabitsReqFromJson(json);

  final List<String>? habitIds;

  Map<String, Object?> toJson() => _$ReorderHabitsReqToJson(this);
}
