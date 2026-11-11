// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'strava_connect_url_res.g.dart';

@JsonSerializable()
class StravaConnectUrlRes {
  const StravaConnectUrlRes({this.url, this.appUrl});

  factory StravaConnectUrlRes.fromJson(Map<String, Object?> json) =>
      _$StravaConnectUrlResFromJson(json);

  final String? url;
  final String? appUrl;

  Map<String, Object?> toJson() => _$StravaConnectUrlResToJson(this);
}
