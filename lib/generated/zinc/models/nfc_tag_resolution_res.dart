// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'habit_execution_res.dart';
import 'habit_version_res.dart';
import 'nfc_tag_res.dart';

part 'nfc_tag_resolution_res.g.dart';

@JsonSerializable()
class NfcTagResolutionRes {
  const NfcTagResolutionRes({
    required this.tag,
    required this.habitVersion,
    required this.todayExecution,
    this.today,
  });

  factory NfcTagResolutionRes.fromJson(Map<String, Object?> json) =>
      _$NfcTagResolutionResFromJson(json);

  final NfcTagRes tag;
  final HabitVersionRes habitVersion;
  final String? today;
  final HabitExecutionRes todayExecution;

  Map<String, Object?> toJson() => _$NfcTagResolutionResToJson(this);
}
