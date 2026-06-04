// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'configuration_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigurationRes _$ConfigurationResFromJson(Map<String, dynamic> json) =>
    ConfigurationRes(
      principal: ConfigurationPrincipalRes.fromJson(
        json['principal'] as Map<String, dynamic>,
      ),
      charity: CharityPrincipalRes.fromJson(
        json['charity'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$ConfigurationResToJson(ConfigurationRes instance) =>
    <String, dynamic>{
      'principal': instance.principal,
      'charity': instance.charity,
    };
