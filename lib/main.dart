import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:good_news/responsive_app.dart';
import 'package:good_news/features/authentication/presentation/screens/login_screen.dart';
import 'package:good_news/features/onboarding/presentation/screens/choose_topics_screen.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:good_news/core/services/theme_service.dart';
import 'package:good_news/core/themes/app_theme.dart';
import 'features/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const GoodNewsApp());
}

class GoodNewsApp extends StatefulWidget {
  const GoodNewsApp({Key? key}) : super(key: key);

  @override
  State<GoodNewsApp> createState() => _GoodNewsAppState();
}

class _GoodNewsAppState extends State<GoodNewsApp> {
  late ThemeService _themeService;
  bool _isConnected = true;
  late StreamSubscription _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    _themeService.loadPreferences();

    // ✅ App start होताना internet check
    _checkInitialConnectivity();

    // ✅ Real-time listener
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      if (mounted) {
        setState(() {
          _isConnected = !result.contains(ConnectivityResult.none);
        });
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _themeService,
      builder: (context, child) {
        ThemeData lightTheme;
        ThemeData darkTheme;

        if (_themeService.themeType == AppThemeType.green) {
          lightTheme = AppTheme.greenLightTheme;
          darkTheme = AppTheme.greenDarkTheme;
        } else {
          lightTheme = AppTheme.pinkLightTheme;
          darkTheme = AppTheme.pinkDarkTheme;
        }

        return MaterialApp(
          title: 'JoyScroll',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: _themeService.themeMode,
          home: _SplashWrapper(themeService: _themeService),
          debugShowCheckedModeBanner: false,

          // ✅ Global Overlay - सगळ्या screens वर काम करेल
          builder: (context, child) {
            return _ConnectivityWrapper(
              isConnected: _isConnected,
              themeService: _themeService,
              child: child!,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ✅ Connectivity Wrapper - सगळ्या Tabs वर काम करतो
// ─────────────────────────────────────────────
class _ConnectivityWrapper extends StatefulWidget {
  final bool isConnected;
  final ThemeService themeService;
  final Widget child;

  const _ConnectivityWrapper({
    required this.isConnected,
    required this.themeService,
    required this.child,
  });

  @override
  State<_ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<_ConnectivityWrapper> {
  bool _isChecking = false;

  Future<void> _retry() async {
    setState(() => _isChecking = true);
    await Future.delayed(const Duration(seconds: 1));
    await Connectivity().checkConnectivity();
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeService.isDarkMode;
    final isGreen = widget.themeService.themeType == AppThemeType.green;
    final primaryColor = isGreen
        ? const Color(0xFF4CAF50)
        : AppTheme.accentPink;

    return Stack(
      children: [
        // ✅ Normal App - background मध्ये नेहमी असेल
        widget.child,

        // ✅ Internet नसेल तर overlay येईल
        if (!widget.isConnected)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: widget.isConnected ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Material(
                color: isDark
                    ? const Color(0xFF1A1A1A)
                    : Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // ✅ Icon
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 80,
                          color: isDark
                              ? Colors.white38
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 24),

                        // ✅ Title
                        Text(
                          'No Internet Connection',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // ✅ Subtitle
                        Text(
                          'Please check your connection\nand try again',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ✅ Try Again Button
                        ElevatedButton.icon(
                          onPressed: _isChecking ? null : _retry,
                          icon: _isChecking
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.refresh_rounded),
                          label: Text(
                            _isChecking ? 'Checking...' : 'Try Again',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// ✅ Splash Wrapper
// ─────────────────────────────────────────────
class _SplashWrapper extends StatelessWidget {
  final ThemeService themeService;

  const _SplashWrapper({required this.themeService});

  @override
  Widget build(BuildContext context) {
    final bgColor = themeService.isDarkMode
        ? const Color(0xFF1A1A1A)
        : Colors.white;

    final progressColor = themeService.themeType == AppThemeType.green
        ? const Color(0xFF4CAF50)
        : AppTheme.accentPink;

    return FutureBuilder<Widget>(
      future: _determineInitialScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SplashScreen(
            nextScreen: const LoginScreen(),
            backgroundColor: bgColor,
            accentColor: progressColor,
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: themeService.isDarkMode
                ? Colors.black
                : Colors.white,
            body: const Center(
              child: Text("Error loading app"),
            ),
          );
        }

        return SplashScreen(
          nextScreen: snapshot.data ?? const LoginScreen(),
          backgroundColor: bgColor,
          accentColor: progressColor,
        );
      },
    );
  }

  Future<Widget> _determineInitialScreen() async {
    try {
      final isLoggedIn = await PreferencesService.isLoggedIn();
      if (!isLoggedIn) return const LoginScreen();

      final hasCompletedOnboarding =
      await PreferencesService.isOnboardingCompleted();
      if (!hasCompletedOnboarding) return const ChooseTopicsScreen();

      return const ResponsiveApp();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("🔥 Initial Screen Error: $e");
      }
      return const LoginScreen();
    }
  }
}
