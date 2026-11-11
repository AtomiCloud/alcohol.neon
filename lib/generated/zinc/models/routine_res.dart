// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'routine_res.g.dart';

@JsonSerializable()
class RoutineRes {
  const RoutineRes({required this.id, this.userId, this.name});

  factory RoutineRes.fromJson(Map<String, Object?> json) =>
      _$RoutineResFromJson(json);

  final String id;
  final String? userId;
  final String? name;

  Map<String, Object?> toJson() => _$RoutineResToJson(this);
}
