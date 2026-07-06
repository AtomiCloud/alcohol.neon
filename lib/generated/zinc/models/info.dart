// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'info.g.dart';

@JsonSerializable()
class Info {
  const Info({
    required this.timeStamp,
    this.landscape,
    this.platform,
    this.service,
    this.module,
    this.version,
    this.status,
  });

  factory Info.fromJson(Map<String, Object?> json) => _$InfoFromJson(json);

  final String? landscape;
  final String? platform;
  final String? service;
  final String? module;
  final String? version;
  final String? status;
  final DateTime timeStamp;

  Map<String, Object?> toJson() => _$InfoToJson(this);
}
