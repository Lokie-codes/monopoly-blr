// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
  id: json['id'] as String,
  senderId: json['senderId'] as String,
  senderName: json['senderName'] as String,
  senderColorHex: json['senderColorHex'] as String,
  message: json['message'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  type:
      $enumDecodeNullable(_$ChatMessageTypeEnumMap, json['type']) ??
      ChatMessageType.text,
);

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'senderName': instance.senderName,
      'senderColorHex': instance.senderColorHex,
      'message': instance.message,
      'timestamp': instance.timestamp.toIso8601String(),
      'type': _$ChatMessageTypeEnumMap[instance.type]!,
    };

const _$ChatMessageTypeEnumMap = {
  ChatMessageType.text: 'text',
  ChatMessageType.system: 'system',
  ChatMessageType.emoji: 'emoji',
  ChatMessageType.action: 'action',
};
