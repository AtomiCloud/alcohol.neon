// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'vacation_res.g.dart';

@JsonSerializable()
class VacationRes {
  const VacationRes({
    required this.id,
    this.userId,
    this.startDate,
    this.endDate,
    this.timezone,
    this.createdAt,
  });

  factory VacationRes.fromJson(Map<String, Object?> json) =>
      _$VacationResFromJson(json);

  final String id;
  final String? userId;
  final String? startDate;
  final String? endDate;
  final String? timezone;
  final String? createdAt;

  Map<String, Object?> toJson() => _$VacationResToJson(this);
}
