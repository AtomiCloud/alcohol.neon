// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'web_handoff_res.g.dart';

@JsonSerializable()
class WebHandoffRes {
  const WebHandoffRes({this.url, this.expiresInSeconds});

  factory WebHandoffRes.fromJson(Map<String, Object?> json) =>
      _$WebHandoffResFromJson(json);

  final String? url;
  final int? expiresInSeconds;

  Map<String, Object?> toJson() => _$WebHandoffResToJson(this);
}
