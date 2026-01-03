
enum NetworkEventType {
  handshake,
  playerJoined,
  startGame,
  rollDice,
  buyProperty,
  endTurn,
  stateUpdate,
  chatMessage,
  payBail,
}

class NetworkMessage {
  final NetworkEventType type;
  final Map<String, dynamic>? payload;
  final String senderId;

  NetworkMessage({
    required this.type,
    required this.senderId,
    this.payload,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name, // "handshake"
      'senderId': senderId,
      'payload': payload,
    };
  }

  factory NetworkMessage.fromJson(Map<String, dynamic> json) {
    return NetworkMessage(
      type: NetworkEventType.values.firstWhere((e) => e.name == json['type']),
      senderId: json['senderId'] as String,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }
}
