import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_mvp/pages/chat_page.dart'; // Import the ChatPage (we'll create this in the next phase)
import 'package:flutter_chat_mvp/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final _authService = AuthService(); // Instance of AuthService

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Chats',
        ), // A more appropriate title for the home page
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut(); // Call the signOut method
              // Check if the widget is still mounted before navigating.
              if (!mounted) return;
              Navigator.pushReplacementNamed(
                context,
                '/login',
              ); // Navigate back to login
            },
          ),
        ],
      ),
      body:
          _buildConversationList(), // This function will display the list of users (or eventually, conversations)
    );
  }

  Widget _buildConversationList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          _firestore
              .collection('users')
              .snapshots(), // Stream of all users from Firestore
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<DocumentSnapshot> users = snapshot.data!.docs;
        // Filter out the current user so they don't see themselves in the list
        users =
            users.where((user) => user.id != _auth.currentUser!.uid).toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            return _buildConversationListItem(users[index]);
          },
        );
      },
    );
  }

  Widget _buildConversationListItem(DocumentSnapshot otherUser) {
    Map<String, dynamic> userData = otherUser.data() as Map<String, dynamic>;
    String otherUserId = otherUser.id;
    String currentUserId = _auth.currentUser!.uid;

    // Create a consistent conversation ID.  This is VERY important for private messaging.
    List<String> ids = [currentUserId, otherUserId];
    ids.sort(); // ALWAYS sort the UIDs to get the same ID regardless of who initiates the chat
    String conversationId = ids.join('_');

    return ListTile(
      title: Text(
        userData['username'] ?? 'Unknown User',
      ), // Display the username
onTap: () {
        // Navigate to the ChatPage, passing the conversation ID and other user's ID
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatPage(
                  // Corrected line: Use =>, not ->
                  conversationId: conversationId,
                  otherUserId: otherUserId,
                  otherUserName: userData['username'],
                ),
          ),
        );
      },
    );
  }
}
