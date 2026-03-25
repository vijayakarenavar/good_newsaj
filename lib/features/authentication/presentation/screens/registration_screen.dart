import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/constants/theme_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isTermsAccepted = false;

  String? _displayNameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _canRegister =>
      _displayNameController.text.trim().isNotEmpty &&
          _phoneController.text.trim().isNotEmpty &&
          _emailController.text.trim().isNotEmpty &&
          _passwordController.text.isNotEmpty &&
          _confirmPasswordController.text.isNotEmpty &&
          _displayNameError == null &&
          _phoneError == null &&
          _emailError == null &&
          _passwordError == null &&
          _confirmPasswordError == null &&
          _isTermsAccepted;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.register(
        _displayNameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
        _phoneController.text.trim(),
      );

      if (!mounted) return;

      if (response['token'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ??
                  'Registration successful! Please login with your credentials.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      } else {
        _showError(
          response['message'] ?? response['error'] ?? 'Registration failed',
          isNetwork: false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      final errorStr = e.toString();

      if (errorStr.contains('SocketException') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('connection error') ||
          errorStr.contains('DioException') ||
          errorStr.contains('DioError') ||
          errorStr.contains('NetworkException')) {
        _showError(
          'No internet connection. Please check your network and try again.',
          isNetwork: true,
        );
      } else if (errorStr.contains('TimeoutException') ||
          errorStr.contains('timeout')) {
        _showError(
          'Request timed out. Please try again.',
          isNetwork: true,
        );
      } else {
        _showError(
          'Registration failed. Please try again.',
          isNetwork: false,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message, {bool isNetwork = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isNetwork ? Icons.wifi_off : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  48 -
                  kToolbarHeight,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(isDark),
                  const SizedBox(height: 32),
                  _buildDisplayNameField(isDark),
                  const SizedBox(height: 16),
                  _buildPhoneField(isDark),
                  const SizedBox(height: 16),
                  _buildEmailField(isDark),
                  const SizedBox(height: 16),
                  _buildPasswordField(isDark),
                  const SizedBox(height: 16),
                  _buildConfirmPasswordField(isDark),
                  const SizedBox(height: 16),
                  _buildTermsCheckbox(isDark),
                  const SizedBox(height: 24),
                  _buildRegisterButton(),
                  const SizedBox(height: 16),
                  _buildLoginLink(isDark),
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
          'Create your account',
          style: TextStyle(
            color: ThemeTokens.primaryGreen,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDisplayNameField(bool isDark) {
    return TextFormField(
      controller: _displayNameController,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      onChanged: (value) {
        setState(() {
          if (value.trim().isEmpty) {
            _displayNameError = 'Display name is required';
          } else if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
            _displayNameError = 'Only letters and spaces are allowed';
          } else if (value.trim().length < 2) {
            _displayNameError = 'Display name must be at least 2 characters';
          } else {
            _displayNameError = null;
          }
        });
      },
      decoration: _buildInputDecoration(
        label: 'Name',
        prefixIcon: Icons.person_outlined,
        errorText: _displayNameError,
        isDark: isDark,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your display name';
        }
        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
          return 'Only letters and spaces are allowed';
        }
        if (value.trim().length < 2) {
          return 'Display name must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildPhoneField(bool isDark) {
    return TextFormField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      onChanged: (value) {
        setState(() {
          if (value.trim().isEmpty) {
            _phoneError = 'Phone number is required';
          } else if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
            _phoneError = 'Phone must start with 6-9 and be 10 digits';
          } else {
            _phoneError = null;
          }
        });
      },
      decoration: _buildInputDecoration(
        label: 'Phone Number',
        prefixIcon: Icons.phone_outlined,
        errorText: _phoneError,
        isDark: isDark,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter your phone number';
        }
        if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(value)) {
          return 'Phone must start with 6-9 and be 10 digits';
        }
        return null;
      },
    );
  }

  Widget _buildEmailField(bool isDark) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      onChanged: (value) {
        setState(() {
          final email = value.trim().toLowerCase();
          if (value.trim().isEmpty) {
            _emailError = 'Email is required';
          } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$')
              .hasMatch(email)) {
            _emailError = 'Only @gmail.com emails are allowed';
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
        final email = value.trim().toLowerCase();
        if (!RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$').hasMatch(email)) {
          return 'Only @gmail.com emails are allowed';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField(bool isDark) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      onChanged: (value) {
        setState(() {
          if (value.isEmpty) {
            _passwordError = 'Password is required';
          } else if (value.length < 6) {
            _passwordError = 'Password must be at least 6 characters';
          } else {
            _passwordError = null;
          }
          if (_confirmPasswordController.text.isNotEmpty) {
            _confirmPasswordError =
            _confirmPasswordController.text != value
                ? 'Passwords do not match'
                : null;
          }
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
        if (value == null || value.isEmpty) return 'Please enter a password';
        if (value.length < 6) {
          return 'Password must be at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _buildConfirmPasswordField(bool isDark) {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      onChanged: (value) {
        setState(() {
          if (value.isEmpty) {
            _confirmPasswordError = 'Please confirm your password';
          } else if (value != _passwordController.text) {
            _confirmPasswordError = 'Passwords do not match';
          } else {
            _confirmPasswordError = null;
          }
        });
      },
      decoration: _buildInputDecoration(
        label: 'Confirm Password',
        prefixIcon: Icons.lock_outlined,
        errorText: _confirmPasswordError,
        isDark: isDark,
        suffixIcon: IconButton(
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please confirm your password';
        }
        if (value != _passwordController.text) {
          return 'Passwords do not match';
        }
        return null;
      },
    );
  }

  Widget _buildTermsCheckbox(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(
          left: 4.0, right: 8.0, top: 6.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _isTermsAccepted,
            onChanged: (value) {
              setState(() => _isTermsAccepted = value ?? false);
            },
            activeColor: ThemeTokens.primaryGreen,
            checkColor: Colors.white,
            side: BorderSide(
              color: isDark ? Colors.white38 : Colors.grey,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'I agree to the ',
                style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.grey,
                  fontSize: 13,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: ThemeTokens.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _openUrl(
                          'https://goodnewsapp.lemmecode.com/legal/terms'),
                  ),
                  TextSpan(
                    text: ' and ',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey,
                    ),
                  ),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: ThemeTokens.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => _openUrl(
                          'https://goodnewsapp.lemmecode.com/legal/privacy'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _isLoading ? 56 : maxWidth,
          height: 56,
          child: ElevatedButton(
            onPressed: _canRegister && !_isLoading ? _register : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeTokens.primaryGreen,
              foregroundColor: Colors.white,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius:
                BorderRadius.circular(_isLoading ? 28 : 12),
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
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                'Register',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoginLink(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(
            color: isDark ? Colors.white60 : Colors.grey[700],
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Login',
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