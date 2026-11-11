// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strava_connection_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StravaConnectionRes _$StravaConnectionResFromJson(Map<String, dynamic> json) =>
    StravaConnectionRes(
      connected: json['connected'] as bool,
      connectedAtUtc: json['connectedAtUtc'] == null
          ? null
          : DateTime.parse(json['connectedAtUtc'] as String),
    );

Map<String, dynamic> _$StravaConnectionResToJson(
  StravaConnectionRes instance,
) => <String, dynamic>{
  'connected': instance.connected,
  'connectedAtUtc': instance.connectedAtUtc?.toIso8601String(),
};
