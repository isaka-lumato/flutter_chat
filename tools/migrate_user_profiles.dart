import 'package:cloud_firestore/cloud_firestore.dart';

/// Run this script ONCE to update all existing user profiles in Firestore
/// to have displayName, bio, photoUrl, and email fields with sensible defaults.
/// Usage: flutter pub run tools/migrate_user_profiles.dart
Future<void> main() async {
  final firestore = FirebaseFirestore.instance;
  final users = await firestore.collection('users').get();
  int updated = 0;

  for (final doc in users.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    if (!data.containsKey('displayName')) {
      updates['displayName'] = data['username'] ?? 'Unknown User';
    }
    if (!data.containsKey('bio')) {
      updates['bio'] = '';
    }
    if (!data.containsKey('photoUrl')) {
      updates['photoUrl'] = '';
    }
    if (!data.containsKey('email')) {
      updates['email'] = data['email'] ?? '';
    }

    if (updates.isNotEmpty) {
      await doc.reference.set(updates, SetOptions(merge: true));
      updated++;
    }
  }

  print('Migration complete. Updated $updated user profiles.');
}
