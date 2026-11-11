// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'web_handoff_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebHandoffRes _$WebHandoffResFromJson(Map<String, dynamic> json) =>
    WebHandoffRes(
      expiresInSeconds: (json['expiresInSeconds'] as num).toInt(),
      url: json['url'] as String?,
    );

Map<String, dynamic> _$WebHandoffResToJson(WebHandoffRes instance) =>
    <String, dynamic>{
      'url': instance.url,
      'expiresInSeconds': instance.expiresInSeconds,
    };
