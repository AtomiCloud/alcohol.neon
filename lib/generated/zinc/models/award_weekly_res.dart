// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'award_weekly_res.g.dart';

@JsonSerializable()
class AwardWeeklyRes {
  const AwardWeeklyRes({required this.awards, this.userId});

  factory AwardWeeklyRes.fromJson(Map<String, Object?> json) =>
      _$AwardWeeklyResFromJson(json);

  final String? userId;
  final int awards;

  Map<String, Object?> toJson() => _$AwardWeeklyResToJson(this);
}
