// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserRes _$UserResFromJson(Map<String, dynamic> json) => UserRes(
  principal: UserPrincipalRes.fromJson(
    json['principal'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$UserResToJson(UserRes instance) => <String, dynamic>{
  'principal': instance.principal,
};
