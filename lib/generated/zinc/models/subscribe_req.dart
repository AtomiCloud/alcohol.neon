// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'subscribe_req.g.dart';

@JsonSerializable()
class SubscribeReq {
  const SubscribeReq({this.tier});

  factory SubscribeReq.fromJson(Map<String, Object?> json) =>
      _$SubscribeReqFromJson(json);

  final String? tier;

  Map<String, Object?> toJson() => _$SubscribeReqToJson(this);
}
