// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'trade_offer.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TradeOffer _$TradeOfferFromJson(Map<String, dynamic> json) => TradeOffer(
  fromPlayerId: json['fromPlayerId'] as String,
  toPlayerId: json['toPlayerId'] as String,
  offeredPropertyIndices:
      (json['offeredPropertyIndices'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  requestedPropertyIndices:
      (json['requestedPropertyIndices'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  cashOffer: (json['cashOffer'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$TradeOfferToJson(TradeOffer instance) =>
    <String, dynamic>{
      'fromPlayerId': instance.fromPlayerId,
      'toPlayerId': instance.toPlayerId,
      'offeredPropertyIndices': instance.offeredPropertyIndices,
      'requestedPropertyIndices': instance.requestedPropertyIndices,
      'cashOffer': instance.cashOffer,
    };
