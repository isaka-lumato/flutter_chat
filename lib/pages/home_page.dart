import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_mvp/pages/chat_page.dart';
import 'package:flutter_chat_mvp/pages/new_chat_page.dart';
import 'package:flutter_chat_mvp/services/auth_service.dart';
import 'package:flutter_chat_mvp/pages/login_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E4374), // Deep blue color
        title: const Text(
          'Lenus connect',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFE5C3A6), // Soft golden color
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 4, // Add subtle shadow
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout,
              color: Color(0xFFE5C3A6),
            ), // Match title color
            onPressed: () async {
              try {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              } catch (e) {
                print("Logout error: $e");
              }
            },
          ),
        ],
      ),
      body:
          currentUser == null
              ? const Center(child: Text('No user found.'))
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('conversations')
                        .where('participants', arrayContains: currentUser.uid)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text('No chats available'));
                  }
                  final conversations = snapshot.data!.docs;
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 8),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      var conversation =
                          conversations[index].data() as Map<String, dynamic>;
                      String conversationId = conversations[index].id;
                      String otherUserName =
                          conversation['otherUserName'] ?? 'Chat';
                      String otherUserId = conversation['otherUserId'] ?? '';
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          title: Text(
                            otherUserName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => ChatPage(
                                      conversationId: conversationId,
                                      otherUserId: otherUserId,
                                      otherUserName: otherUserName,
                                    ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2E4374), // Match AppBar color
        child: const Icon(
          Icons.chat,
          color: Color(0xFFE5C3A6),
        ), // Match title color
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewChatPage()),
          );
        },
      ),
    );
  }
}
