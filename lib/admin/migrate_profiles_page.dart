import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrateProfilesPage extends StatefulWidget {
  const MigrateProfilesPage({Key? key}) : super(key: key);
  @override
  State<MigrateProfilesPage> createState() => _MigrateProfilesPageState();
}

class _MigrateProfilesPageState extends State<MigrateProfilesPage> {
  bool _isMigrating = false;
  String? _result;

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
      _result = null;
    });
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

    setState(() {
      _isMigrating = false;
      _result = 'Migration complete. Updated $updated user profiles.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Migrate User Profiles')),
      body: Center(
        child: _isMigrating
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _runMigration,
                    child: const Text('Run Migration'),
                  ),
                  if (_result != null) ...[
                    const SizedBox(height: 24),
                    Text(_result!),
                  ]
                ],
              ),
      ),
    );
  }
}
