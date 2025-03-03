import 'package:equatable/equatable.dart';
import 'package:flutter_application_2/models/participant.dart';
import 'package:flutter_application_2/models/message.dart';

class Meeting extends Equatable {
  final String code;
  final DateTime createdAt;
  final List<Participant> participants;
  final List<ChatMessage> messages;

  const Meeting({
    required this.code,
    required this.createdAt,
    required this.participants,
    required this.messages,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      code: json['code'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      participants: (json['participants'] as List)
          .map((p) => Participant.fromJson(p))
          .toList(),
      messages: (json['messages'] as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'participants': participants.map((p) => p.toJson()).toList(),
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  Meeting copyWith({
    String? code,
    DateTime? createdAt,
    List<Participant>? participants,
    List<ChatMessage>? messages,
  }) {
    return Meeting(
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
    );
  }

  @override
  List<Object?> get props => [code, createdAt, participants, messages];
}
