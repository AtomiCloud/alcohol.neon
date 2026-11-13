// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'reorder_habits_res.g.dart';

@JsonSerializable()
class ReorderHabitsRes {
  const ReorderHabitsRes({this.habitIds});

  factory ReorderHabitsRes.fromJson(Map<String, Object?> json) =>
      _$ReorderHabitsResFromJson(json);

  final List<String>? habitIds;

  Map<String, Object?> toJson() => _$ReorderHabitsResToJson(this);
}
