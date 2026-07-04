// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_configuration_req.g.dart';

@JsonSerializable()
class CreateConfigurationReq {
  const CreateConfigurationReq({this.timezone, this.defaultCharityId});

  factory CreateConfigurationReq.fromJson(Map<String, Object?> json) =>
      _$CreateConfigurationReqFromJson(json);

  final String? timezone;
  final String? defaultCharityId;

  Map<String, Object?> toJson() => _$CreateConfigurationReqToJson(this);
}
