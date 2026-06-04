// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_configuration_req.g.dart';

@JsonSerializable()
class UpdateConfigurationReq {
  const UpdateConfigurationReq({
    this.timezone,
    this.defaultCharityId,
  });
  
  factory UpdateConfigurationReq.fromJson(Map<String, Object?> json) => _$UpdateConfigurationReqFromJson(json);
  
  final String? timezone;
  final String? defaultCharityId;

  Map<String, Object?> toJson() => _$UpdateConfigurationReqToJson(this);
}
