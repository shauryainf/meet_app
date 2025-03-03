import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/models/message.dart';
import 'package:flutter_application_2/models/participant.dart';
import 'package:flutter_application_2/screens/home_screen.dart';
import 'package:flutter_application_2/services/socket_service.dart';
import 'package:flutter_application_2/services/webrtc_service.dart';
import 'package:flutter_application_2/theme/app_theme.dart';
import 'package:flutter_application_2/widgets/chat_panel.dart';
import 'package:flutter_application_2/widgets/video_panel.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';

class MeetingScreen extends StatefulWidget {
  final String meetingCode;
  final String userName;

  const MeetingScreen({
    super.key,
    required this.meetingCode,
    required this.userName,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late SocketService _socketService;
  late WebRTCService _webRTCService;

  List<Participant> _participants = [];
  List<ChatMessage> _messages = [];

  bool _isAudioEnabled = true;
  bool _isVideoEnabled = true;
  bool _isChatVisible = false;
  bool _isInitializing = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Initialize services and join meeting
  Future<void> _initialize() async {
    try {
      // Create socket service
      _socketService = SocketService();

      // Create WebRTC service
      _webRTCService = WebRTCService(_socketService);

      // Initialize local media
      await _webRTCService.initLocalMedia();

      // Listen for participant updates
      _socketService.onParticipants.listen((participants) {
        setState(() {
          _participants = participants;
        });

        // Call new participants that aren't the current user
        for (final participant in participants) {
          if (participant.id != _socketService.socketId &&
              !_webRTCService.remoteRenderers.containsKey(participant.id)) {
            _webRTCService.call(participant.id);
          }
        }
      });

      // Listen for chat messages
      _socketService.onChatMessage.listen((data) {
        final message = ChatMessage(
          id: data['id'] ?? const Uuid().v4(),
          senderId: data['senderId'] ?? '',
          senderName: data['senderName'] ?? 'Unknown',
          content: data['content'] ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
              data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
        );

        setState(() {
          _messages = [..._messages, message];
        });
      });

      // Join the meeting
      _socketService.joinMeeting(widget.meetingCode, widget.userName);

      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _hasError = true;
        _errorMessage = 'Failed to initialize meeting: $e';
      });
    }
  }

  // Toggle audio
  void _toggleAudio() {
    _webRTCService.toggleAudio();
    setState(() {
      _isAudioEnabled = !_isAudioEnabled;
    });
  }

  // Toggle video
  void _toggleVideo() {
    _webRTCService.toggleVideo();
    setState(() {
      _isVideoEnabled = !_isVideoEnabled;
    });
  }

  // Toggle chat panel
  void _toggleChat() {
    setState(() {
      _isChatVisible = !_isChatVisible;
    });
  }

  // Leave meeting
  Future<void> _leaveMeeting() async {
    _socketService.leaveMeeting();
    await _socketService.dispose();
    await _webRTCService.dispose();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }

  // Send a chat message
  void _sendMessage(String content) {
    if (content.trim().isEmpty) return;

    _socketService.sendChatMessage(content);
  }

  // Copy meeting code to clipboard
  void _copyMeetingCode() {
    Clipboard.setData(ClipboardData(text: widget.meetingCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Meeting code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    // Use a future to dispose of the services since we can't make dispose() async
    Future.microtask(() async {
      try {
        await _socketService.dispose();
      } catch (e) {
        print('Error disposing socket service: $e');
      }

      try {
        await _webRTCService.dispose();
      } catch (e) {
        print('Error disposing WebRTC service: $e');
      }
    });

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<AppTheme>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Initializing meeting...',
                  style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 24),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'An unknown error occurred',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Go back to home'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Main meeting screen
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Meeting'),
            const SizedBox(width: 8),
            Chip(
              label: Text(
                widget.meetingCode,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        actions: [
          // Copy meeting code button
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyMeetingCode,
            tooltip: 'Copy meeting code',
          ),
          // Theme toggle button
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: 'Toggle theme',
          ),
          // Chat toggle button
          IconButton(
            icon: Badge(
              isLabelVisible: _messages.isNotEmpty && !_isChatVisible,
              child: Icon(_isChatVisible ? Icons.chat : Icons.chat_outlined),
            ),
            onPressed: _toggleChat,
            tooltip: 'Toggle chat',
          ),
        ],
      ),
      body: isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout(),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Audio toggle button
              IconButton(
                icon: Icon(_isAudioEnabled ? Icons.mic : Icons.mic_off),
                onPressed: _toggleAudio,
                tooltip:
                    _isAudioEnabled ? 'Mute microphone' : 'Unmute microphone',
                color: _isAudioEnabled
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
              // Video toggle button
              IconButton(
                icon:
                    Icon(_isVideoEnabled ? Icons.videocam : Icons.videocam_off),
                onPressed: _toggleVideo,
                tooltip: _isVideoEnabled ? 'Turn off camera' : 'Turn on camera',
                color: _isVideoEnabled
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
              // Switch camera button
              IconButton(
                icon: const Icon(Icons.switch_camera),
                onPressed: _webRTCService.switchCamera,
                tooltip: 'Switch camera',
              ),
              // End call button
              IconButton(
                icon: const Icon(Icons.call_end),
                onPressed: _leaveMeeting,
                tooltip: 'Leave meeting',
                color: Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Layout for landscape orientation
  Widget _buildLandscapeLayout() {
    return Row(
      children: [
        // Video panel
        Expanded(
          flex: _isChatVisible ? 2 : 3,
          child: VideoPanel(
            localRenderer: _webRTCService.localRenderer,
            remoteRenderers: _webRTCService.remoteRenderers,
            participants: _participants,
          ),
        ),

        // Chat panel
        if (_isChatVisible)
          Expanded(
            flex: 1,
            child: ChatPanel(
              messages: _messages,
              onSendMessage: _sendMessage,
              currentUserId: _socketService.socketId ?? 'unknown',
            ),
          ),
      ],
    );
  }

  // Layout for portrait orientation
  Widget _buildPortraitLayout() {
    return Column(
      children: [
        // Video panel
        Expanded(
          flex: _isChatVisible ? 1 : 2,
          child: VideoPanel(
            localRenderer: _webRTCService.localRenderer,
            remoteRenderers: _webRTCService.remoteRenderers,
            participants: _participants,
          ),
        ),

        // Chat panel
        if (_isChatVisible)
          Expanded(
            flex: 1,
            child: ChatPanel(
              messages: _messages,
              onSendMessage: _sendMessage,
              currentUserId: _socketService.socketId ?? 'unknown',
            ),
          ),
      ],
    );
  }
}
