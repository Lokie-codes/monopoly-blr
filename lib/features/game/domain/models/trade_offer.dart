import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'trade_offer.g.dart';

/// #7e: Represents a trade offer between two players
@JsonSerializable()
class TradeOffer extends Equatable {
  final String fromPlayerId;
  final String toPlayerId;
  final List<int> offeredPropertyIndices;   // Properties the initiator offers
  final List<int> requestedPropertyIndices; // Properties the initiator wants
  final int cashOffer;    // Cash the initiator offers (positive = giving, negative = requesting)

  const TradeOffer({
    required this.fromPlayerId,
    required this.toPlayerId,
    this.offeredPropertyIndices = const [],
    this.requestedPropertyIndices = const [],
    this.cashOffer = 0,
  });

  factory TradeOffer.fromJson(Map<String, dynamic> json) => _$TradeOfferFromJson(json);
  Map<String, dynamic> toJson() => _$TradeOfferToJson(this);

  @override
  List<Object> get props => [fromPlayerId, toPlayerId, offeredPropertyIndices, requestedPropertyIndices, cashOffer];
}
