// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:json_annotation/json_annotation.dart';

part 'pledge_sync_summary_res.g.dart';

@JsonSerializable()
class PledgeSyncSummaryRes {
  const PledgeSyncSummaryRes({
    required this.causesUpserted,
    required this.charitiesCreated,
    required this.charitiesUpdated,
    required this.externalIdsLinked,
    required this.charitiesProcessed,
  });

  factory PledgeSyncSummaryRes.fromJson(Map<String, Object?> json) =>
      _$PledgeSyncSummaryResFromJson(json);

  final int causesUpserted;
  final int charitiesCreated;
  final int charitiesUpdated;
  final int externalIdsLinked;
  final int charitiesProcessed;

  Map<String, Object?> toJson() => _$PledgeSyncSummaryResToJson(this);
}
