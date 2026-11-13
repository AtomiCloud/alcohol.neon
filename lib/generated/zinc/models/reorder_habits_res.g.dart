// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reorder_habits_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReorderHabitsRes _$ReorderHabitsResFromJson(Map<String, dynamic> json) =>
    ReorderHabitsRes(
      habitIds: (json['habitIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$ReorderHabitsResToJson(ReorderHabitsRes instance) =>
    <String, dynamic>{'habitIds': instance.habitIds};
