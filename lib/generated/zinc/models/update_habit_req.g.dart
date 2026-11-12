// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'update_habit_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateHabitReq _$UpdateHabitReqFromJson(Map<String, dynamic> json) =>
    UpdateHabitReq(
      enabled: json['enabled'] as bool,
      task: json['task'] as String?,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      notificationTime: json['notificationTime'] as String?,
      stake: json['stake'] as String?,
      charityId: json['charityId'] as String?,
      timezone: json['timezone'] as String?,
      deadlineTime: json['deadlineTime'] as String?,
    );

Map<String, dynamic> _$UpdateHabitReqToJson(UpdateHabitReq instance) =>
    <String, dynamic>{
      'task': instance.task,
      'daysOfWeek': instance.daysOfWeek,
      'notificationTime': instance.notificationTime,
      'stake': instance.stake,
      'charityId': instance.charityId,
      'enabled': instance.enabled,
      'timezone': instance.timezone,
      'deadlineTime': instance.deadlineTime,
    };
