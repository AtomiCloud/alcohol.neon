// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_customer_res.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateCustomerRes _$CreateCustomerResFromJson(Map<String, dynamic> json) =>
    CreateCustomerRes(
      customerId: json['customerId'] as String?,
      clientSecret: json['clientSecret'] as String?,
    );

Map<String, dynamic> _$CreateCustomerResToJson(CreateCustomerRes instance) =>
    <String, dynamic>{
      'customerId': instance.customerId,
      'clientSecret': instance.clientSecret,
    };
