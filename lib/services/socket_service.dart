import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_application_2/models/participant.dart';

class SocketService {
  // Socket instance
  late IO.Socket _socket;

  // Server URL
  final String _serverUrl;

  // User information
  String? _userId;
  String? _userName;
  String? _meetingCode;

  // Connection retry variables
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;

  // Stream controllers for events
  final StreamController<List<Participant>> _onParticipantsController =
      StreamController<List<Participant>>.broadcast();
  final StreamController<Map<String, dynamic>> _onOfferController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _onAnswerController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _onIceCandidateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _onUserLeftController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _onChatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Event streams
  Stream<List<Participant>> get onParticipants =>
      _onParticipantsController.stream;
  Stream<Map<String, dynamic>> get onOffer => _onOfferController.stream;
  Stream<Map<String, dynamic>> get onAnswer => _onAnswerController.stream;
  Stream<Map<String, dynamic>> get onIceCandidate =>
      _onIceCandidateController.stream;
  Stream<String> get onUserLeft => _onUserLeftController.stream;
  Stream<Map<String, dynamic>> get onChatMessage =>
      _onChatMessageController.stream;

  // Connection status stream
  final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStatus => _connectionStatusController.stream;

  // Constructor
  SocketService({String? serverUrl})
      : _serverUrl = serverUrl ?? _determineServerUrl() {
    _initialize();
  }

  // Determine server URL based on environment
  static String _determineServerUrl() {
    // When running in production (web), determine if we're accessing via a relative URL
    // or use the environment-provided URL
    const serverUrlFromEnv = String.fromEnvironment('BACKEND_URL');

    if (serverUrlFromEnv.isNotEmpty) {
      return serverUrlFromEnv;
    }

    // In web release builds running on the same domain as the backend,
    // use a relative URL to make it work with the Nginx proxy
    if (identical(0, 0.0)) {
      // Simple check for JS platform (web)
      return '/'; // Relative URL, will be handled by Nginx
    }

    // Default for local development
    return 'http://localhost:3000';
  }

  // Initialize socket connection
  void _initialize() {
    _socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(_maxReconnectAttempts)
          .setReconnectionDelay(1000)
          .build(),
    );

    // Set up event listeners
    _socket.onConnect((_) {
      print('Socket connected: ${_socket.id}');
      _userId = _socket.id;
      _connectionStatusController.add(true);
      _reconnectAttempts = 0;

      // If we were in a meeting before disconnection, rejoin
      if (_meetingCode != null && _userName != null) {
        joinMeeting(_meetingCode!, _userName!);
      }
    });

    _socket.onDisconnect((_) {
      print('Socket disconnected');
      _connectionStatusController.add(false);

      // Try to reconnect if not intentional
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
    });

    _socket.onConnectError((error) {
      print('Socket connection error: $error');
      _connectionStatusController.add(false);

      // Try to reconnect if not too many attempts
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
    });

    _socket.onConnectTimeout((_) {
      print('Socket connection timeout');
      _connectionStatusController.add(false);

      // Try to reconnect if not too many attempts
      if (_reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      }
    });

    _socket.onError((error) {
      print('Socket error: $error');
    });

    // Listen for socket events
    _socket.on('user-joined', (data) {
      try {
        final participants = (data['participants'] as List)
            .map((p) => Participant.fromJson(p))
            .toList();
        _onParticipantsController.add(participants);
      } catch (e) {
        print('Error parsing user-joined event: $e');
      }
    });

    _socket.on('meeting-joined', (data) {
      try {
        final participants = (data['participants'] as List)
            .map((p) => Participant.fromJson(p))
            .toList();
        _meetingCode = data['meetingCode'];
        _onParticipantsController.add(participants);
      } catch (e) {
        print('Error parsing meeting-joined event: $e');
      }
    });

    _socket.on('offer', (data) {
      _onOfferController.add(data);
    });

    _socket.on('answer', (data) {
      _onAnswerController.add(data);
    });

    _socket.on('ice-candidate', (data) {
      _onIceCandidateController.add(data);
    });

    _socket.on('user-left', (data) {
      try {
        final userId = data['userId'];
        final participants = (data['participants'] as List)
            .map((p) => Participant.fromJson(p))
            .toList();

        _onUserLeftController.add(userId);
        _onParticipantsController.add(participants);
      } catch (e) {
        print('Error parsing user-left event: $e');
      }
    });

    _socket.on('chat-message', (data) {
      _onChatMessageController.add(data);
    });

    // Connect to the server
    connect();
  }

  // Schedule reconnection attempt
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: 2), () {
      _reconnectAttempts++;
      print(
          'Attempting to reconnect (${_reconnectAttempts}/${_maxReconnectAttempts})');
      connect();
    });
  }

  // Connect to the socket server
  void connect() {
    if (!_socket.connected) {
      _socket.connect();
    }
  }

  // Disconnect from the socket server
  void disconnect() {
    _reconnectTimer?.cancel();
    if (_socket.connected) {
      _socket.disconnect();
    }
  }

  // Join a meeting
  void joinMeeting(String meetingCode, String userName) {
    _userName = userName;
    _meetingCode = meetingCode;

    if (_socket.connected) {
      _socket.emit('join-meeting', {
        'meetingCode': meetingCode,
        'userName': userName,
      });
    } else {
      connect();
    }
  }

  // Leave the current meeting
  void leaveMeeting() {
    if (_meetingCode != null && _socket.connected) {
      _socket.emit('leave-meeting', {
        'meetingCode': _meetingCode,
      });
      _meetingCode = null;
      _userName = null;
    }
  }

  // Send WebRTC offer
  void sendOffer(String targetId, Map<String, dynamic> sdp) {
    if (_socket.connected) {
      _socket.emit('offer', {
        'targetId': targetId,
        'sdp': sdp,
      });
    }
  }

  // Send WebRTC answer
  void sendAnswer(String targetId, Map<String, dynamic> sdp) {
    if (_socket.connected) {
      _socket.emit('answer', {
        'targetId': targetId,
        'sdp': sdp,
      });
    }
  }

  // Send ICE candidate
  void sendIceCandidate(String targetId, Map<String, dynamic> candidate) {
    if (_socket.connected) {
      _socket.emit('ice-candidate', {
        'targetId': targetId,
        'candidate': candidate,
      });
    }
  }

  // Send chat message
  void sendChatMessage(String content) {
    if (_meetingCode != null && _userName != null && _socket.connected) {
      _socket.emit('chat-message', {
        'meetingCode': _meetingCode,
        'message': {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'senderId': _socket.id ?? 'unknown',
          'senderName': _userName!,
          'content': content,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      });
    }
  }

  // Check if connected to server
  bool get isConnected => _socket.connected;

  // Get current socket ID
  String? get socketId => _socket.id;

  // Get current meeting code
  String? get meetingCode => _meetingCode;

  // Dispose resources
  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    disconnect();

    await _onParticipantsController.close();
    await _onOfferController.close();
    await _onAnswerController.close();
    await _onIceCandidateController.close();
    await _onUserLeftController.close();
    await _onChatMessageController.close();
    await _connectionStatusController.close();
  }
}
