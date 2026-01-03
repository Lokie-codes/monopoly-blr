// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Player _$PlayerFromJson(Map<String, dynamic> json) => Player(
  id: json['id'] as String,
  name: json['name'] as String,
  balance: (json['balance'] as num?)?.toInt() ?? 1500,
  position: (json['position'] as num?)?.toInt() ?? 0,
  colorHex: json['colorHex'] as String? ?? "#FF0000",
  isJailed: json['isJailed'] as bool? ?? false,
);

Map<String, dynamic> _$PlayerToJson(Player instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'balance': instance.balance,
  'position': instance.position,
  'colorHex': instance.colorHex,
  'isJailed': instance.isJailed,
};
