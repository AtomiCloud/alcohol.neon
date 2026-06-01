// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_status_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HabitStatusRes _$HabitStatusResFromJson(Map<String, dynamic> json) =>
    HabitStatusRes(
      currentStreak: (json['currentStreak'] as num).toInt(),
      maxStreak: (json['maxStreak'] as num).toInt(),
      isCompleteToday: json['isCompleteToday'] as bool,
      week: WeekStatusRes.fromJson(json['week'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$HabitStatusResToJson(HabitStatusRes instance) =>
    <String, dynamic>{
      'currentStreak': instance.currentStreak,
      'maxStreak': instance.maxStreak,
      'isCompleteToday': instance.isCompleteToday,
      'week': instance.week,
    };
