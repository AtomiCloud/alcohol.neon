// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorInfo _$ErrorInfoFromJson(Map<String, dynamic> json) => ErrorInfo(
  schema: json['schema'],
  id: json['id'] as String?,
  title: json['title'] as String?,
  version: json['version'] as String?,
);

Map<String, dynamic> _$ErrorInfoToJson(ErrorInfo instance) => <String, dynamic>{
  'schema': instance.schema,
  'id': instance.id,
  'title': instance.title,
  'version': instance.version,
};
