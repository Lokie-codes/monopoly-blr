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

  const Player({
    required this.id,
    required this.name,
    this.balance = 1000,
    this.position = 0,
    this.colorHex = "#FF0000",
    this.isJailed = false,
  });

  Player copyWith({
    String? name,
    int? balance,
    int? position,
    String? colorHex,
    bool? isJailed,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      position: position ?? this.position,
      colorHex: colorHex ?? this.colorHex,
      isJailed: isJailed ?? this.isJailed,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);
  Map<String, dynamic> toJson() => _$PlayerToJson(this);

  @override
  List<Object> get props => [id, name, balance, position, colorHex, isJailed];
}
