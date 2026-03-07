import 'package:flutter/material.dart';
import 'package:good_news/core/constants/theme_tokens.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:good_news/responsive_app.dart';
import 'package:good_news/features/authentication/presentation/screens/registration_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../onboarding/presentation/screens/onboarding_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  // Google Sign-In instance
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '293043554696-41f65f90a0opo0jq15ves6d2fhb1v2qe.apps.googleusercontent.com',
  );

  static const String _baseUrl = 'https://goodnewsapp.lemmecode.com/api/v1';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canLogin =>
      _emailController.text.trim().isNotEmpty &&
          _passwordController.text.isNotEmpty;

  // ── Email/Password Login ──────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (response['status'] == 'success') {
        if (response['token'] != null) {
          await PreferencesService.saveUserData(
            token: response['token'],
            userId: 0,
            name: 'User',
            email: _emailController.text.trim(),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ResponsiveApp()),
        );
      } else {
        _showError('Invalid email or password');
      }
    } catch (e) {
      _showError('Login failed. Please check your connection and try again.');
    }

    setState(() => _isLoading = false);
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  Future<void> _googleSignInMethod() async {
    setState(() => _isGoogleLoading = true);

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;

      // ✅ Debug prints
      print("ID TOKEN: ${auth.idToken}");
      print("ACCESS TOKEN: ${auth.accessToken}");

      final String? idToken = auth.idToken;

      if (idToken == null) {
        _showError('Google Sign-In failed. Please try again.');
        setState(() => _isGoogleLoading = false);
        return;
      }

      final result = await ApiService.googleMobileLogin(idToken);

      if (result['token'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-In successful!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        _showError(result['error'] ?? 'Google Sign-In failed.');
      }
    } catch (e) {
      _showError('Google Sign-In failed: $e');
    }

    setState(() => _isGoogleLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegistrationScreen()),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeTokens.darkBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 48),
                  _buildEmailField(),
                  const SizedBox(height: 16),
                  _buildPasswordField(),
                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 16),
                  _buildDivider(),
                  const SizedBox(height: 16),
                  _buildGoogleButton(),
                  const SizedBox(height: 32),
                  _buildSignUpLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: ThemeTokens.primaryGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          'Joy Scroll',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Welcome back!',
          style: TextStyle(
            color: ThemeTokens.primaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: Colors.white),
      onChanged: (value) {
        setState(() {
          if (value.trim().isEmpty) {
            _emailError = 'Email is required';
          } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
              .hasMatch(value)) {
            _emailError = 'Please enter a valid email';
          } else {
            _emailError = null;
          }
        });
      },
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: const TextStyle(color: ThemeTokens.textSecondary),
        errorText: _emailError,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        filled: true,
        fillColor: ThemeTokens.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        prefixIcon: const Icon(Icons.email_outlined,
            color: ThemeTokens.textSecondary),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your email';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: const TextStyle(color: Colors.white),
      onChanged: (value) {
        setState(() {
          _passwordError = value.isEmpty ? 'Password is required' : null;
        });
      },
      decoration: InputDecoration(
        labelText: 'Password',
        labelStyle: const TextStyle(color: ThemeTokens.textSecondary),
        errorText: _passwordError,
        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
        filled: true,
        fillColor: ThemeTokens.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        prefixIcon:
        const Icon(Icons.lock_outlined, color: ThemeTokens.textSecondary),
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: ThemeTokens.textSecondary,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter your password';
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isLoading ? 56 : double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _canLogin && !_isLoading && !_isGoogleLoading ? _login : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeTokens.primaryGreen,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_isLoading ? 28 : 12),
          ),
          elevation: 0,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2),
          )
              : const Text(
            'Login',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: ThemeTokens.textSecondary.withOpacity(0.3)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: ThemeTokens.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: ThemeTokens.textSecondary.withOpacity(0.3)),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _isLoading || _isGoogleLoading ? null : _googleSignInMethod,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: ThemeTokens.textSecondary.withOpacity(0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isGoogleLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/g-logo.png',
              width: 22,
              height: 22,
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Don't have an account? ",
          style: TextStyle(color: ThemeTokens.textSecondary, fontSize: 14),
        ),
        TextButton(
          onPressed: _navigateToRegister,
          child: const Text(
            "Sign Up",
            style: TextStyle(
              color: ThemeTokens.primaryGreen,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}