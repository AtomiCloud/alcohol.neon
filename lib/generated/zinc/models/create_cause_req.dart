// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'create_cause_req.g.dart';

@JsonSerializable()
class CreateCauseReq {
  const CreateCauseReq({
    this.key,
    this.name,
  });
  
  factory CreateCauseReq.fromJson(Map<String, Object?> json) => _$CreateCauseReqFromJson(json);
  
  final String? key;
  final String? name;

  Map<String, Object?> toJson() => _$CreateCauseReqToJson(this);
}
