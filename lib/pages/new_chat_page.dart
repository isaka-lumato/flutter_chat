import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_mvp/pages/chat_page.dart';
import 'package:google_fonts/google_fonts.dart';

class NewChatPage extends StatelessWidget {
  const NewChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: Text("Select a User", style: GoogleFonts.lato()),
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final users =
              snapshot.data!.docs
                  .where((doc) => doc.id != currentUser.uid)
                  .toList();
          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final data = users[index].data() as Map<String, dynamic>;
              final otherUserId = users[index].id;
              final otherUserName = data['username'] ?? 'Unknown';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                child: ListTile(
                  leading: CircleAvatar(
  radius: 22,
  backgroundColor: Colors.grey.shade300,
  backgroundImage: (data['photoUrl'] != null && (data['photoUrl'] as String).isNotEmpty)
      ? NetworkImage(data['photoUrl'])
      : null,
  child: (data['photoUrl'] == null || (data['photoUrl'] as String).isEmpty)
      ? Text(
          otherUserName.substring(0, 1).toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        )
      : null,
),
                  title: Text(otherUserName, style: GoogleFonts.lato()),
                  onTap: () async {
                    List<String> ids = [currentUser.uid, otherUserId];
                    ids.sort();
                    final conversationId = ids.join('_');
                    final conversationRef = FirebaseFirestore.instance
                        .collection('conversations')
                        .doc(conversationId);
                    await conversationRef.set({
                      'participants': ids,
                      'otherUserName': otherUserName,
                      'lastUpdated': FieldValue.serverTimestamp(),
                      'lastMessage': '',
                    }, SetOptions(merge: true));
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ChatPage(
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
    );
  }
}
