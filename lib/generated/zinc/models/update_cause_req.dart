// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'update_cause_req.g.dart';

@JsonSerializable()
class UpdateCauseReq {
  const UpdateCauseReq({this.name});

  factory UpdateCauseReq.fromJson(Map<String, Object?> json) =>
      _$UpdateCauseReqFromJson(json);

  final String? name;

  Map<String, Object?> toJson() => _$UpdateCauseReqToJson(this);
}
