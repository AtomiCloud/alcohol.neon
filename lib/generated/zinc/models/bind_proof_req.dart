// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'bind_proof_req.g.dart';

@JsonSerializable()
class BindProofReq {
  const BindProofReq({this.pluginKey, this.settings});

  factory BindProofReq.fromJson(Map<String, Object?> json) =>
      _$BindProofReqFromJson(json);

  final String? pluginKey;
  final String? settings;

  Map<String, Object?> toJson() => _$BindProofReqToJson(this);
}
