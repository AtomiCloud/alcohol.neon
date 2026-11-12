// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plugin_manifest_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PluginManifestRes _$PluginManifestResFromJson(Map<String, dynamic> json) =>
    PluginManifestRes(
      version: (json['version'] as num).toInt(),
      alwaysBound: json['alwaysBound'] as bool,
      key: json['key'] as String?,
      name: json['name'] as String?,
      platforms: (json['platforms'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      settingsSchema: json['settingsSchema'] as String?,
      minTier: json['minTier'] as String?,
    );

Map<String, dynamic> _$PluginManifestResToJson(PluginManifestRes instance) =>
    <String, dynamic>{
      'key': instance.key,
      'name': instance.name,
      'version': instance.version,
      'platforms': instance.platforms,
      'settingsSchema': instance.settingsSchema,
      'minTier': instance.minTier,
      'alwaysBound': instance.alwaysBound,
    };
