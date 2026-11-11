// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_configuration_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateConfigurationRes _$UpdateConfigurationResFromJson(
  Map<String, dynamic> json,
) => UpdateConfigurationRes(
  id: json['id'] as String?,
  userId: json['userId'] as String?,
  timezone: json['timezone'] as String?,
  defaultCharityId: json['defaultCharityId'] as String?,
  settledChecks: (json['settledChecks'] as List<dynamic>?)
      ?.map((e) => TimezoneSettledCheckRes.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$UpdateConfigurationResToJson(
  UpdateConfigurationRes instance,
) => <String, dynamic>{
  'id': instance.id,
  'userId': instance.userId,
  'timezone': instance.timezone,
  'defaultCharityId': instance.defaultCharityId,
  'settledChecks': instance.settledChecks,
};
