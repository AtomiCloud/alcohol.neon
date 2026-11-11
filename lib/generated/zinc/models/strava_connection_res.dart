// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'strava_connection_res.g.dart';

@JsonSerializable()
class StravaConnectionRes {
  const StravaConnectionRes({required this.connected, this.connectedAtUtc});

  factory StravaConnectionRes.fromJson(Map<String, Object?> json) =>
      _$StravaConnectionResFromJson(json);

  final bool connected;
  final DateTime? connectedAtUtc;

  Map<String, Object?> toJson() => _$StravaConnectionResToJson(this);
}
