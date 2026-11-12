// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'proof_binding_res.g.dart';

@JsonSerializable()
class ProofBindingRes {
  const ProofBindingRes({
    required this.habitId,
    required this.pluginVersion,
    this.pluginKey,
    this.settings,
  });

  factory ProofBindingRes.fromJson(Map<String, Object?> json) =>
      _$ProofBindingResFromJson(json);

  final String habitId;
  final String? pluginKey;
  final int pluginVersion;
  final String? settings;

  Map<String, Object?> toJson() => _$ProofBindingResToJson(this);
}
