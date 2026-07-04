// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'habit_version_meta_res.g.dart';

@JsonSerializable()
class HabitVersionMetaRes {
  const HabitVersionMetaRes({
    required this.version,
    required this.isActive,
    this.id,
  });

  factory HabitVersionMetaRes.fromJson(Map<String, Object?> json) =>
      _$HabitVersionMetaResFromJson(json);

  final String? id;
  final int version;
  final bool isActive;

  Map<String, Object?> toJson() => _$HabitVersionMetaResToJson(this);
}
