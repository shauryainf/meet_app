import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_2/models/message.dart';

class MeetingService {
  final String _baseUrl;

  MeetingService({String baseUrl = 'http://localhost:3000'})
      : _baseUrl = baseUrl;

  // Create a new meeting
  Future<String> createMeeting() async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/meetings'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data['meetingCode'];
      } else {
        throw Exception('Failed to create meeting');
      }
    } catch (e) {
      throw Exception('Failed to connect to server: $e');
    }
  }

  // Check if a meeting exists
  Future<bool> checkMeetingExists(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/meetings/$code'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return data['exists'];
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Get chat messages for a meeting
  Future<List<ChatMessage>> getMeetingMessages(String code) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/meetings/$code/messages'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success']) {
        return (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
