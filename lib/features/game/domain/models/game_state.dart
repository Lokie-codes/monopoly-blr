import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'player.dart';

part 'game_state.g.dart';

enum GamePhase { lobby, playing, ended }

@JsonSerializable(explicitToJson: true)
class GameState extends Equatable {
  final List<Player> players;
  final String? currentPlayerId;
  final GamePhase phase;
  final List<int> lastDiceRoll;
  final Map<int, String> propertyOwners;
  final bool hasRolled;
  final String? notificationMessage;
  final List<int> pendingDiceRoll;
  final bool isAnimatingDice;
  final bool canRollAgain;
  
  const GameState({
    this.players = const [],
    this.currentPlayerId,
    this.phase = GamePhase.lobby,
    this.lastDiceRoll = const [],
    this.propertyOwners = const {},
    this.hasRolled = false,
    this.notificationMessage,
    this.pendingDiceRoll = const [],
    this.isAnimatingDice = false,
    this.canRollAgain = false,
  });

  GameState copyWith({
    List<Player>? players,
    String? currentPlayerId,
    GamePhase? phase,
    List<int>? lastDiceRoll,
    Map<int, String>? propertyOwners,
    bool? hasRolled,
    String? notificationMessage,
    List<int>? pendingDiceRoll,
    bool? isAnimatingDice,
    bool? canRollAgain,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      phase: phase ?? this.phase,
      lastDiceRoll: lastDiceRoll ?? this.lastDiceRoll,
      propertyOwners: propertyOwners ?? this.propertyOwners,
      hasRolled: hasRolled ?? this.hasRolled,
      notificationMessage: notificationMessage ?? this.notificationMessage,
      pendingDiceRoll: pendingDiceRoll ?? this.pendingDiceRoll,
      isAnimatingDice: isAnimatingDice ?? this.isAnimatingDice,
      canRollAgain: canRollAgain ?? this.canRollAgain,
    );
  }

  factory GameState.fromJson(Map<String, dynamic> json) => _$GameStateFromJson(json);
  Map<String, dynamic> toJson() => _$GameStateToJson(this);

  @override
  List<Object?> get props => [players, currentPlayerId, phase, lastDiceRoll, propertyOwners, hasRolled, notificationMessage, pendingDiceRoll, isAnimatingDice, canRollAgain];
}
