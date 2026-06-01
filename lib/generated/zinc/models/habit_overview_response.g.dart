// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_overview_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HabitOverviewResponse _$HabitOverviewResponseFromJson(
  Map<String, dynamic> json,
) => HabitOverviewResponse(
  usedSkip: (json['usedSkip'] as num).toInt(),
  totalSkip: (json['totalSkip'] as num).toInt(),
  habits: (json['habits'] as List<dynamic>?)
      ?.map((e) => HabitOverviewHabitRes.fromJson(e as Map<String, dynamic>))
      .toList(),
  totalDebt: json['totalDebt'] as String?,
);

Map<String, dynamic> _$HabitOverviewResponseToJson(
  HabitOverviewResponse instance,
) => <String, dynamic>{
  'habits': instance.habits,
  'totalDebt': instance.totalDebt,
  'usedSkip': instance.usedSkip,
  'totalSkip': instance.totalSkip,
};
