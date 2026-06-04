// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_version_meta_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HabitVersionMetaRes _$HabitVersionMetaResFromJson(Map<String, dynamic> json) =>
    HabitVersionMetaRes(
      version: (json['version'] as num).toInt(),
      isActive: json['isActive'] as bool,
      id: json['id'] as String?,
    );

Map<String, dynamic> _$HabitVersionMetaResToJson(
  HabitVersionMetaRes instance,
) => <String, dynamic>{
  'id': instance.id,
  'version': instance.version,
  'isActive': instance.isActive,
};
