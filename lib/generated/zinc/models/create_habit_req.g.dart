// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_habit_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateHabitReq _$CreateHabitReqFromJson(Map<String, dynamic> json) =>
    CreateHabitReq(
      charityId: json['charityId'] as String,
      task: json['task'] as String?,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      notificationTime: json['notificationTime'] as String?,
      stake: json['stake'] as String?,
      timezone: json['timezone'] as String?,
    );

Map<String, dynamic> _$CreateHabitReqToJson(CreateHabitReq instance) =>
    <String, dynamic>{
      'task': instance.task,
      'daysOfWeek': instance.daysOfWeek,
      'notificationTime': instance.notificationTime,
      'stake': instance.stake,
      'charityId': instance.charityId,
      'timezone': instance.timezone,
    };
