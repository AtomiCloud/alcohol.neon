// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_routine_req.g.dart';

@JsonSerializable()
class CreateRoutineReq {
  const CreateRoutineReq({this.name});

  factory CreateRoutineReq.fromJson(Map<String, Object?> json) =>
      _$CreateRoutineReqFromJson(json);

  final String? name;

  Map<String, Object?> toJson() => _$CreateRoutineReqToJson(this);
}
