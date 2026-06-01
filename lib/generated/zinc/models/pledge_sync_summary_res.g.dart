// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pledge_sync_summary_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PledgeSyncSummaryRes _$PledgeSyncSummaryResFromJson(
  Map<String, dynamic> json,
) => PledgeSyncSummaryRes(
  causesUpserted: (json['causesUpserted'] as num).toInt(),
  charitiesCreated: (json['charitiesCreated'] as num).toInt(),
  charitiesUpdated: (json['charitiesUpdated'] as num).toInt(),
  externalIdsLinked: (json['externalIdsLinked'] as num).toInt(),
  charitiesProcessed: (json['charitiesProcessed'] as num).toInt(),
);

Map<String, dynamic> _$PledgeSyncSummaryResToJson(
  PledgeSyncSummaryRes instance,
) => <String, dynamic>{
  'causesUpserted': instance.causesUpserted,
  'charitiesCreated': instance.charitiesCreated,
  'charitiesUpdated': instance.charitiesUpdated,
  'externalIdsLinked': instance.externalIdsLinked,
  'charitiesProcessed': instance.charitiesProcessed,
};
