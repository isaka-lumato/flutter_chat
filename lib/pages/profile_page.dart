import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'edit_profile_page.dart';
import '../services/image_service.dart';

class ProfilePage extends StatefulWidget {
  final String? userId; // If null, show current user's profile
  const ProfilePage({Key? key, this.userId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  String? displayName;
  String? photoUrl;
  String? bio;
  String? email;
  bool isLoading = true;
  bool isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final currentUser = _auth.currentUser;
    final profileUid = widget.userId ?? currentUser?.uid;
    if (profileUid == null || profileUid.isEmpty) {
      setState(() {
        displayName = 'Invalid User';
        photoUrl = '';
        bio = '';
        email = '';
        isCurrentUser = false;
        isLoading = false;
      });
      return;
    }
    final doc = await _firestore.collection('users').doc(profileUid).get();
    final data = doc.data();
    if (data == null || data.isEmpty) {
      print('DEBUG: No profile data found for user $profileUid');
      setState(() {
        displayName = 'Unknown User';
        photoUrl = '';
        bio = '';
        email = '';
        isCurrentUser = profileUid == currentUser?.uid;
        isLoading = false;
      });
      return;
    }
    setState(() {
      displayName = data['displayName'] ?? data['username'] ?? (profileUid == currentUser?.uid ? currentUser?.displayName ?? '' : 'Unknown User');
      photoUrl = data['photoUrl'] ?? (profileUid == currentUser?.uid ? currentUser?.photoURL : null) ?? '';
      bio = data['bio'] ?? '';
      email = (profileUid == currentUser?.uid) ? currentUser?.email : data['email'] ?? '';
      isCurrentUser = profileUid == currentUser?.uid;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 1,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
                              ? NetworkImage(photoUrl!)
                              : null,
                          child: (photoUrl == null || photoUrl!.isEmpty)
                              ? Icon(Icons.person, size: 56, color: theme.colorScheme.primary)
                              : null,
                        ),
                        if (isCurrentUser)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: InkWell(
                              onTap: () async {
                                final imageService = ImageService();
                                final file = await imageService.pickImage();
                                if (file != null) {
                                  // Use user.uid as the folder for profile photos
                                  final uid = _auth.currentUser?.uid;
                                  if (uid != null) {
                                    final url = await imageService.uploadImage(file, uid, isProfilePhoto: true);
                                    if (url != null) {
                                      await _firestore.collection('users').doc(uid).set({
                                        'photoUrl': url,
                                      }, SetOptions(merge: true));
                                      setState(() {
                                        photoUrl = url;
                                      });
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to upload profile picture.')),
                                      );
                                    }
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: theme.colorScheme.primary,
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    (displayName != null && displayName!.isNotEmpty) ? displayName! : 'No display name',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (email != null && email!.isNotEmpty) ? email! : 'No email set',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 24),
                  if (bio != null && bio!.isNotEmpty)
                    Text(
                      bio!,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  if (bio == null || bio!.isEmpty)
                    Text(
                      'No bio set',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                    ),
                  const SizedBox(height: 32),
                  if (isCurrentUser)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Profile'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfilePage(
                              displayName: displayName,
                              bio: bio,
                            ),
                          ),
                        );
                        if (updated == true) {
                          setState(() => isLoading = true);
                          await _loadProfile();
                        }
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
