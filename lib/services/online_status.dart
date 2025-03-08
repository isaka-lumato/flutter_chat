import 'package:firebase_database/firebase_database.dart' show FirebaseDatabase, DatabaseReference, ServerValue;
import 'package:firebase_auth/firebase_auth.dart';

class OnlineStatusService {
  final DatabaseReference _onlineRef = FirebaseDatabase.instance.ref('status');
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  void setOnlineStatus(bool isOnline) {
    _onlineRef.child(userId).set({
      'online': isOnline,
      'lastSeen': ServerValue.timestamp,
    });
  }

  void setupPresence() {
    final connectionRef = FirebaseDatabase.instance.ref('.info/connected');
    
    connectionRef.onValue.listen((event) {
      if (event.snapshot.value == false) {
        return;
      }

      _onlineRef
          .child(userId)
          .onDisconnect()
          .set({
            'online': false,
            'lastSeen': ServerValue.timestamp,
          })
          .then((_) => setOnlineStatus(true));
    });
  }

  Stream<bool> getUserOnlineStatus(String userId) {
    return _onlineRef
        .child(userId)
        .onValue
        .map((event) {
          final data = event.snapshot.value as Map?;
          return data?['online'] == true;
        });
  }
} 