import 'package:firebase_database/firebase_database.dart';

class UserStatusService {
  static Stream<Map<String, dynamic>?> userStatusStream(String userId) {
    final ref = FirebaseDatabase.instance.ref('status/$userId');
    return ref.onValue.map((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        return data;
      }
      return null;
    });
  }
}
