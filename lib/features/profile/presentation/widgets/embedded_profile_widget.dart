import 'package:flutter/material.dart';
import 'package:good_news/core/services/user_service.dart';
import 'package:good_news/core/services/social_api_service.dart';
import 'package:good_news/features/profile/presentation/screens/blocked_users_screen.dart';
import 'package:good_news/features/profile/presentation/screens/my_posts_screen.dart';
import 'package:good_news/features/profile/presentation/screens/reading_history_screen.dart';
import 'package:good_news/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:good_news/features/profile/presentation/widgets/friends_section.dart';
import 'package:good_news/features/profile/presentation/widgets/quick_actions.dart';
import 'package:good_news/features/profile/presentation/widgets/stats_row.dart';
import 'package:good_news/features/profile/presentation/widgets/menu_list.dart';
import 'package:good_news/features/social/presentation/screens/friend_requests_screen.dart';
import 'package:good_news/features/settings/presentation/screens/settings_screen.dart';

class EmbeddedProfileWidget extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>?>? onReadingHistoryAction;

  const EmbeddedProfileWidget({
    Key? key,
    this.onReadingHistoryAction,
  }) : super(key: key);

  @override
  State<EmbeddedProfileWidget> createState() => EmbeddedProfileWidgetState();
}

class EmbeddedProfileWidgetState extends State<EmbeddedProfileWidget> {
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
    _loadUserData();
    _loadFriends();
    _loadFriendRequestsCount();
  }

  Future<void> refreshData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUserData(),
      _loadFriends(),
      _loadFriendRequestsCount(),
    ]);
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await UserService.getUserProfile();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
        });
      }
      await _loadStats();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile'),
            backgroundColor: Colors.red,
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
        if (stats != null && mounted) {
          setState(() {
            _articlesReadCount = stats['articles_read'] ?? 0;
            _userStats = stats;
            _isStatsLoading = false;
          });
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
      if (mounted) {
        setState(() {
          _articlesReadCount = 0;
          _isStatsLoading = false;
        });
      }
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _isFriendsLoading = true);
    try {
      final response = await SocialApiService.getFriends();
      if (response['status'] == 'success' && mounted) {
        final data = response['data'] ?? [];
        setState(() {
          _friends = (data as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _isFriendsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFriendsLoading = false);
    }
  }

  Future<void> _loadFriendRequestsCount() async {
    setState(() => _isFriendRequestsLoading = true);
    try {
      final response = await SocialApiService.getFriendRequests();
      if (response['status'] == 'success' && mounted) {
        final data = response['data'] ?? [];
        setState(() {
          _friendRequestsCount = (data as List).length;
          _isFriendRequestsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _friendRequestsCount = 0;
          _isFriendRequestsLoading = false;
        });
      }
    }
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

  void _showMyPosts(BuildContext context) {
    final userId = _userProfile?['id'];
    if (userId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MyPostsScreen(userId: userId),
        ),
      );
    }
  }

  void _showFriendRequests(BuildContext context) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const FriendRequestsScreen()),
    );

    if (result == true && mounted) {
      await Future.wait([
        _loadFriendRequestsCount(),
        _loadFriends(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    final displayName = _userProfile?['display_name'] ?? 'Good News Reader';
    final email = _userProfile?['email'] ?? 'No email available';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
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
                      backgroundColor: primaryColor.withOpacity(0.15),
                      child: Text(
                        displayName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 40,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: _editProfile,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
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
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 28)),

        // Articles Read Card
        SliverToBoxAdapter(
          child: _buildArticlesReadCard(primaryColor, isDark, theme),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // Quick Actions
        SliverToBoxAdapter(
          child: _buildSectionCard(
            context,
            child: QuickActionsWidget(
              onMyPostsTap: () => _showMyPosts(context),
              onFriendRequestsTap: () => _showFriendRequests(context),
              onSettingsTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
              friendRequestsCount: _friendRequestsCount,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // Friends Section
        SliverToBoxAdapter(
          child: _buildSectionCard(
            context,
            child: FriendsSectionWidget(
              friends: _friends,
              isLoading: _isFriendsLoading,
              onFriendsUpdated: _loadFriends,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),

        // Menu List
        SliverToBoxAdapter(
          child: _buildSectionCard(
            context,
            child: MenuList(
              items: [
                MenuItem(
                  title: 'Reading History',
                  icon: Icons.history,
                  onTap: () async {
                    try {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ReadingHistoryScreen(),
                        ),
                      );

                      // "Read Again" action handle करा
                      if (widget.onReadingHistoryAction != null) {
                        widget.onReadingHistoryAction!(result);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open Reading History'),
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
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildArticlesReadCard(Color primaryColor, bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        try {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ReadingHistoryScreen(),
            ),
          );

          if (widget.onReadingHistoryAction != null) {
            widget.onReadingHistoryAction!(result);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open Reading History'),
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
                      color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.85),
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

  Widget _buildSectionCard(BuildContext context, {required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
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
      child: child,
    );
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