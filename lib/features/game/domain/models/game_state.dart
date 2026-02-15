import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'player.dart';
import 'trade_offer.dart';

part 'game_state.g.dart';

enum GamePhase { lobby, playing, auction, ended }

@JsonSerializable(explicitToJson: true)
class GameState extends Equatable {
  final List<Player> players;
  final String? currentPlayerId;
  final GamePhase phase;
  final List<int> lastDiceRoll;
  final Map<int, String> propertyOwners;
  final Map<int, int> propertyHouses; // #7c: property index -> house count (0-4 houses, 5=hotel)
  final bool hasRolled;
  final String? notificationMessage;
  final List<int> pendingDiceRoll;
  final bool isAnimatingDice;
  final bool canRollAgain;
  // #7d: Auction state
  final int? auctionPropertyIndex;
  final Map<String, int> auctionBids; // playerId -> bid amount
  final String? auctionCurrentBidderId;
  // #7e: Pending trade
  final TradeOffer? pendingTradeOffer;
  // #9: Turn counter for timed win condition
  final int turnCount;
  
  const GameState({
    this.players = const [],
    this.currentPlayerId,
    this.phase = GamePhase.lobby,
    this.lastDiceRoll = const [],
    this.propertyOwners = const {},
    this.propertyHouses = const {},
    this.hasRolled = false,
    this.notificationMessage,
    this.pendingDiceRoll = const [],
    this.isAnimatingDice = false,
    this.canRollAgain = false,
    this.auctionPropertyIndex,
    this.auctionBids = const {},
    this.auctionCurrentBidderId,
    this.pendingTradeOffer,
    this.turnCount = 0,
  });

  GameState copyWith({
    List<Player>? players,
    String? currentPlayerId,
    GamePhase? phase,
    List<int>? lastDiceRoll,
    Map<int, String>? propertyOwners,
    Map<int, int>? propertyHouses,
    bool? hasRolled,
    String? notificationMessage,
    List<int>? pendingDiceRoll,
    bool? isAnimatingDice,
    bool? canRollAgain,
    int? auctionPropertyIndex,
    Map<String, int>? auctionBids,
    String? auctionCurrentBidderId,
    TradeOffer? pendingTradeOffer,
    int? turnCount,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      phase: phase ?? this.phase,
      lastDiceRoll: lastDiceRoll ?? this.lastDiceRoll,
      propertyOwners: propertyOwners ?? this.propertyOwners,
      propertyHouses: propertyHouses ?? this.propertyHouses,
      hasRolled: hasRolled ?? this.hasRolled,
      notificationMessage: notificationMessage ?? this.notificationMessage,
      pendingDiceRoll: pendingDiceRoll ?? this.pendingDiceRoll,
      isAnimatingDice: isAnimatingDice ?? this.isAnimatingDice,
      canRollAgain: canRollAgain ?? this.canRollAgain,
      auctionPropertyIndex: auctionPropertyIndex ?? this.auctionPropertyIndex,
      auctionBids: auctionBids ?? this.auctionBids,
      auctionCurrentBidderId: auctionCurrentBidderId ?? this.auctionCurrentBidderId,
      pendingTradeOffer: pendingTradeOffer ?? this.pendingTradeOffer,
      turnCount: turnCount ?? this.turnCount,
    );
  }

  factory GameState.fromJson(Map<String, dynamic> json) => _$GameStateFromJson(json);
  Map<String, dynamic> toJson() => _$GameStateToJson(this);

  @override
  List<Object?> get props => [players, currentPlayerId, phase, lastDiceRoll, propertyOwners, propertyHouses, hasRolled, notificationMessage, pendingDiceRoll, isAnimatingDice, canRollAgain, auctionPropertyIndex, auctionBids, auctionCurrentBidderId, pendingTradeOffer, turnCount];
}
