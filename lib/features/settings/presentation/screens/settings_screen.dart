import 'package:flutter/material.dart';

import 'package:good_news/core/services/theme_service.dart';
import 'package:good_news/core/services/notification_service.dart';
import 'package:good_news/core/services/app_info_service.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:good_news/features/authentication/presentation/screens/login_screen.dart';
import 'package:good_news/core/themes/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

import 'PrivacyPolicyScreen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late ThemeService _themeService;
  // bool _notificationsEnabled = true;
  // bool _dailyDigest = true;
  String _appVersion = 'Loading...';

  @override
  void initState() {
    super.initState();
    _themeService = ThemeService();
    // Load saved preferences (including theme mode)
    _themeService.loadPreferences();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final version = await AppInfoService.getAppVersion();
    if (mounted) {
      setState(() {
        _appVersion = version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionHeaderColor = isDark
        ? Theme.of(context).colorScheme.primary.withOpacity(0.9)
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance', sectionHeaderColor),
          Card(
            child: Column(
              children: [
                // ONLY LIGHT MODE TOGGLE (THEME COLOR OPTION COMMENTED OUT)

                /*
                // Theme Color Picker
                ListenableBuilder(
                  listenable: _themeService,
                  builder: (context, child) {
                    return ListTile(
                      leading: Icon(
                        Icons.palette,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      title: const Text('Theme Color'),
                      subtitle: Text(
                        _themeService.themeType == AppThemeType.green
                            ? 'Green (Default)'
                            : 'Pink',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _themeService.themeType == AppThemeType.green
                                  ? AppTheme.accentGreen
                                  : AppTheme.accentPink,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                      onTap: () {
                        _showThemeColorDialog();
                      },
                    );
                  },
                ),
                const Divider(height: 1),
                */

                // Light Mode Toggle (Default = ON)
                ListenableBuilder(
                  listenable: _themeService,
                  builder: (context, child) {
                    return SwitchListTile(
                      title: const Text('Light Mode'),
                      subtitle: const Text('Light mode is default, toggle for dark theme'),
                      value: !_themeService.isDarkMode,
                      onChanged: (value) {
                        _themeService.setThemeMode(
                          value ? ThemeMode.light : ThemeMode.dark,
                        );
                        NotificationService.showSuccess(
                          value ? 'Light mode enabled' : 'Dark mode enabled',
                        );
                      },
                      secondary: Icon(
                        _themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Personalization Section
          _buildSectionHeader('Personalization', sectionHeaderColor),
          Card(
            child: ListTile(
              leading: Icon(
                Icons.category,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Manage Categories'),
              subtitle: const Text('Choose your preferred news topics'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                _showCategoriesDialog();
              },
            ),
          ),

          const SizedBox(height: 16),

          // Data & Privacy Section
          _buildSectionHeader('Data & Privacy', sectionHeaderColor),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Account Section
          _buildSectionHeader('Account', sectionHeaderColor),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              subtitle: const Text('Sign out of your account'),
              trailing: const Icon(Icons.chevron_right, color: Colors.red),
              onTap: () {
                _showLogoutDialog();
              },
            ),
          ),

          const SizedBox(height: 16),

          // About Section
          _buildSectionHeader('About', sectionHeaderColor),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
                  title: const Text('App Version'),
                  subtitle: Text('Version $_appVersion'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.rate_review, color: Theme.of(context).colorScheme.primary),
                  title: const Text('Rate App'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final url = Uri.parse(
                      'https://play.google.com/store/apps/details?id=com.joyscroll.app',
                    );
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Thank you for your feedback!')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // COMMENTED OUT BUT STILL AVAILABLE FOR FUTURE USE
  void _showThemeColorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Theme Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<AppThemeType>(
                title: const Text('Green'),
                subtitle: const Text('Fresh and strategic'),
                value: AppThemeType.green,
                groupValue: _themeService.themeType,
                onChanged: (value) {
                  if (value != null) {
                    _themeService.setThemeType(value);
                    Navigator.of(context).pop();
                    NotificationService.showSuccess('Green theme applied');
                  }
                },
                secondary: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              RadioListTile<AppThemeType>(
                title: const Text('Pink'),
                subtitle: const Text('Vibrant and energetic'),
                value: AppThemeType.pink,
                groupValue: _themeService.themeType,
                onChanged: (value) {
                  if (value != null) {
                    _themeService.setThemeType(value);
                    Navigator.of(context).pop();
                    NotificationService.showSuccess('Pink theme applied');
                  }
                },
                secondary: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentPink,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCategoriesDialog() async {
    try {
      final categoriesResponse = await ApiService.getCategories();

      List<Map<String, dynamic>> categories = [];
      Set<int> selectedCategories = {};

      if (categoriesResponse['categories'] != null) {
        categories = List<Map<String, dynamic>>.from(categoriesResponse['categories']);
      }

      final savedCategories = await PreferencesService.getSelectedCategories();
      selectedCategories = Set<int>.from(savedCategories);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Choose Categories'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Select at least 3 categories to personalize your feed:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            final categoryId = category['id'] as int;
                            final isSelected = selectedCategories.contains(categoryId);

                            return CheckboxListTile(
                              title: Text(category['name']),
                              subtitle: category['description'] != null
                                  ? Text(category['description'], style: const TextStyle(fontSize: 12))
                                  : null,
                              value: isSelected,
                              onChanged: (bool? value) {
                                setDialogState(() {
                                  if (value == true) {
                                    selectedCategories.add(categoryId);
                                  } else {
                                    selectedCategories.remove(categoryId);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${selectedCategories.length} selected (minimum 3)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selectedCategories.length >= 3 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: selectedCategories.length >= 3
                        ? () async {
                      Navigator.of(context).pop();
                      await _saveCategories(selectedCategories.toList());
                    }
                        : null,
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveCategories(List<int> categoryIds) async {
    try {
      await PreferencesService.saveSelectedCategories(categoryIds);

      try {
        final token = await PreferencesService.getToken();
        if (token !=null && token.isNotEmpty) {
          await ApiService.saveUserPreferencesAuth(categoryIds, token);
        }
      } catch (_) {}

      if (mounted) {
        NotificationService.showSuccess('Categories updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _logout();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    try {
      await PreferencesService.clearToken();
      await PreferencesService.clearUserData();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
        );

        NotificationService.showSuccess('Logged out successfully');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}