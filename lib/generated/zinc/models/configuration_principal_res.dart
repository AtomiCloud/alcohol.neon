// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'configuration_principal_res.g.dart';

@JsonSerializable()
class ConfigurationPrincipalRes {
  const ConfigurationPrincipalRes({
    this.id,
    this.userId,
    this.timezone,
    this.defaultCharityId,
  });
  
  factory ConfigurationPrincipalRes.fromJson(Map<String, Object?> json) => _$ConfigurationPrincipalResFromJson(json);
  
  final String? id;
  final String? userId;
  final String? timezone;
  final String? defaultCharityId;

  Map<String, Object?> toJson() => _$ConfigurationPrincipalResToJson(this);
}
