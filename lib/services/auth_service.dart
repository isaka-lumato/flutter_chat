import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with username and password (with username uniqueness check)
  Future<User?> signUpWithUsernameAndPassword(
    String username,
    String password,
  ) async {
    try {
      print('DEBUG: Starting signUpWithUsernameAndPassword for username: $username');
      // Check if username is taken in Firestore
      final query = await _firestore
          .collection('users')
          .where('displayName', isEqualTo: username)
          .limit(1)
          .get();
      print('DEBUG: Username check complete, docs found: ${query.docs.length}');
      if (query.docs.isNotEmpty) {
        print('DEBUG: Username already in use');
        throw FirebaseAuthException(
          code: 'username-already-in-use',
          message: 'That username is already taken. Please choose another.',
        );
      }
      final email = "$username@example.com";
      print('DEBUG: Creating user with email: $email');
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final User? user = result.user;
      print('DEBUG: User creation result: ${user?.uid}');
      if (user != null) {
        print('DEBUG: Updating displayName and writing user doc to Firestore');
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
        print('DEBUG: Firestore write and displayName update complete');
        return user;
      }
      print('DEBUG: User is null after creation');
      return user;
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException: ${e.code} ${e.message}');
      throw FirebaseAuthException(
        code: e.code,
        message: _friendlyAuthError(e),
      );
    } catch (e, stack) {
      print('DEBUG: Unknown error in signUpWithUsernameAndPassword: $e');
      print(stack);
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
      await GoogleSignIn().signOut(); // Also sign out from Google
    } catch (e) {
      print("Error signing out: $e");
      rethrow;
    }
  }

  // Google Sign-In
  Future<User?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return null;
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final UserCredential userCredential = await _auth.signInWithCredential(credential);
    final User? user = userCredential.user;
    if (user != null) {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      String username = user.displayName ?? '';
      // If displayName is not set, use the email prefix
      if (username.isEmpty && user.email != null && user.email!.contains('@')) {
        username = user.email!.split('@')[0];
        await user.updateDisplayName(username);
      }
      // If user doc does not exist or missing displayName, set it
      final docData = userDoc.data();
      final firestoreDisplayName = docData != null ? docData['displayName'] as String? : null;
      if (!userDoc.exists || firestoreDisplayName == null || firestoreDisplayName.isEmpty) {
        await _firestore.collection('users').doc(user.uid).set({
          'displayName': username,
          'username': username, // Set username same as displayName by default
          'bio': '',
          'photoUrl': user.photoURL ?? '',
          'email': user.email ?? '',
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
    return user;
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


