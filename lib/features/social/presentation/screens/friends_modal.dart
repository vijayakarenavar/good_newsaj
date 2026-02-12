import 'package:flutter/material.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/constants/theme_tokens.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:permission_handler/permission_handler.dart';

class FriendsModal extends StatefulWidget {
  const FriendsModal({super.key});

  @override
  State<FriendsModal> createState() => _FriendsModalState();
}

class _FriendsModalState extends State<FriendsModal> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _showExplanation = true;
  bool _permissionGranted = false;
  bool _permissionDenied = false;
  bool _permissionPermanentlyDenied = false;
  List<Map<String, dynamic>> _friendSuggestions = [];
  Set<int> _addedFriends = {};

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _requestPermission() async {
    setState(() {
      _showExplanation = false;
      _isLoading = true;
    });

    try {
      print('📱 FRIENDS: Requesting contact permission...');

      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.contacts.status;
        print('📱 FRIENDS: Current permission status: $status');

        if (status.isDenied) {
          final results = await Permission.contacts.request();
          status = results;
          print('📱 FRIENDS: Permission request result: $status');
        }

        if (status.isGranted) {
          print('✅ FRIENDS: Contact permission granted');
          await _loadContactsAndSuggestFriends();
        } else if (status.isPermanentlyDenied) {
          print('❌ FRIENDS: Contact permission permanently denied');
          setState(() {
            _isLoading = false;
            _permissionPermanentlyDenied = true;
          });
        } else {
          print('❌ FRIENDS: Contact permission denied');
          setState(() {
            _isLoading = false;
            _permissionDenied = true;
          });
        }
      } else {
        print('🌐 FRIENDS: Running on web. Contact permission not available.');
        setState(() {
          _isLoading = false;
          _permissionGranted = true;
          _friendSuggestions = [];
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact access is not available on web. Please use the mobile app to add friends via contacts.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ FRIENDS: Permission request failed: $e');
      setState(() {
        _isLoading = false;
        _permissionDenied = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permission error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadContactsAndSuggestFriends() async {
    try {
      final contacts = <dynamic>[];
      final phoneNumbers = <String>[];

      print('📞 FRIENDS: Processing ${phoneNumbers.length} real contacts');

      const salt = 'good_news_app_salt_2024';
      final hashedContacts = phoneNumbers.map((phone) {
        final combined = phone + salt;
        return sha256.convert(utf8.encode(combined)).toString();
      }).toList();

      print('🔐 FRIENDS: Hashed ${hashedContacts.length} phone numbers');

      final response = await ApiService.postContactsSuggest(hashedContacts);

      if (response['status'] == 'success') {
        setState(() {
          _permissionGranted = true;
          _friendSuggestions = List<Map<String, dynamic>>.from(response['suggestions'] ?? []);
          _isLoading = false;
        });
        print('✅ FRIENDS: Found ${_friendSuggestions.length} friend suggestions');
      } else {
        throw Exception('API returned error: ${response['error']}');
      }
    } catch (e) {
      print('❌ FRIENDS: Failed to load friend suggestions: $e');
      setState(() {
        _isLoading = false;
        _permissionGranted = true;
        _friendSuggestions = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load suggestions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSearchDialog() {
    showSearch<String>(
      context: context,
      delegate: FriendSearchDelegate(
        onSearch: _searchFriendsFromApi,
        onAddFriend: _addFriendFromSearch,
        addedFriends: _addedFriends,
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _searchFriendsFromApi(String query) async {
    if (query.isEmpty) return [];
    try {
      print('🔍 FRIENDS: Searching for: "$query"');
      final response = await ApiService.searchFriends(query);

      print('📡 FRIENDS: Search response status: ${response['status']}');
      print('📊 FRIENDS: Search response data: ${response['data']}');

      if (response['status'] == 'success') {
        final data = response['data'] ?? [];
        final results = List<Map<String, dynamic>>.from(data);
        print('✅ FRIENDS: Found ${results.length} users');
        return results;
      } else {
        throw Exception(response['error'] ?? 'Search failed');
      }
    } catch (e) {
      print('❌ FRIENDS: Search failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return [];
    }
  }

  Future<void> _addFriendFromSearch(Map<String, dynamic> friend) async {
    try {
      final userId = friend['id'] as int;

      if (_addedFriends.contains(userId)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Friend request already sent!'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      print('📤 FRIENDS: Sending friend request to user $userId');
      final response = await ApiService.sendFriendRequest(userId);
      print('📬 FRIENDS: Friend request response: ${response['status']}');

      if (response['status'] == 'success') {
        setState(() {
          _addedFriends.add(userId);
        });

        final displayName = friend['display_name'];
        final userName = (displayName != null && displayName.toString().trim().isNotEmpty)
            ? displayName.toString()
            : 'User #$userId';

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to $userName!'),
              backgroundColor: ThemeTokens.primaryGreen,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to send request');
      }
    } catch (e) {
      print('❌ FRIENDS: Failed to send friend request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send request: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // ✅ Header with gradient
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
                      : [Colors.white, Colors.grey.shade50],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Close button with hover effect
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Add Friends',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Search button with hover effect
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showSearchDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: ThemeTokens.primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.search_rounded,
                          color: ThemeTokens.primaryGreen,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildContent(theme, isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    if (_showExplanation) return _buildExplanationScreen(theme, isDark);
    if (_isLoading) return _buildLoadingScreen(theme, isDark);
    if (_permissionDenied) return _buildPermissionDeniedScreen(theme, isDark);
    if (_permissionPermanentlyDenied) return _buildPermissionPermanentlyDeniedScreen(theme, isDark);
    if (_permissionGranted) return _buildFriendsList(theme, isDark);
    return _buildExplanationScreen(theme, isDark);
  }

  Widget _buildExplanationScreen(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✅ Animated gradient icon
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 800),
            builder: (context, double value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeTokens.primaryGreen,
                        ThemeTokens.primaryGreen.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeTokens.primaryGreen.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.people_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Find Your Friends',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 26,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Grant access to your contacts to find friends on Good News. We only use phone numbers to match and never upload contacts without consent.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.6,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          // ✅ Gradient button with shadow
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _requestPermission,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeTokens.primaryGreen,
                      ThemeTokens.primaryGreen.withOpacity(0.8),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeTokens.primaryGreen.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Add Friends',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Skip for now',
              style: TextStyle(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ThemeTokens.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(ThemeTokens.primaryGreen),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Finding your friends...',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedScreen(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.contacts_outlined,
              size: 72,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Access Denied',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'We need access to your contacts to help you find friends who are using Good News App.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _requestPermission,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeTokens.primaryGreen,
                      ThemeTokens.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeTokens.primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildPermissionPermanentlyDeniedScreen(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.settings_rounded,
              size: 72,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Permission Required',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'To find your friends, please enable contacts access in your device settings.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                try {
                  await openAppSettings();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not open settings: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ThemeTokens.primaryGreen,
                      ThemeTokens.primaryGreen.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeTokens.primaryGreen.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Open Settings',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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

  Widget _buildFriendsList(ThemeData theme, bool isDark) {
    if (_friendSuggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline_rounded,
                size: 72,
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No friends found',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'None of your contacts are using Good News App yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: ThemeTokens.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_friendSuggestions.length} friends found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: ThemeTokens.primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _friendSuggestions.length,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final friend = _friendSuggestions[index];
              final userId = friend['id'] as int;
              final isAdded = _addedFriends.contains(userId);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ThemeTokens.primaryGreen,
                          ThemeTokens.primaryGreen.withOpacity(0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                      child: Text(
                        friend['name'][0].toUpperCase(),
                        style: TextStyle(
                          color: ThemeTokens.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    friend['name'],
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    friend['phone'],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                  trailing: isAdded
                      ? Icon(Icons.check_circle_rounded, color: ThemeTokens.primaryGreen, size: 28)
                      : Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _addFriend(friend),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              ThemeTokens.primaryGreen,
                              ThemeTokens.primaryGreen.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: ThemeTokens.primaryGreen.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Add',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _addFriend(Map<String, dynamic> friend) async {
    try {
      final response = await ApiService.addFriend(friend['id']);

      if (response['status'] == 'success') {
        setState(() {
          _addedFriends.add(friend['id'] as int);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${friend['name']}!'),
              backgroundColor: ThemeTokens.primaryGreen,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );

          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to add friend');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add friend: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ============= ENHANCED SEARCH DELEGATE =============

class FriendSearchDelegate extends SearchDelegate<String> {
  final Future<List<Map<String, dynamic>>> Function(String) onSearch;
  final Function(Map<String, dynamic>) onAddFriend;
  final Set<int> addedFriends;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  FriendSearchDelegate({
    required this.onSearch,
    required this.onAddFriend,
    required this.addedFriends,
  });

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: isDark ? Colors.grey.shade600 : Colors.grey.shade400),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  String get searchFieldLabel => 'Search by name or email';

  @override
  List<Widget>? buildActions(BuildContext context) {
    final theme = Theme.of(context);
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () {
            query = '';
            _searchResults = [];
            _hasSearched = false;
            _isLoading = false;
            showSuggestions(context);
          },
        ),
      IconButton(
        icon: Icon(Icons.search_rounded, color: ThemeTokens.primaryGreen),
        onPressed: () {
          if (query.trim().isNotEmpty) {
            _performSearch(context);
          }
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, ''),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults(context);
  }

  void _performSearch(BuildContext context) async {
    final q = query.trim();
    if (q.isEmpty) return;

    _isLoading = true;
    _hasSearched = false;

    showResults(context);

    try {
      print('🔍 Searching for "$q"...');
      final results = await onSearch(q);
      _searchResults = results;
      print('✅ Search completed with ${results.length} results');

      final originalQuery = query;
      query = '';
      await Future.delayed(Duration.zero);
      query = originalQuery;

      _isLoading = false;
      _hasSearched = true;

      showResults(context);
    } catch (e) {
      print('❌ Search error: $e');
      _searchResults = [];
      _isLoading = false;
      _hasSearched = true;
      showResults(context);
    }
  }

  Widget _buildSearchResults(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ThemeTokens.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  size: 64,
                  color: ThemeTokens.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Search for friends',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Enter a name or email, then tap the search icon',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ThemeTokens.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                color: ThemeTokens.primaryGreen,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Searching...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasSearched && _searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No users found',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Try a different name or email',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final friend = _searchResults[index];
        final userId = friend['id'] as int;
        final isAdded = addedFriends.contains(userId);

        final displayName = friend['display_name'];
        final name = (displayName != null && displayName.toString().trim().isNotEmpty)
            ? displayName.toString()
            : 'User #$userId';

        final initial = name.startsWith('User #') ? 'U' : name[0].toUpperCase();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    ThemeTokens.primaryGreen,
                    ThemeTokens.primaryGreen.withOpacity(0.7),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                child: Text(
                  initial,
                  style: TextStyle(
                    color: ThemeTokens.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            title: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              friend['email']?.toString() ?? 'ID: $userId',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
            trailing: isAdded
                ? Icon(Icons.check_circle_rounded, color: ThemeTokens.primaryGreen, size: 28)
                : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async => await onAddFriend(friend),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeTokens.primaryGreen,
                        ThemeTokens.primaryGreen.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: ThemeTokens.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Send Request',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}