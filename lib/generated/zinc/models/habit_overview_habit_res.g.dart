// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'habit_overview_habit_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HabitOverviewHabitRes _$HabitOverviewHabitResFromJson(
  Map<String, dynamic> json,
) => HabitOverviewHabitRes(
  stake: StakeRes.fromJson(json['stake'] as Map<String, dynamic>),
  enabled: json['enabled'] as bool,
  charity: HabitCharityRefRes.fromJson(json['charity'] as Map<String, dynamic>),
  status: HabitStatusRes.fromJson(json['status'] as Map<String, dynamic>),
  timeLeftToEodMinutes: (json['timeLeftToEodMinutes'] as num).toInt(),
  version: HabitVersionMetaRes.fromJson(
    json['version'] as Map<String, dynamic>,
  ),
  id: json['id'] as String?,
  name: json['name'] as String?,
  notificationTime: json['notificationTime'] as String?,
  timezone: json['timezone'] as String?,
  days: (json['days'] as List<dynamic>?)?.map((e) => e as bool).toList(),
  totalDebt: json['totalDebt'] as String?,
);

Map<String, dynamic> _$HabitOverviewHabitResToJson(
  HabitOverviewHabitRes instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'notificationTime': instance.notificationTime,
  'timezone': instance.timezone,
  'days': instance.days,
  'stake': instance.stake,
  'enabled': instance.enabled,
  'charity': instance.charity,
  'status': instance.status,
  'timeLeftToEodMinutes': instance.timeLeftToEodMinutes,
  'version': instance.version,
  'totalDebt': instance.totalDebt,
};
