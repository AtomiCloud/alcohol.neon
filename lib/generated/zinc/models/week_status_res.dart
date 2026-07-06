// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'week_status_res.g.dart';

@JsonSerializable()
class WeekStatusRes {
  const WeekStatusRes({
    this.sunday,
    this.monday,
    this.tuesday,
    this.wednesday,
    this.thursday,
    this.friday,
    this.saturday,
    this.start,
    this.end,
  });

  factory WeekStatusRes.fromJson(Map<String, Object?> json) =>
      _$WeekStatusResFromJson(json);

  final String? sunday;
  final String? monday;
  final String? tuesday;
  final String? wednesday;
  final String? thursday;
  final String? friday;
  final String? saturday;
  final String? start;
  final String? end;

  Map<String, Object?> toJson() => _$WeekStatusResToJson(this);
}
