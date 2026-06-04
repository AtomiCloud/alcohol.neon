// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_version_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HabitVersionRes _$HabitVersionResFromJson(Map<String, dynamic> json) =>
    HabitVersionRes(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      version: (json['version'] as num).toInt(),
      charityId: json['charityId'] as String,
      task: json['task'] as String?,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      notificationTime: json['notificationTime'] as String?,
      stake: json['stake'] as String?,
      ratio: json['ratio'] as String?,
      timezone: json['timezone'] as String?,
    );

Map<String, dynamic> _$HabitVersionResToJson(HabitVersionRes instance) =>
    <String, dynamic>{
      'id': instance.id,
      'habitId': instance.habitId,
      'version': instance.version,
      'task': instance.task,
      'daysOfWeek': instance.daysOfWeek,
      'notificationTime': instance.notificationTime,
      'stake': instance.stake,
      'ratio': instance.ratio,
      'charityId': instance.charityId,
      'timezone': instance.timezone,
    };
