// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'charity_principal_res.dart';
import 'configuration_principal_res.dart';

part 'configuration_res.g.dart';

@JsonSerializable()
class ConfigurationRes {
  const ConfigurationRes({
    required this.principal,
    required this.charity,
  });
  
  factory ConfigurationRes.fromJson(Map<String, Object?> json) => _$ConfigurationResFromJson(json);
  
  final ConfigurationPrincipalRes principal;
  final CharityPrincipalRes charity;

  Map<String, Object?> toJson() => _$ConfigurationResToJson(this);
}
