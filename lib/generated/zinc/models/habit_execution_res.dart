// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'habit_execution_res.g.dart';

@JsonSerializable()
class HabitExecutionRes {
  const HabitExecutionRes({
    required this.id,
    required this.habitVersionId,
    required this.paymentProcessed,
    this.date,
    this.status,
    this.completedAt,
    this.notes,
  });
  
  factory HabitExecutionRes.fromJson(Map<String, Object?> json) => _$HabitExecutionResFromJson(json);
  
  final String id;
  final String habitVersionId;
  final String? date;
  final String? status;
  final String? completedAt;
  final String? notes;
  final bool paymentProcessed;

  Map<String, Object?> toJson() => _$HabitExecutionResToJson(this);
}
