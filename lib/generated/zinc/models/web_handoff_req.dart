// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'web_handoff_req.g.dart';

@JsonSerializable()
class WebHandoffReq {
  const WebHandoffReq({this.platform, this.storefront});

  factory WebHandoffReq.fromJson(Map<String, Object?> json) =>
      _$WebHandoffReqFromJson(json);

  final String? platform;
  final String? storefront;

  Map<String, Object?> toJson() => _$WebHandoffReqToJson(this);
}
