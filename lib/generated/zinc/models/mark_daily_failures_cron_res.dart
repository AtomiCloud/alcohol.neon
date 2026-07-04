// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'mark_daily_failures_cron_res.g.dart';

@JsonSerializable()
class MarkDailyFailuresCronRes {
  const MarkDailyFailuresCronRes({required this.totalMarked});

  factory MarkDailyFailuresCronRes.fromJson(Map<String, Object?> json) =>
      _$MarkDailyFailuresCronResFromJson(json);

  final int totalMarked;

  Map<String, Object?> toJson() => _$MarkDailyFailuresCronResToJson(this);
}
