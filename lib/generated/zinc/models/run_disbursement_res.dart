// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'run_disbursement_res.g.dart';

@JsonSerializable()
class RunDisbursementRes {
  const RunDisbursementRes({required this.completed});

  factory RunDisbursementRes.fromJson(Map<String, Object?> json) =>
      _$RunDisbursementResFromJson(json);

  final int completed;

  Map<String, Object?> toJson() => _$RunDisbursementResToJson(this);
}
