// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'set_charity_causes_req.g.dart';

@JsonSerializable()
class SetCharityCausesReq {
  const SetCharityCausesReq({this.keys});

  factory SetCharityCausesReq.fromJson(Map<String, Object?> json) =>
      _$SetCharityCausesReqFromJson(json);

  final List<String>? keys;

  Map<String, Object?> toJson() => _$SetCharityCausesReqToJson(this);
}
