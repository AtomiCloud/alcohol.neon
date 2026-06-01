// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_configuration_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateConfigurationReq _$UpdateConfigurationReqFromJson(
  Map<String, dynamic> json,
) => UpdateConfigurationReq(
  timezone: json['timezone'] as String?,
  defaultCharityId: json['defaultCharityId'] as String?,
);

Map<String, dynamic> _$UpdateConfigurationReqToJson(
  UpdateConfigurationReq instance,
) => <String, dynamic>{
  'timezone': instance.timezone,
  'defaultCharityId': instance.defaultCharityId,
};
