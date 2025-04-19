import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with username and password (no duplicate check)
  Future<User?> signUpWithUsernameAndPassword(
    String username,
    String password,
  ) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: "$username@example.com",
        password: password,
      );
      final User? user = result.user;
      if (user != null) {
        // Update display name and store user data in Firestore
        await user.updateDisplayName(username);
        await user.reload(); // Force reload after update
        final updatedUser = _auth.currentUser;
        await _firestore.collection('users').doc(user.uid).set({
          'displayName': username,
          'bio': '',
          'photoUrl': '',
          'email': user.email ?? '',
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return updatedUser;
      }
      return user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      print("Generic Error: $e");
      rethrow;
    }
  }

  // Sign in with username and password
  Future<User?> signInWithUsernameAndPassword(
    String username,
    String password,
  ) async {
    try {
      final email = "$username@example.com";
      print("DEBUG: =====================");
      print("DEBUG: Sign-in attempt start");
      print("DEBUG: Email being used: $email");

      // Add verification that the user exists first
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      print("DEBUG: Available sign-in methods: $methods");

      if (methods.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that email.',
        );
      }

      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      print("DEBUG: Sign-in successful");
      print("DEBUG: User ID: ${result.user?.uid}");
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("DEBUG: Firebase Auth Exception: ${e.code}");
      rethrow;
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print("Error signing out: $e");
      rethrow;
    }
  }
}
