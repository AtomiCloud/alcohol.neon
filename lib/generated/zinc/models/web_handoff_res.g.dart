// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_handoff_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebHandoffRes _$WebHandoffResFromJson(Map<String, dynamic> json) =>
    WebHandoffRes(
      url: json['url'] as String?,
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$WebHandoffResToJson(WebHandoffRes instance) =>
    <String, dynamic>{
      'url': instance.url,
      'expiresInSeconds': instance.expiresInSeconds,
    };
