import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:good_news/core/utils/responsive_helper.dart';
import 'package:good_news/core/services/image_picker_service.dart';
import 'package:good_news/core/services/notification_service.dart';
import 'package:good_news/core/services/user_service.dart';
import 'package:good_news/features/profile/presentation/screens/blocked_users_screen.dart';
import 'package:good_news/features/profile/presentation/screens/my_posts_screen.dart';
import 'package:good_news/features/profile/presentation/screens/reading_history_screen.dart';
import 'package:good_news/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:good_news/features/profile/presentation/widgets/friends_section.dart';
import 'package:good_news/features/profile/presentation/widgets/quick_actions.dart';
import 'package:good_news/features/profile/presentation/widgets/user_activity.dart';
import 'package:good_news/features/profile/presentation/widgets/stats_row.dart';
import 'package:good_news/features/profile/presentation/widgets/menu_list.dart';
import 'package:good_news/core/services/social_api_service.dart';
import 'package:good_news/features/social/presentation/screens/friend_requests_screen.dart';
import 'package:good_news/features/settings/presentation/screens/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  File? _profileImage;
  double _scrollOffset = 0.0;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;
  bool _isLoading = true;

  int _articlesReadCount = 0;
  bool _isStatsLoading = true;

  List<Map<String, dynamic>> _friends = [];
  bool _isFriendsLoading = true;

  int _friendRequestsCount = 0;
  bool _isFriendRequestsLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addObserver(this);

    _loadUserData();
    _loadFriends();
    _loadFriendRequestsCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshProfileData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserData();
  }

  void refreshData() {
    _refreshProfileData();
  }

  Future<void> _refreshProfileData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUserData(),
      _loadFriends(),
      _loadFriendRequestsCount(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isFriendsLoading = true);
    try {
      final response = await SocialApiService.getFriends();
      if (response['status'] == 'success') {
        final data = response['data'] ?? [];
        if (mounted) {
          setState(() {
            _friends = (data as List)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
            _isFriendsLoading = false;
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to load friends');
      }
    } catch (e) {
      print('Error loading friends: $e');
      if (mounted) {
        setState(() => _isFriendsLoading = false);
      }
    }
  }

  Future<void> _loadFriendsSilently() async {
    try {
      final response = await SocialApiService.getFriends();
      if (response['status'] == 'success') {
        final data = response['data'] ?? [];
        if (mounted) {
          setState(() {
            _friends = (data as List)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          });
        }
      }
    } catch (e) {
      print('Error loading friends silently: $e');
    }
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await UserService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
        });
      }
      print('✅ Profile loaded: ${_userProfile?['display_name']}');
      await _loadStats();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _loadUserData,
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
    try {
      try {
        final stats = await UserService.getUserStats();
        if (stats != null) {
          if (mounted) {
            setState(() {
              _articlesReadCount = stats['articles_read'] ?? 0;
              _userStats = stats;
              _isStatsLoading = false;
            });
          }
          return;
        }
      } catch (e) {
        print('⚠️ getUserStats not available: $e');
      }

      final history = await UserService.getHistory();

      if (mounted) {
        setState(() {
          _articlesReadCount = history.length;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      print('❌ Error loading stats: $e');
      if (mounted) {
        setState(() {
          _articlesReadCount = 0;
          _isStatsLoading = false;
        });
      }
    }
  }

  Future<void> _loadFriendRequestsCount() async {
    setState(() => _isFriendRequestsLoading = true);
    try {
      final response = await SocialApiService.getFriendRequests();
      if (response['status'] == 'success') {
        final data = response['data'] ?? [];
        if (mounted) {
          setState(() {
            _friendRequestsCount = (data as List).length;
            _isFriendRequestsLoading = false;
          });
        }
      } else {
        throw Exception(response['error'] ?? 'Failed to load friend requests');
      }
    } catch (e) {
      print('Error loading friend requests count: $e');
      if (mounted) {
        setState(() {
          _friendRequestsCount = 0;
          _isFriendRequestsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _onScroll() {
    setState(() => _scrollOffset = _scrollController.offset);
  }

  Future<void> _editProfile() async {
    if (_userProfile == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          userProfile: _userProfile!,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadUserData();
    }
  }

  Widget _buildSectionCard({required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.25)
                : Colors.grey.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAnimatedProfileHeader() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(50),
        child: Center(
          child: CircularProgressIndicator.adaptive(),
        ),
      );
    }

    final displayName = _userProfile?['display_name'] ?? 'Good News Reader';
    final email = _userProfile?['email'] ?? 'No email available';

    final scale = (1.0 - (_scrollOffset / 200)).clamp(0.8, 1.0);
    final opacity = (1.0 - (_scrollOffset / 100)).clamp(0.3, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(scale),
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    backgroundImage:
                    _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
                        ? Text(
                      displayName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 40,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                        : null,
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _editProfile,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticlesReadCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.colorScheme.primary;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: () async {
        try {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ReadingHistoryScreen(),
            ),
          );
          if (mounted) await _loadStats();
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open Reading History: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.25)
                  : Colors.grey.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor.withOpacity(0.2),
                    primaryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.article_outlined,
                color: primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Articles Read',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: textColor.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_articlesReadCount',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: primaryColor.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
      );
    });

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 26),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfileData,
        color: Theme.of(context).colorScheme.primary,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: ResponsiveHelper.getResponsivePadding(context).copyWith(
            bottom: 80,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnimatedProfileHeader(),
              const SizedBox(height: 28),

              if (_isStatsLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator.adaptive(),
                  ),
                )
              else
                _buildArticlesReadCard(),
              const SizedBox(height: 28),

              _buildSectionCard(
                child: QuickActionsWidget(
                  onMyPostsTap: () => _showMyPosts(context),
                  onFriendRequestsTap: () => _showFriendRequests(context),
                  onSettingsTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  ),
                  friendRequestsCount: _friendRequestsCount,
                ),
              ),

              const SizedBox(height: 28),

              _buildSectionCard(
                child: FriendsSectionWidget(
                  friends: _friends,
                  isLoading: _isFriendsLoading,
                  onFriendsUpdated: _loadFriendsSilently,
                ),
              ),

              const SizedBox(height: 28),

              MenuList(
                items: [
                  MenuItem(
                    title: 'Reading History',
                    icon: Icons.history,
                    onTap: () async {
                      try {
                        print('🔍 PROFILE: Opening Reading History...');

                        final result = await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ReadingHistoryScreen(),
                          ),
                        );

                        print('🔍 PROFILE: ReadingHistoryScreen returned: $result');

                        if (mounted) {
                          await _loadStats();
                        }

                        if (result != null &&
                            result is Map &&
                            result['action'] == 'read_article') {
                          print(
                              '🔍 PROFILE: Detected "Read Again" action for article ${result['article_id']}');
                          print(
                              '🔍 PROFILE: Passing result back to HomeScreen and closing ProfileScreen');

                          Navigator.of(context).pop(result);
                          return;
                        }

                        print('🔍 PROFILE: No "Read Again" action, staying on ProfileScreen');
                      } catch (e) {
                        print('❌ PROFILE: Error in Reading History: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not open Reading History: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  MenuItem(
                    title: 'Settings',
                    icon: Icons.settings_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    ),
                  ),
                  MenuItem(
                    title: 'Blocked Users',
                    icon: Icons.block,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const BlockedUsersScreen(),
                        ),
                      );
                    },
                  ),
                  MenuItem(
                    title: 'About',
                    icon: Icons.info_outline,
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showMyPosts(BuildContext context) {
    final userId = _userProfile?['id'];
    if (userId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MyPostsScreen(userId: userId),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User ID not available')),
      );
    }
  }

  void _showFriendRequests(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FriendRequestsScreen()),
    );

    if (result == true && mounted) {
      print('🔄 Friend requests screen returned with changes, refreshing...');
      await Future.wait([
        _loadFriendRequestsCount(),
        _loadFriends(),
      ]);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Joy Scroll App',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFF68BB59),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 32),
      ),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'Bringing you positive, AI-powered news stories that brighten your day.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}