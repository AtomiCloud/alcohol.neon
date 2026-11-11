// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'plugin_manifest_res.g.dart';

@JsonSerializable()
class PluginManifestRes {
  const PluginManifestRes({
    required this.version,
    required this.alwaysBound,
    this.key,
    this.name,
    this.platforms,
    this.settingsSchema,
    this.minTier,
  });

  factory PluginManifestRes.fromJson(Map<String, Object?> json) =>
      _$PluginManifestResFromJson(json);

  final String? key;
  final String? name;
  final int version;
  final List<String>? platforms;
  final String? settingsSchema;
  final String? minTier;
  final bool alwaysBound;

  Map<String, Object?> toJson() => _$PluginManifestResToJson(this);
}
