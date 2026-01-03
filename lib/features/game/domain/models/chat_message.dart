import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

@JsonSerializable()
class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String senderColorHex;
  final String message;
  final DateTime timestamp;
  final ChatMessageType type;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderColorHex,
    required this.message,
    required this.timestamp,
    this.type = ChatMessageType.text,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  @override
  List<Object?> get props => [id, senderId, senderName, message, timestamp, type];
}

enum ChatMessageType {
  text,      // Regular player message
  system,    // System notification (player joined, etc.)
  emoji,     // Quick emoji reaction
  action,    // Game action notification
}

// Quick emoji reactions for in-game chat
class QuickEmoji {
  static const List<String> emojis = [
    '👍', '😂', '😮', '😢', '😡', '🎉', '💰', '🏠', '🎲', '🔥',
  ];
  
  static const Map<String, String> emojiMeanings = {
    '👍': 'Good move!',
    '😂': 'Haha!',
    '😮': 'Wow!',
    '😢': 'Sad',
    '😡': 'Angry',
    '🎉': 'Celebration!',
    '💰': 'Money!',
    '🏠': 'Property!',
    '🎲': 'Dice!',
    '🔥': 'On fire!',
  };
}
