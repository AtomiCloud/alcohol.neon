// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'configuration_principal_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigurationPrincipalRes _$ConfigurationPrincipalResFromJson(
  Map<String, dynamic> json,
) => ConfigurationPrincipalRes(
  id: json['id'] as String?,
  userId: json['userId'] as String?,
  timezone: json['timezone'] as String?,
  defaultCharityId: json['defaultCharityId'] as String?,
);

Map<String, dynamic> _$ConfigurationPrincipalResToJson(
  ConfigurationPrincipalRes instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'timezone': instance.timezone,
  'defaultCharityId': instance.defaultCharityId,
};
