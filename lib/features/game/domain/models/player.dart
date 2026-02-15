import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'player.g.dart';

@JsonSerializable()
class Player extends Equatable {
  final String id;
  final String name;
  final int balance;
  final int position;
  final String colorHex;
  final bool isJailed;
  final int jailTurns; // #9: Track turns spent in jail (max 3)
  final bool hasGetOutOfJailFreeCard; // #7c: Get Out of Jail Free card

  const Player({
    required this.id,
    required this.name,
    this.balance = 1000,
    this.position = 0,
    this.colorHex = "#FF0000",
    this.isJailed = false,
    this.jailTurns = 0,
    this.hasGetOutOfJailFreeCard = false,
  });

  Player copyWith({
    String? name,
    int? balance,
    int? position,
    String? colorHex,
    bool? isJailed,
    int? jailTurns,
    bool? hasGetOutOfJailFreeCard,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      position: position ?? this.position,
      colorHex: colorHex ?? this.colorHex,
      isJailed: isJailed ?? this.isJailed,
      jailTurns: jailTurns ?? this.jailTurns,
      hasGetOutOfJailFreeCard: hasGetOutOfJailFreeCard ?? this.hasGetOutOfJailFreeCard,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerToJson(this);

  @override
  List<Object> get props => [id, name, balance, position, colorHex, isJailed, jailTurns, hasGetOutOfJailFreeCard];
}
