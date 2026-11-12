// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'inbox_count_res.g.dart';

@JsonSerializable()
class InboxCountRes {
  const InboxCountRes({required this.count});

  factory InboxCountRes.fromJson(Map<String, Object?> json) =>
      _$InboxCountResFromJson(json);

  final int count;

  Map<String, Object?> toJson() => _$InboxCountResToJson(this);
}
