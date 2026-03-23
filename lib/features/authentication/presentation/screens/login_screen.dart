import 'package:flutter/material.dart';
import 'package:good_news/core/constants/theme_tokens.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:good_news/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:good_news/features/authentication/presentation/screens/registration_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'] ?? '',
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canLogin =>
      _emailController.text.trim().isNotEmpty &&
          _passwordController.text.isNotEmpty;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      if (response['token'] != null) {
        await PreferencesService.saveUserData(
          token: response['token'],
          userId: response['user_id'],
          name: 'User',
          email: _emailController.text.trim(),
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login successful!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        _showError(response['message'] ?? 'Invalid email or password');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Login failed. Please check your connection and try again.');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _googleSignInMethod() async {
    setState(() => _isGoogleLoading = true);

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        if (mounted) setState(() => _isGoogleLoading = false);
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      if (idToken == null) {
        if (!mounted) return;
        _showError('Google Sign-In failed. Please try again.');
        setState(() => _isGoogleLoading = false);
        return;
      }

      final result = await ApiService.googleMobileLogin(idToken);

      if (!mounted) return;

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
      if (!mounted) return;
      _showError('Google Sign-In failed: $e');
    }

    if (mounted) setState(() => _isGoogleLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  _buildLogo(isDark),
                  const SizedBox(height: 48),
                  _buildEmailField(isDark),
                  const SizedBox(height: 16),
                  _buildPasswordField(isDark),
                  const SizedBox(height: 24),
                  _buildLoginButton(),
                  const SizedBox(height: 16),
                  _buildDivider(isDark),
                  const SizedBox(height: 16),
                  _buildGoogleButton(isDark),
                  const SizedBox(height: 32),
                  _buildSignUpLink(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: ThemeTokens.primaryGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          'Joy Scroll',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
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

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData prefixIcon,
    String? errorText,
    Widget? suffixIcon,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: isDark ? Colors.white60 : Colors.grey,
      ),
      errorText: errorText,
      errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
      filled: true,
      fillColor: isDark ? Colors.white.withOpacity(0.07) : Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isDark ? Colors.white24 : Colors.grey.shade200,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: ThemeTokens.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: isDark ? Colors.white54 : Colors.grey,
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildEmailField(bool isDark) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
      ),
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
      decoration: _buildInputDecoration(
        label: 'Email',
        prefixIcon: Icons.email_outlined,
        errorText: _emailError,
        isDark: isDark,
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

  Widget _buildPasswordField(bool isDark) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
      ),
      onChanged: (value) {
        setState(() {
          _passwordError = value.isEmpty ? 'Password is required' : null;
        });
      },
      decoration: _buildInputDecoration(
        label: 'Password',
        prefixIcon: Icons.lock_outlined,
        errorText: _passwordError,
        isDark: isDark,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: isDark ? Colors.white54 : Colors.grey,
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
    final double fullWidth = MediaQuery.of(context).size.width;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _isLoading ? 56 : fullWidth,
      height: 56,
      child: ElevatedButton(
        onPressed:
        _canLogin && !_isLoading && !_isGoogleLoading ? _login : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeTokens.primaryGreen,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_isLoading ? 28 : 12),
          ),
          elevation: 2,
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

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey[500],
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed:
        _isLoading || _isGoogleLoading ? null : _googleSignInMethod,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white : Colors.black87,
          side: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor:
          isDark ? Colors.white.withOpacity(0.07) : Colors.white,
          elevation: 1,
          shadowColor: Colors.black12,
        ),
        child: _isGoogleLoading
            ? SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: ThemeTokens.primaryGreen,
            strokeWidth: 2,
          ),
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
            Text(
              'Sign in with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLink(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey[700],
            fontSize: 14,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: TextButton(
            onPressed: _navigateToRegister,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              "Sign Up",
              style: TextStyle(
                color: ThemeTokens.primaryGreen,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}