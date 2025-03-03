import 'package:flutter/material.dart';
import 'package:flutter_application_2/models/message.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatPanel extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String) onSendMessage;
  final String currentUserId;

  const ChatPanel({
    super.key,
    required this.messages,
    required this.onSendMessage,
    required this.currentUserId,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  // Convert app messages to chat UI messages
  List<types.Message> _getMessages() {
    return widget.messages.map((message) => message.toChatUiMessage()).toList();
  }

  // Handle sending a message
  void _handleSendPressed(types.PartialText message) {
    widget.onSendMessage(message.text);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = types.User(id: widget.currentUserId);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        children: [
          // Chat header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.chat),
                const SizedBox(width: 8),
                Text(
                  'Chat',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),

          // Chat messages
          Expanded(
            child: Chat(
              messages: _getMessages(),
              onSendPressed: _handleSendPressed,
              user: currentUser,
              theme: DefaultChatTheme(
                backgroundColor: Theme.of(context).colorScheme.surface,
                primaryColor: Theme.of(context).colorScheme.primary,
                secondaryColor: Theme.of(context).colorScheme.surfaceVariant,
                inputBackgroundColor:
                    Theme.of(context).colorScheme.surfaceVariant,
                inputTextColor: Theme.of(context).colorScheme.onSurface,
                sentMessageBodyTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16,
                ),
                receivedMessageBodyTextStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              showUserNames: true,
              showUserAvatars: false,
              emptyState: Center(
                child: Text(
                  'No messages yet',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
