// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_configuration_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateConfigurationReq _$CreateConfigurationReqFromJson(
  Map<String, dynamic> json,
) => CreateConfigurationReq(
  timezone: json['timezone'] as String?,
  defaultCharityId: json['defaultCharityId'] as String?,
);

Map<String, dynamic> _$CreateConfigurationReqToJson(
  CreateConfigurationReq instance,
) => <String, dynamic>{
  'timezone': instance.timezone,
  'defaultCharityId': instance.defaultCharityId,
};
