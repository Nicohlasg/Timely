import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';
import '../state/achievement_state.dart';
import '../widgets/common/bouncy_button.dart';

class LoginData extends ChangeNotifier {
  String _email = '';
  String _password = '';
  String? _emailErrorText;
  String? _passwordErrorText;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _kRememberedEmailKey = 'remembered_email';

  String get email => _email;
  String get password => _password;
  String? get emailErrorText => _emailErrorText;
  String? get passwordErrorText => _passwordErrorText;
  bool get isPasswordVisible => _isPasswordVisible;
  bool get rememberMe => _rememberMe;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString(_kRememberedEmailKey);
    if (rememberedEmail != null) {
      _email = rememberedEmail;
      _rememberMe = true;
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

  void setRememberMe(bool value) {
    if (_rememberMe != value) {
      _rememberMe = value;
      notifyListeners();
    }
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  bool validate() {
    bool isValid = true;
    if (_email.isEmpty) {
      _emailErrorText = 'Please enter an email.';
      isValid = false;
    } else {
      _emailErrorText = null;
    }

    if (_password.isEmpty) {
      _passwordErrorText = 'Please enter a password.';
      isValid = false;
    } else {
      _passwordErrorText = null;
    }
    notifyListeners();
    return isValid;
  }

  Future<String?> signIn(BuildContext context) async {
    if (!validate()) {
      return "Please fix the errors above.";
    }

    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_kRememberedEmailKey, _email.trim());
    } else {
      await prefs.remove(_kRememberedEmailKey);
    }

    try {
      debugPrint('Attempting to sign in with Firebase Auth...');
      await _auth.signInWithEmailAndPassword(
        email: _email.trim(),
        password: _password.trim(),
      );

      // Check for first login achievement
      final isFirstLogin = prefs.getBool('is_first_login') ?? true;
      if (isFirstLogin) {
        await context
            .read<AchievementState>()
            .unlockAchievement('first_login');
        await prefs.setBool('is_first_login', false);
      }

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        return 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        return 'The email address is not valid.';
      }
      return 'An error occurred. Please try again.';
    }
  }
}

class LoginPage extends StatefulWidget {
  final bool showTutorial;
  const LoginPage({super.key, this.showTutorial = false});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final LoginData _loginData = LoginData();

  @override
  void initState() {
    super.initState();
    _loginData.init();
    if (widget.showTutorial) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ShowCaseWidget.of(context).startShowCase([
          _LoginViewState._emailKey,
          _LoginViewState._passwordKey,
          _LoginViewState._loginButtonKey,
        ]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _loginData,
      child: ShowCaseWidget(
        builder: Builder(
          builder: (context) => const _LoginView(),
        ),
      ),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => __LoginViewState();
}

class __LoginViewState extends State<_LoginView> {
  static final _emailKey = GlobalKey();
  static final _passwordKey = GlobalKey();
  static final _loginButtonKey = GlobalKey();

  late TextEditingController _emailController;
  late LoginData _loginData;

  @override
  void initState() {
    super.initState();
    _loginData = context.read<LoginData>();
    _emailController = TextEditingController(text: _loginData.email);
    _loginData.addListener(_onLoginDataChanged);
  }

  @override
  void dispose() {
    _loginData.removeListener(_onLoginDataChanged);
    _emailController.dispose();
    super.dispose();
  }

  void _onLoginDataChanged() {
    if (_emailController.text != _loginData.email) {
      _emailController.text = _loginData.email;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loginData = context.watch<LoginData>();

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
                        "Login",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Showcase(
                        key: _emailKey,
                        title: 'Welcome!',
                        description: "Let's see if you remember your details.",
                        child: TextFormField(
                          controller: _emailController,
                          onChanged: (value) => loginData.setEmail(value),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: const TextStyle(color: Colors.white70),
                          errorText: loginData.emailErrorText,
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
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Showcase(
                        key: _passwordKey,
                        description: "Your password goes here.",
                        child: TextFormField(
                          obscureText: !loginData.isPasswordVisible,
                          onChanged: (value) => loginData.setPassword(value),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Password",
                          labelStyle: const TextStyle(color: Colors.white70),
                          errorText: loginData.passwordErrorText,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          suffixIcon: IconButton(
                            icon: Icon(
                              loginData.isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white70,
                            ),
                            onPressed: () =>
                                loginData.togglePasswordVisibility(),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white30),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Checkbox(
                            value: loginData.rememberMe,
                            onChanged: (value) {
                              loginData.setRememberMe(value ?? false);
                            },
                            checkColor: Colors.black,
                            activeColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                          ),
                          const Text(
                            "Remember me",
                            style: TextStyle(color: Colors.white),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/forgot_password');
                            },
                            child: const Text(
                              "Forgot password?",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: Showcase(
                          key: _loginButtonKey,
                          title: 'All Set?',
                          description:
                              'Tap here to log in and start your journey.',
                          child: BouncyButton(
                            onPressed: () async {
                              final String? error =
                                  await loginData.signIn(context);
                              if (context.mounted) {
                                if (error == null) {
                                  Navigator.pushNamed(context, '/home');
                                } else {
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(
                                      SnackBar(content: Text(error)));
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
                              child: const Text("Login"),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: Colors.white),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: const Text(
                              "Register",
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
        ],
      ),
    );
  }
}
