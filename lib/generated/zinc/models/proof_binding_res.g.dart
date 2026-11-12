// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'proof_binding_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProofBindingRes _$ProofBindingResFromJson(Map<String, dynamic> json) =>
    ProofBindingRes(
      habitId: json['habitId'] as String,
      pluginVersion: (json['pluginVersion'] as num).toInt(),
      pluginKey: json['pluginKey'] as String?,
      settings: json['settings'] as String?,
    );

Map<String, dynamic> _$ProofBindingResToJson(ProofBindingRes instance) =>
    <String, dynamic>{
      'habitId': instance.habitId,
      'pluginKey': instance.pluginKey,
      'pluginVersion': instance.pluginVersion,
      'settings': instance.settings,
    };
