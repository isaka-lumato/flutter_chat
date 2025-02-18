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
      appBar: AppBar(title: const Text('Login / Register')),
      body: Form(
        key: _formKey, // Assign the GlobalKey to the Form
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Conditionally display the error message if it's not null
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
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
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    // Validate the form inputs
                    setState(
                      () => _errorMessage = null,
                    ); // Clear any previous error message
                    try {
                      // Attempt to sign in the user
                      var user = await _authService
                          .signInWithUsernameAndPassword(
                            _usernameController
                                .text, // Get the username from the controller
                            _passwordController
                                .text, // Get the password from the controller
                          );

                      // If sign-in fails (user is null), attempt to sign up the user
                      if (user == null) {
                        user = await _authService.signUpWithUsernameAndPassword(
                          _usernameController.text,
                          _passwordController.text,
                        );
                      }

                      // If sign-in or sign-up is successful, navigate to the HomePage
                      if (user != null) {
                        // Navigate to chat page and replace
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomePage(),
                          ),
                        );
                      }
                    } catch (e) {
                      setState(
                        () => _errorMessage = e.toString(),
                      ); // Update the error message state
                    }
                  }
                },
                child: const Text('Login / Register'),
              ),
            ],
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
