import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/common/bouncy_button.dart';

class RegisterData extends ChangeNotifier {
  String _name = '';
  String _username = '';
  String _email = '';
  String _password = '';
  String _confirmPassword = '';

  String? _nameErrorText;
  String? _usernameErrorText;
  String? _emailErrorText;
  String? _passwordErrorText;
  String? _confirmPasswordErrorText;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get name => _name;
  String get username => _username;
  String get email => _email;
  String get password => _password;
  String get confirmPassword => _confirmPassword;

  String? get nameErrorText => _nameErrorText;
  String? get usernameErrorText => _usernameErrorText;
  String? get emailErrorText => _emailErrorText;
  String? get passwordErrorText => _passwordErrorText;
  String? get confirmPasswordErrorText => _confirmPasswordErrorText;

  bool get isPasswordVisible => _isPasswordVisible;
  bool get isConfirmPasswordVisible => _isConfirmPasswordVisible;

  void setName(String value) {
    if (_name != value) {
      _name = value;
      _nameErrorText = null;
      notifyListeners();
    }
  }

  void setUsername(String value) {
    if (_username != value) {
      _username = value;
      _usernameErrorText = null;
      notifyListeners();
    }
  }

  void setEmail(String value) {
    if (_email != value) {
      _email = value;
      _emailErrorText = null;
      notifyListeners();
    }
  }

  void setPassword(String value) {
    if (_password != value) {
      _password = value;
      _passwordErrorText = null;
      notifyListeners();
    }
  }

  void setConfirmPassword(String value) {
    if (_confirmPassword != value) {
      _confirmPassword = value;
      _confirmPasswordErrorText = null;
      notifyListeners();
    }
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    notifyListeners();
  }

  bool _validateFields() {
    bool isValid = true;
    if (_name.isEmpty) {
      _nameErrorText = 'Please enter your name.';
      isValid = false;
    }
    if (_username.isEmpty) {
      _usernameErrorText = 'Please enter a username.';
      isValid = false;
    } else if (_username.length < 3) {
      _usernameErrorText = 'Username must be at least 3 characters.';
      isValid = false;
    } else if (_username.contains(' ')) {
      _usernameErrorText = 'Username cannot contain spaces.';
      isValid = false;
    }

    if (_email.isEmpty) {
      _emailErrorText = 'Please enter an email.';
      isValid = false;
    }
    if (_password.length < 6) {
      _passwordErrorText = 'Password must be at least 6 characters.';
      isValid = false;
    }
    if (_password != _confirmPassword) {
      _confirmPasswordErrorText = 'Passwords do not match.';
      isValid = false;
    }
    notifyListeners();
    return isValid;
  }

  Future<bool> _isUsernameTaken(String username) async {
    final result = await _firestore
        .collection('users')
        .where('username', isEqualTo: username.trim().toLowerCase())
        .get();
    return result.docs.isNotEmpty;
  }

  Future<String?> signUp() async {
    if (!_validateFields()) {
      return "Please fix the errors above.";
    }

    if (await _isUsernameTaken(_username)) {
      _usernameErrorText = 'This username is already taken.';
      notifyListeners();
      return "Please choose a different username.";
    }

    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: _email.trim(),
            password: _password.trim(),
          );

      await userCredential.user?.updateProfile(displayName: _name.trim());

      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': _name.trim(),
          'username': _username
              .trim()
              .toLowerCase(),
          'email': _email.trim(),
          'createdAt': Timestamp.now(),
          'firstName': _name.trim().split(' ').first,
          'lastName': _name.trim().contains(' ')
              ? _name.trim().split(' ').last
              : '',
          'occupation': '',
          'location': '',
          'phoneNumber': '',
          'photoURL':
              'https://www.gstatic.com/flutter-onestack-prototype/genui/example_1.jpg',
        });
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        return 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        return 'An account already exists for that email.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is not valid.';
      }
      return 'An error occurred. Please try again.';
    }
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RegisterData(),
      child: const _RegisterView(),
    );
  }
}

class _RegisterView extends StatelessWidget {
  const _RegisterView();

  @override
  Widget build(BuildContext context) {
    final registerData = context.watch<RegisterData>();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/img/background.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    width: 350,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          onChanged: (value) => registerData.setName(value),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            labelStyle: const TextStyle(color: Colors.white70),
                            errorText: registerData.nameErrorText,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            suffixIcon: const Icon(
                              Icons.person,
                              color: Colors.white70,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          onChanged: (value) => registerData.setUsername(value),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Username",
                            labelStyle: const TextStyle(color: Colors.white70),
                            errorText: registerData.usernameErrorText,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            suffixIcon: const Icon(
                              Icons.alternate_email,
                              color: Colors.white70,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          onChanged: (value) => registerData.setEmail(value),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Email",
                            labelStyle: const TextStyle(color: Colors.white70),
                            errorText: registerData.emailErrorText,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            suffixIcon: const Icon(
                              Icons.email,
                              color: Colors.white70,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          obscureText: !registerData.isPasswordVisible,
                          onChanged: (value) => registerData.setPassword(value),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: const TextStyle(color: Colors.white70),
                            errorText: registerData.passwordErrorText,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            suffixIcon: IconButton(
                              icon: Icon(
                                registerData.isPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed: () =>
                                  registerData.togglePasswordVisibility(),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          obscureText: !registerData.isConfirmPasswordVisible,
                          onChanged: (value) =>
                              registerData.setConfirmPassword(value),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            labelStyle: const TextStyle(color: Colors.white70),
                            errorText: registerData.confirmPasswordErrorText,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.1),
                            suffixIcon: IconButton(
                              icon: Icon(
                                registerData.isConfirmPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.white70,
                              ),
                              onPressed: () => registerData
                                  .toggleConfirmPasswordVisibility(),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: BouncyButton(
                            onPressed: () async {
                              final String? error = await registerData.signUp();
                              if (context.mounted) {
                                if (error == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Registration successful! Please log in.',
                                      ),
                                    ),
                                  );
                                  Navigator.pop(
                                    context,
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(error)),
                                  );
                                }
                              }
                            },
                            child: ElevatedButton(
                              onPressed: null, // Handled by wrapper
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text("Register"),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Already have an account?",
                              style: TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
