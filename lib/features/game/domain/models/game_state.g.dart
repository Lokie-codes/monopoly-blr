// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GameState _$GameStateFromJson(Map<String, dynamic> json) => GameState(
  players:
      (json['players'] as List<dynamic>?)
          ?.map((e) => Player.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  currentPlayerId: json['currentPlayerId'] as String?,
  phase:
      $enumDecodeNullable(_$GamePhaseEnumMap, json['phase']) ?? GamePhase.lobby,
  lastDiceRoll:
      (json['lastDiceRoll'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  propertyOwners:
      (json['propertyOwners'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(int.parse(k), e as String),
      ) ??
      const {},
  hasRolled: json['hasRolled'] as bool? ?? false,
  notificationMessage: json['notificationMessage'] as String?,
  pendingDiceRoll:
      (json['pendingDiceRoll'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  isAnimatingDice: json['isAnimatingDice'] as bool? ?? false,
  canRollAgain: json['canRollAgain'] as bool? ?? false,
);

Map<String, dynamic> _$GameStateToJson(GameState instance) => <String, dynamic>{
  'players': instance.players.map((e) => e.toJson()).toList(),
  'currentPlayerId': instance.currentPlayerId,
  'phase': _$GamePhaseEnumMap[instance.phase]!,
  'lastDiceRoll': instance.lastDiceRoll,
  'propertyOwners': instance.propertyOwners.map(
    (k, e) => MapEntry(k.toString(), e),
  ),
  'hasRolled': instance.hasRolled,
  'notificationMessage': instance.notificationMessage,
  'pendingDiceRoll': instance.pendingDiceRoll,
  'isAnimatingDice': instance.isAnimatingDice,
  'canRollAgain': instance.canRollAgain,
};

const _$GamePhaseEnumMap = {
  GamePhase.lobby: 'lobby',
  GamePhase.playing: 'playing',
  GamePhase.ended: 'ended',
};
