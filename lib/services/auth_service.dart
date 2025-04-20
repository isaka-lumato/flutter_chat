import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with username and password (with username uniqueness check)
  Future<User?> signUpWithUsernameAndPassword(
    String username,
    String password,
  ) async {
    try {
      // Check if username is taken in Firestore
      final query = await _firestore
          .collection('users')
          .where('displayName', isEqualTo: username)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: 'That username is already taken. Please choose another.',
        );
      }
      final email = "$username@example.com";
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = result.user;
      if (user != null) {
        // Update display name and store user data in Firestore in parallel
        await Future.wait([
          user.updateDisplayName(username),
          _firestore.collection('users').doc(user.uid).set({
            'displayName': username,
            'bio': '',
            'photoUrl': '',
            'email': user.email ?? '',
            'uid': user.uid,
            'createdAt': FieldValue.serverTimestamp(),
          }),
        ]);
        return user;
      }
      return user;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: _friendlyAuthError(e),
      );
    } catch (e) {
      throw Exception('An unknown error occurred. Please try again.');
    }
  }

  // Sign in with username and password (optimized)
  Future<User?> signInWithUsernameAndPassword(
    String username,
    String password,
  ) async {
    try {
      final email = "$username@example.com";
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw FirebaseAuthException(
        code: e.code,
        message: _friendlyAuthError(e),
      );
    } catch (e) {
      throw Exception('An unknown error occurred. Please try again.');
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

  // Helper for user-friendly error messages
  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with that username.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'That username is already taken.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Invalid username format.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'username-already-in-use':
        return 'That username is already taken. Please choose another.';
      case 'invalid-credential':
      case 'invalid-email':
        return 'The username or credential is invalid or malformed.';
      default:
        return e.message ?? 'Authentication error.';
    }
  }
}


