// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlanRes _$PlanResFromJson(Map<String, dynamic> json) => PlanRes(
  priceCents: (json['priceCents'] as num).toInt(),
  habitsUnlimited: json['habitsUnlimited'] as bool,
  skipsMonthly: (json['skipsMonthly'] as num).toInt(),
  vacationWindowsYearly: (json['vacationWindowsYearly'] as num).toInt(),
  freezeBase: (json['freezeBase'] as num).toInt(),
  key: json['key'] as String?,
  currency: json['currency'] as String?,
  habitsMax: (json['habitsMax'] as num?)?.toInt(),
);

Map<String, dynamic> _$PlanResToJson(PlanRes instance) => <String, dynamic>{
  'key': instance.key,
  'priceCents': instance.priceCents,
  'currency': instance.currency,
  'habitsMax': instance.habitsMax,
  'habitsUnlimited': instance.habitsUnlimited,
  'skipsMonthly': instance.skipsMonthly,
  'vacationWindowsYearly': instance.vacationWindowsYearly,
  'freezeBase': instance.freezeBase,
};
