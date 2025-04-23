import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_mvp/pages/chat_page.dart';
import 'package:flutter_chat_mvp/pages/new_chat_page.dart';
import 'package:flutter_chat_mvp/pages/profile_page.dart';
import 'package:flutter_chat_mvp/services/user_status_service.dart';

import 'package:flutter_chat_mvp/services/auth_service.dart';
import 'package:flutter_chat_mvp/pages/login_page.dart';
import 'package:intl/intl.dart';

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
            icon: const Icon(Icons.account_circle, color: Color(0xFFE5C3A6), size: 28),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),

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
                  final currentUID = FirebaseAuth.instance.currentUser!.uid;
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    separatorBuilder:
                        (context, index) => const SizedBox(height: 8),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      var conversation =
                          conversations[index].data() as Map<String, dynamic>;
                      String conversationId = conversations[index].id;
                      List participants = conversation['participants'] ?? [];
                      String otherUserId = participants.firstWhere((id) => id != currentUser!.uid, orElse: () => '');
                      String otherUserName = conversation['otherUserName'] ?? 'Chat';
                      final unreadCounts = (conversation['unreadCounts'] as Map<String, dynamic>?) ?? {};
                      final unreadCount = (unreadCounts[currentUID] ?? 0) as int;
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
                          title: Row(
                            children: [
                              // Profile picture
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                                builder: (context, snapshot) {
                                  String? photoUrl;
                                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                                    photoUrl = data?['photoUrl'] as String?;
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10.0),
                                    child: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: Colors.grey.shade300,
                                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: (photoUrl == null || photoUrl.isEmpty)
                                          ? Icon(Icons.person, size: 18, color: Colors.grey.shade700)
                                          : null,
                                    ),
                                  );
                                },
                              ),
                              // Online indicator
                              StreamBuilder<Map<String, dynamic>?>(
                                stream: UserStatusService.userStatusStream(otherUserId),
                                builder: (context, statusSnapshot) {
                                  debugPrint('User $otherUserId status: \\${statusSnapshot.data}');
                                  final isOnline = statusSnapshot.data?['online'] == true;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: isOnline
                                        ? Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          )
                                        : SizedBox(width: 10, height: 10),
                                  );
                                },
                              ),
                              // Username
                              FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(otherUserId).get(),
                                builder: (context, nameSnapshot) {
                                  String displayName = otherUserName;
                                  if (nameSnapshot.connectionState == ConnectionState.done && nameSnapshot.hasData) {
                                    final data = nameSnapshot.data!.data() as Map<String, dynamic>?;
                                    if (data != null && (data['displayName'] as String?)?.isNotEmpty == true) {
                                      displayName = data['displayName'];
                                    }
                                  }
                                  return Text(
                                    displayName,
                                    style: TextStyle(
                                      fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 16,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          subtitle: Text(
                            conversation['lastMessage'] ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    conversation['lastMessageTimestamp'] != null
                                      ? DateFormat('hh:mm a').format((conversation['lastMessageTimestamp'] as Timestamp).toDate())
                                      : '',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(Icons.arrow_forward_ios, color: Colors.grey),
                                ],
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
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
