// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'mark_daily_failures_req.g.dart';

@JsonSerializable()
class MarkDailyFailuresReq {
  const MarkDailyFailuresReq({this.date, this.habitIds});

  factory MarkDailyFailuresReq.fromJson(Map<String, Object?> json) =>
      _$MarkDailyFailuresReqFromJson(json);

  final String? date;
  final List<String>? habitIds;

  Map<String, Object?> toJson() => _$MarkDailyFailuresReqToJson(this);
}
