import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat with ${widget.otherUserName}',
        ), // Display other user's name in AppBar
      ),
      body: Center(
        child: Text(
          'Chat Page Content will go here!',
        ), // Placeholder text for now
      ),
    );
  }
}
