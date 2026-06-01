// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Info _$InfoFromJson(Map<String, dynamic> json) => Info(
  timeStamp: DateTime.parse(json['timeStamp'] as String),
  landscape: json['landscape'] as String?,
  platform: json['platform'] as String?,
  service: json['service'] as String?,
  module: json['module'] as String?,
  version: json['version'] as String?,
  status: json['status'] as String?,
);

Map<String, dynamic> _$InfoToJson(Info instance) => <String, dynamic>{
  'landscape': instance.landscape,
  'platform': instance.platform,
  'service': instance.service,
  'module': instance.module,
  'version': instance.version,
  'status': instance.status,
  'timeStamp': instance.timeStamp.toIso8601String(),
};
