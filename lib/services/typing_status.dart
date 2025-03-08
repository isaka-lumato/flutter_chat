import 'package:firebase_database/firebase_database.dart' show FirebaseDatabase, DatabaseReference, ServerValue;

class TypingStatusService {
  final DatabaseReference _typingRef = FirebaseDatabase.instance.ref('typing');
  
  void setTypingStatus(String userId, String chatId, bool isTyping) {
    _typingRef.child(chatId).child(userId).set({
      'isTyping': isTyping,
      'timestamp': ServerValue.timestamp,
    });
  }

  Stream<bool> getTypingStatus(String userId, String chatId) {
    return _typingRef
        .child(chatId)
        .child(userId)
        .onValue
        .map((event) {
          final data = event.snapshot.value as Map?;
          return data?['isTyping'] == true;
        });
  }
} 