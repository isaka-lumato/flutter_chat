import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_mvp/services/auth_service.dart'; // Import the AuthService
import 'package:flutter_chat_mvp/pages/home_page.dart'; // Import the HomePage

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // GlobalKey for the form to manage form state and validation
  final _formKey = GlobalKey<FormState>();

  // TextEditingControllers to manage the text input for username and password
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // Instance of AuthService to handle authentication logic
  final _authService = AuthService();

  // Variable to store and display error messages to the user
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Changed from gradient decoration back to plain white background
        color: Colors.white,
        child: Form(
          key: _formKey, // Assign the GlobalKey to the Form
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Add the logo at the top
                Image.asset('assets/images/logo.png', height: 120),
                const SizedBox(height: 20),
                // Conditionally display the error message if it's not null
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                ],

                // TextFormField for username input
                TextFormField(
                  controller: _usernameController, // Attach the controller
                  decoration: const InputDecoration(labelText: 'Username'),
                  validator:
                      (value) =>
                          value!.isEmpty
                              ? 'Enter a username'
                              : null, // Validate that the field is not empty
                ),

                // TextFormField for password input
                TextFormField(
                  controller: _passwordController, // Attach the controller
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true, // Hide the password text
                  validator:
                      (value) =>
                          value!.length < 6
                              ? 'Password must be at least 6 characters'
                              : null, // Validate password length
                ),
                const SizedBox(height: 20),

                // Button to trigger login/register process
                ElevatedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Colors.blue.shade600),
                    foregroundColor: MaterialStateProperty.all(Colors.white),
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    textStyle: MaterialStateProperty.all(
                      const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    elevation: MaterialStateProperty.all(2),
                    overlayColor: MaterialStateProperty.resolveWith<Color?>(
                      (states) {
                        if (states.contains(MaterialState.pressed)) {
                          return Colors.blue.shade800;
                        }
                        return null;
                      },
                    ),
                  ),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _errorMessage = null);
                      try {
                        User? user;
                        try {
                          // Attempt to sign in
                          user = await _authService
                              .signInWithUsernameAndPassword(
                                _usernameController.text,
                                _passwordController.text,
                              );
                        } on FirebaseAuthException catch (e) {
                          if (e.code == 'user-not-found') {
                            // If not found, attempt to sign up
                            user = await _authService
                                .signUpWithUsernameAndPassword(
                                  _usernameController.text,
                                  _passwordController.text,
                                );
                          } else {
                            rethrow;
                          }
                        }

                        if (user != null) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HomePage(),
                            ),
                          );
                        }
                      } catch (e) {
                        if (e is FirebaseAuthException) {
                          print("Firebase Auth Error Code: ${e.code}");
                          print("Firebase Auth Error Message: ${e.message}");
                          setState(() => _errorMessage = e.message ?? e.code);
                        } else {
                          print(
                            "Generic Error during Login/Register: ${e.toString()}",
                          );
                          setState(() => _errorMessage = e.toString());
                        }
                      }
                    }
                  },
                  child: const Text('Login or Register'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Clean up resources by disposing of the controllers when the widget is removed
  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
