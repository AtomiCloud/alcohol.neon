// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'timezone_settled_check_res.dart';

part 'update_configuration_res.g.dart';

@JsonSerializable()
class UpdateConfigurationRes {
  const UpdateConfigurationRes({
    this.id,
    this.userId,
    this.timezone,
    this.defaultCharityId,
    this.settledChecks,
  });

  factory UpdateConfigurationRes.fromJson(Map<String, Object?> json) =>
      _$UpdateConfigurationResFromJson(json);

  final String? id;
  final String? userId;
  final String? timezone;
  final String? defaultCharityId;
  final List<TimezoneSettledCheckRes>? settledChecks;

  Map<String, Object?> toJson() => _$UpdateConfigurationResToJson(this);
}
