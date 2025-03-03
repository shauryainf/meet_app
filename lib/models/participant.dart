import 'package:equatable/equatable.dart';

class Participant extends Equatable {
  final String id;
  final String name;
  final DateTime joinedAt;

  const Participant({
    required this.id,
    required this.name,
    required this.joinedAt,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'],
      name: json['name'],
      joinedAt: DateTime.fromMillisecondsSinceEpoch(json['joinedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'joinedAt': joinedAt.millisecondsSinceEpoch,
    };
  }

  Participant copyWith({
    String? id,
    String? name,
    DateTime? joinedAt,
  }) {
    return Participant(
      id: id ?? this.id,
      name: name ?? this.name,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  List<Object?> get props => [id, name, joinedAt];
}
