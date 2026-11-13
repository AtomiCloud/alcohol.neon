// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reorder_habits_req.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReorderHabitsReq _$ReorderHabitsReqFromJson(Map<String, dynamic> json) =>
    ReorderHabitsReq(
      habitIds: (json['habitIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ReorderHabitsReqToJson(ReorderHabitsReq instance) =>
    <String, dynamic>{'habitIds': instance.habitIds};
