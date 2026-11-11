// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'timezone_settled_check_res.g.dart';

@JsonSerializable()
class TimezoneSettledCheckRes {
  const TimezoneSettledCheckRes({this.habitId, this.date, this.status});

  factory TimezoneSettledCheckRes.fromJson(Map<String, Object?> json) =>
      _$TimezoneSettledCheckResFromJson(json);

  final String? habitId;
  final String? date;
  final String? status;

  Map<String, Object?> toJson() => _$TimezoneSettledCheckResToJson(this);
}
