import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/screens/meeting_screen.dart';
import 'package:flutter_application_2/services/meeting_service.dart';
import 'package:flutter_application_2/theme/app_theme.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  final MeetingService _meetingService = MeetingService();

  bool _isCreating = false;
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // Create a new meeting
  Future<void> _createMeeting() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final code = await _meetingService.createMeeting();

      if (mounted) {
        _navigateToMeeting(code);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create meeting: $e';
          _isCreating = false;
        });
      }
    }
  }

  // Join an existing meeting
  Future<void> _joinMeeting() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }

    if (_codeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a meeting code';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final exists =
          await _meetingService.checkMeetingExists(_codeController.text);

      if (mounted) {
        if (exists) {
          _navigateToMeeting(_codeController.text);
        } else {
          setState(() {
            _errorMessage = 'Meeting not found';
            _isJoining = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to join meeting: $e';
          _isJoining = false;
        });
      }
    }
  }

  // Navigate to the meeting screen
  void _navigateToMeeting(String code) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MeetingScreen(
          meetingCode: code,
          userName: _nameController.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<AppTheme>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Call App'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeProvider.toggleTheme();
            },
            tooltip: 'Toggle theme',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App logo or icon
                Icon(
                  Icons.video_call,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // App title
                Text(
                  'Video Call App',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 8),

                // App description
                Text(
                  'Connect with friends and colleagues through high-quality video calls',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 48),

                // Name input
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Your Name',
                    hintText: 'Enter your name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // Meeting code input
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Meeting Code',
                    hintText: 'Enter meeting code to join',
                    prefixIcon: const Icon(Icons.numbers),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                ),
                const SizedBox(height: 24),

                // Join meeting button
                ElevatedButton.icon(
                  onPressed: _isJoining || _isCreating ? null : _joinMeeting,
                  icon: _isJoining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Join Meeting'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 16),

                // Create meeting button
                OutlinedButton.icon(
                  onPressed: _isCreating || _isJoining ? null : _createMeeting,
                  icon: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Create New Meeting'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                // Error message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
