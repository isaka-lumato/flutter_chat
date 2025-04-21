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
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  String? _errorMessage;
  bool _isLoading = false;
  bool _isSignUp = false; // Toggle between sign in and sign up



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
                  validator: (value) {
                    final username = value ?? '';
                    final usernameRegExp = RegExp(r'^[a-zA-Z0-9_]{3,}$');
                    if (username.isEmpty) {
                      return 'Enter a username';
                    }
                    if (!usernameRegExp.hasMatch(username)) {
                      return 'Username must be at least 3 characters and only contain letters, numbers, or _';
                    }
                    return null;
                  },
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

                // Google Sign-In Button
                ElevatedButton.icon(
                  // NOTE: Google Drive links like 'https://drive.google.com/file/d/...' are not direct image links and will not work with Image.network.
icon: Image.network(
  'https://img.icons8.com/color/48/000000/google-logo.png',
  height: 24,
  width: 24,
  errorBuilder: (context, error, stackTrace) => Icon(Icons.error, color: Colors.red),
),
                  label: const Text('Sign in with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          try {
                            final user = await _authService.signInWithGoogle();
                            if (user != null) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const HomePage()),
                              );
                            }
                          } catch (e) {
                            setState(() => _errorMessage = e.toString());
                          } finally {
                            setState(() => _isLoading = false);
                          }
                        },
                ),
                const SizedBox(height: 16),
                // Note about username usage
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Note: Your username will be used as your login. No email required.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                // Button to trigger sign in or sign up
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
                  onPressed: _isLoading ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _errorMessage = null;
                        _isLoading = true;
                      });
                      try {
                        User? user;
                        if (_isSignUp) {
                          user = await _authService.signUpWithUsernameAndPassword(
                            _usernameController.text,
                            _passwordController.text,
                          );
                        } else {
                          user = await _authService.signInWithUsernameAndPassword(
                            _usernameController.text,
                            _passwordController.text,
                          );
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
                          setState(() => _errorMessage = e.message ?? e.code);
                        } else {
                          setState(() => _errorMessage = e.toString());
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  },
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
                ),
                const SizedBox(height: 12),
                // Toggle between sign in and sign up
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _errorMessage = null;
                          });
                        },
                  child: Text(
                    _isSignUp
                        ? 'Already have an account? Sign In'
                        : 'Don\'t have an account? Sign Up',
                    style: const TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                      fontSize: 15,
                    ),
                  ),
                ),
                // Placeholder for password reset
                // Uncomment and implement if you want password reset
                // const SizedBox(height: 8),
                // GestureDetector(
                //   onTap: () {
                //     // TODO: Implement password reset
                //   },
                //   child: Text('Forgot password?', style: TextStyle(color: Colors.blue)),
                // ),
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
