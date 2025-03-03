import 'package:equatable/equatable.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatMessage extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      senderId: json['senderId'],
      senderName: json['senderName'],
      content: json['content'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'content': content,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  // Convert to flutter_chat_types Message for chat UI
  types.TextMessage toChatUiMessage() {
    return types.TextMessage(
      id: id,
      author: types.User(id: senderId, firstName: senderName),
      text: content,
      createdAt: timestamp.millisecondsSinceEpoch,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? content,
    DateTime? timestamp,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [id, senderId, senderName, content, timestamp];
}
