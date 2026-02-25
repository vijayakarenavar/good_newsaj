// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:good_news/core/utils/responsive_helper.dart';
import 'package:good_news/core/services/user_service.dart';
import 'package:good_news/features/profile/presentation/screens/blocked_users_screen.dart';
import 'package:good_news/features/profile/presentation/screens/my_posts_screen.dart';
import 'package:good_news/features/profile/presentation/screens/reading_history_screen.dart';
import 'package:good_news/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:good_news/features/profile/presentation/widgets/friends_section.dart';
import 'package:good_news/features/profile/presentation/widgets/quick_actions.dart';
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

  Future<void> _refreshProfileData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadUserData(),
      _loadFriends(),
      _loadFriendRequestsCount(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  // ================= FRIENDS =================

  Future<void> _loadFriends() async {
    setState(() => _isFriendsLoading = true);
    try {
      final response = await SocialApiService.getFriends();
      if (response['status'] == 'success') {
        final data = response['data'] ?? [];
        if (mounted) {
          setState(() {
            _friends = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
            _isFriendsLoading = false;
          });
        }
      } else {
        throw Exception(response['error']);
      }
    } catch (e) {
      debugPrint("Error loading friends: $e");
      if (mounted) setState(() => _isFriendsLoading = false);
    }
  }

  Future<void> _loadFriendsSilently() async {
    try {
      final response = await SocialApiService.getFriends();
      if (response['status'] == 'success') {
        final data = response['data'] ?? [];
        if (mounted) {
          setState(() {
            _friends = (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Silent friends load error: $e");
    }
  }

  // ================= USER PROFILE =================

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await UserService.getUserProfile();
      if (mounted) setState(() => _userProfile = profile);

      await _loadStats();

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading user data: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load profile: $e")),
        );
      }
    }
  }

  // ================= STATS =================

  Future<void> _loadStats() async {
    setState(() => _isStatsLoading = true);
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

      final history = await UserService.getHistory();
      if (mounted) {
        setState(() {
          _articlesReadCount = history.length;
          _isStatsLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Stats load error: $e");
      if (mounted) {
        setState(() {
          _articlesReadCount = 0;
          _isStatsLoading = false;
        });
      }
    }
  }

  // ================= FRIEND REQUESTS =================

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
      }
    } catch (e) {
      debugPrint("Friend request count error: $e");
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
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _onScroll() => setState(() => _scrollOffset = _scrollController.offset);

  // ================= EDIT PROFILE =================

  Future<void> _editProfile() async {
    if (_userProfile == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(userProfile: _userProfile!)),
    );

    if (result == true && mounted) _loadUserData();
  }

  // ================= UI =================

  Widget _buildAnimatedProfileHeader() {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator()));
    }

    final displayName = _userProfile?['display_name'] ?? "Good News Reader";
    final email = _userProfile?['email'] ?? "No email";

    final scale = (1.0 - (_scrollOffset / 200)).clamp(0.8, 1.0);
    final opacity = (1.0 - (_scrollOffset / 100)).clamp(0.3, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      transform: Matrix4.identity()..scale(scale),
      child: Opacity(
        opacity: opacity,
        child: Column(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
              child: _profileImage == null
                  ? Text(displayName[0].toUpperCase(), style: const TextStyle(fontSize: 40))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(email),
          ],
        ),
      ),
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfileData,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildAnimatedProfileHeader(),
              const SizedBox(height: 20),

              QuickActionsWidget(
                onMyPostsTap: _showMyPosts,
                onFriendRequestsTap: _showFriendRequests,
                onSettingsTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                friendRequestsCount: _friendRequestsCount,
              ),

              const SizedBox(height: 20),

              FriendsSectionWidget(
                friends: _friends,
                isLoading: _isFriendsLoading,
                onFriendsUpdated: _loadFriendsSilently,
              ),

              const SizedBox(height: 20),

              MenuList(items: [
                MenuItem(
                  title: "Reading History",
                  icon: Icons.history,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReadingHistoryScreen())),
                ),
                MenuItem(
                  title: "Blocked Users",
                  icon: Icons.block,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedUsersScreen())),
                ),
                MenuItem(
                  title: "About",
                  icon: Icons.info,
                  onTap: () => _showAboutDialog(context),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ================= NAVIGATIONS =================

  void _showMyPosts() {
    final id = _userProfile?['id'];
    if (id != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MyPostsScreen(userId: id)));
    }
  }

  Future<void> _showFriendRequests() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendRequestsScreen()));
    if (result == true) {
      _loadFriendRequestsCount();
      _loadFriends();
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: "Joy Scroll",
      applicationVersion: "1.0.0",
      children: const [Text("Positive AI-powered news app")],
    );
  }
}