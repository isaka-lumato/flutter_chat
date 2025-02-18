import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Instance of FirebaseAuth for handling user authentication
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Instance of FirebaseFirestore for interacting with the database
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with username and password
  Future<User?> signUpWithUsernameAndPassword(
    String username,
    String password,
  ) async {
    try {
      // Check if the username already exists in Firestore
      final usernameQuery =
          await _firestore
              .collection('users')
              .where('username', isEqualTo: username)
              .get();
      if (usernameQuery.docs.isNotEmpty) {
        throw Exception(
          'Username already taken',
        ); // Throw a custom exception if the username is taken
      }

      // Create a new user in Firebase Authentication using a dummy email
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email:
            '$username@yourdomain.com', // Create a dummy email address using the username
        password: password,
      );
      User? user = result.user; // Get the newly created user object

      // Store the username and user ID in Firestore
      await _firestore.collection('users').doc(user!.uid).set({
        'username': username, // Store the provided username
        'uid': user.uid, // Store the user's unique ID
      });

      return user; // Return the newly created user
    } on FirebaseAuthException catch (e) {
      return Future.error(e.message ?? 'An error ocurred');
    } catch (e) {
      return Future.error(
        e.toString(),
      ); // Catch any other errors that may occur
    }
  }

  // Sign in with username and password
  Future<User?> signInWithUsernameAndPassword(
    String username,
    String password,
  ) async {
    try {
      // Sign in the user using Firebase Authentication with the dummy email and password
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: '$username@yourdomain.com', // Use the dummy email address
        password: password,
      );
      return result.user; // Return the signed-in user
    } on FirebaseAuthException catch (e) {
      return Future.error(e.message ?? "Authentication Error");
    } catch (e) {
      return Future.error(e.toString()); // Catch any other errors
    }
  }

  // Sign out the current user
  Future<void> signOut() async {
    return await _auth.signOut();
  }

  // Get current user
  Stream<User?> get user => _auth.authStateChanges();
}
