// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

import 'habit_charity_ref_res.dart';
import 'habit_status_res.dart';
import 'habit_version_meta_res.dart';
import 'stake_res.dart';

part 'habit_overview_habit_res.g.dart';

@JsonSerializable()
class HabitOverviewHabitRes {
  const HabitOverviewHabitRes({
    required this.stake,
    required this.enabled,
    required this.charity,
    required this.status,
    required this.timeLeftToEodMinutes,
    required this.version,
    this.id,
    this.name,
    this.notificationTime,
    this.timezone,
    this.days,
    this.totalDebt,
  });

  factory HabitOverviewHabitRes.fromJson(Map<String, Object?> json) =>
      _$HabitOverviewHabitResFromJson(json);

  final String? id;
  final String? name;
  final String? notificationTime;
  final String? timezone;
  final List<bool>? days;
  final StakeRes stake;
  final bool enabled;
  final HabitCharityRefRes charity;
  final HabitStatusRes status;
  final int timeLeftToEodMinutes;
  final HabitVersionMetaRes version;
  final String? totalDebt;

  Map<String, Object?> toJson() => _$HabitOverviewHabitResToJson(this);
}
