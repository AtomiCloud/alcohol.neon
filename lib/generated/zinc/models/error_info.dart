// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'error_info.g.dart';

@JsonSerializable()
class ErrorInfo {
  const ErrorInfo({this.schema, this.id, this.title, this.version});

  factory ErrorInfo.fromJson(Map<String, Object?> json) =>
      _$ErrorInfoFromJson(json);

  final dynamic schema;
  final String? id;
  final String? title;
  final String? version;

  Map<String, Object?> toJson() => _$ErrorInfoToJson(this);
}
