// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'habit_charity_ref_res.g.dart';

@JsonSerializable()
class HabitCharityRefRes {
  const HabitCharityRefRes({
    this.id,
    this.name,
    this.url,
  });
  
  factory HabitCharityRefRes.fromJson(Map<String, Object?> json) => _$HabitCharityRefResFromJson(json);
  
  final String? id;
  final String? name;
  final String? url;

  Map<String, Object?> toJson() => _$HabitCharityRefResToJson(this);
}
