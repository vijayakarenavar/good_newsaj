import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/user_service.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:good_news/core/services/social_api_service.dart';
import 'package:good_news/features/articles/presentation/screens/friends_posts_screen.dart';
import 'package:good_news/features/profile/presentation/screens/blocked_users_screen.dart';
import 'package:good_news/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:good_news/features/profile/presentation/screens/my_posts_screen.dart';
import 'package:good_news/features/profile/presentation/screens/reading_history_screen.dart';
import 'package:good_news/features/profile/presentation/widgets/friends_section.dart';
import 'package:good_news/features/profile/presentation/widgets/quick_actions.dart';
import 'package:good_news/features/profile/presentation/widgets/menu_list.dart';
import 'package:good_news/features/social/presentation/screens/create_post_screen.dart';
import 'package:good_news/features/social/presentation/screens/friends_modal.dart';
import 'package:good_news/features/social/presentation/screens/friend_requests_screen.dart';
//import 'package:good_news/features/social/presentation/screens/comment_page.dart'; // ✅ ADDED IMPORT
import 'package:good_news/features/settings/presentation/screens/settings_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:good_news/features/articles/presentation/widgets/article_card_widget.dart';
import 'package:good_news/features/articles/presentation/widgets/social_post_card_widget.dart';
import 'package:good_news/features/articles/presentation/widgets/speed_dial_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../social/presentation/screens/comment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _allArticles = [];
  List<Map<String, dynamic>> _socialPosts = [];
  List<Map<String, dynamic>> _videoPosts = [];
  Map<int, String> _categoryMap = {};
  List<Map<String, dynamic>> _displayedItems = [];
  String? _nextCursor;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _showFab = true;
  bool _isRefreshing = false;
  bool _isInitialLoading = true;
  int _currentIndex = 0;
  bool _isSpeedDialOpen = false;

  // 👇 TAB MANAGEMENT (0=Video, 1=News, 2=Social, 3=Profile)
  int _selectedTabIndex = 1;

  // 👇 NEWS TAB: Category filtering
  int? _selectedCategoryId;
  List<int> _selectedCategoryIds = [];

  // 👇 HORIZONTAL PAGE NAVIGATION
  late PageController _horizontalPageController;
  DateTime? _lastTabTapTime;
  int? _lastTappedTabIndex;
  late ScrollController _categoryScrollController;

  // ✅ CRITICAL: Track previous page for swipe detection
  int? _previousPageIndex;

  static const int LOAD_MORE_THRESHOLD = 3;
  static const int PAGE_SIZE = 25;
  static const int PRELOAD_COUNT = 5;
  static const List<String> EXCLUDED_CATEGORIES = ['Education', 'Environment', 'International'];

  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  // ✅ REMOVED: Unused comment-related state variables
  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _preloadedImages = {};
  final Map<String, GlobalKey<_VideoPostWidgetState>> _videoKeys = {};
  DateTime? _loadingStartTime;

  // 👇 Profile state management
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;
  bool _isProfileLoading = true;
  int _articlesReadCount = 0;
  bool _isStatsLoading = true;
  List<Map<String, dynamic>> _friends = [];
  bool _isFriendsLoading = true;
  int _friendRequestsCount = 0;
  bool _isFriendRequestsLoading = true;

  @override
  void initState() {
    super.initState();
    _categoryScrollController = ScrollController();
    _horizontalPageController = PageController();
    _previousPageIndex = null;
    _initializeAnimations();
    _refreshUserDisplayName();
    _loadInitialData();
    _loadProfileData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _categoryScrollController.dispose();
    _horizontalPageController.dispose();
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  Future<void> _preloadImages(List<Map<String, dynamic>> items, int startIndex) async {
    if (!mounted) return;
    final endIndex = (startIndex + PRELOAD_COUNT).clamp(0, items.length);
    for (int i = startIndex; i < endIndex; i++) {
      if (i >= items.length) break;
      final item = items[i];
      String? imageUrl;
      if (item['type'] == 'article' && item['image_url'] != null) {
        imageUrl = item['image_url'];
      } else if ((item['type'] == 'social_post' || item['type'] == 'video_post') &&
          item['image_url'] != null) {
        imageUrl = item['image_url'];
      }
      if (imageUrl != null && imageUrl.isNotEmpty && !_preloadedImages.contains(imageUrl)) {
        _preloadedImages.add(imageUrl);
        try {
          await precacheImage(
            CachedNetworkImageProvider(imageUrl, cacheKey: imageUrl, maxWidth: 600, maxHeight: 600),
            context,
          );
        } catch (e) {
          print('Image preload failed for: $imageUrl');
        }
      }
    }
  }

  Future<void> _refreshUserDisplayName() async {
    try {
      await UserService.refreshUserProfile();
    } catch (e) {}
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isInitialLoading = true);
    try {
      _selectedCategoryIds = await PreferencesService.getSelectedCategories();
      final categoryResponse = await ApiService.getCategories();
      if (categoryResponse['status'] == 'success' && categoryResponse['categories'] != null) {
        final List<dynamic> categories = categoryResponse['categories'];
        _categoryMap = {
          for (final cat in categories)
            if (!EXCLUDED_CATEGORIES.contains(cat['name']))
              (cat['id'] as int): (cat['name'] ?? 'Unnamed') as String
        };
        _selectedCategoryIds =
            _selectedCategoryIds.where((id) => _categoryMap.containsKey(id)).toList();
      }
      await Future.wait([
        _loadArticles(isInitial: true),
        _loadSocialPosts(),
        _loadVideoPosts(),
      ]);
      _updateDisplayedItems();
      if (_displayedItems.isNotEmpty && mounted) {
        _preloadImages(_displayedItems, 0);
      }
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _horizontalPageController.hasClients) {
          _horizontalPageController.jumpToPage(1);
          setState(() {
            _selectedTabIndex = 1;
            _selectedCategoryId = null;
          });
          _scrollCategoryChipsToIndex(0);
        }
      });
    } catch (e) {
      print('❌ HOME: Failed to load: $e');
      if (mounted) _showSnackBar('Failed to load data. Please retry.');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  // 👇 PROFILE DATA LOADING
  Future<void> _loadProfileData() async {
    setState(() => _isProfileLoading = true);
    try {
      await Future.wait([
        _loadUserProfile(),
        _loadUserStats(),
        _loadFriends(),
        _loadFriendRequestsCount(),
      ]);
    } catch (e) {
      print('❌ Error loading profile data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserService.getUserProfile();
      if (mounted) {
        setState(() => _userProfile = profile);
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }

  Future<void> _loadUserStats() async {
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
          _friends = (data as List).map((item) => Map<String, dynamic>.from(item)).toList();
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

  Future<void> _loadArticles({bool isInitial = false}) async {
    if (_isLoadingMore) return;
    try {
      if (mounted) setState(() {
        _isLoadingMore = true;
        _loadingStartTime = DateTime.now();
      });
      final response = await ApiService.getUnifiedFeed(
        limit: PAGE_SIZE,
        cursor: _nextCursor,
        categoryId: _selectedCategoryId,
      );
      if (!mounted) return;
      if (response['status'] == 'success') {
        final List<dynamic> items = response['items'] ?? [];
        List<Map<String, dynamic>> newArticles = items
            .where((item) => item['type'] == 'article')
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        setState(() {
          if (isInitial) {
            _allArticles = newArticles;
          } else {
            _allArticles.addAll(newArticles);
          }
          _nextCursor = response['next_cursor'];
          _hasMore = response['has_more'] ?? (response['next_cursor'] != null);
        });
      }
    } catch (e) {
      print('❌ EXCEPTION loading articles: $e');
    } finally {
      if (mounted) setState(() {
        _isLoadingMore = false;
        _loadingStartTime = null;
      });
    }
  }

  Future<void> _loadSocialPosts() async {
    try {
      final response = await SocialApiService.getPosts();
      if (response['status'] == 'success') {
        final postsList = response['posts'] as List;
        final List<int> locallyLikedPosts = await PreferencesService.getLikedPosts();
        if (mounted) {
          setState(() {
            _socialPosts = postsList
                .map((post) => _formatSocialPost(post, locallyLikedPosts))
                .toList();
          });
        }
      }
    } catch (e) {
      print('❌ Error loading social: $e');
    }
  }

  Map<String, dynamic> _formatSocialPost(Map<String, dynamic> post, List<int> locallyLikedPosts) {
    final authorName = post['display_name'] ?? 'Unknown';
    final likesCount = post['likes_count'] ?? 0;
    final postId = post['id'] is int ? post['id'] : int.tryParse(post['id'].toString()) ?? 0;
    final apiLiked = post['user_has_liked'] == 1 || post['user_has_liked'] == true;
    final localLiked = locallyLikedPosts.contains(postId);
    return {
      'type': 'social_post',
      'id': postId.toString(),
      'author': authorName,
      'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
      'title': post['title'] ?? '',
      'content': post['content'] ?? '',
      'created_at': post['created_at'],
      'likes': likesCount,
      'isLiked': apiLiked || localLiked,
      'image_url': post['image_url'],
    };
  }

  Future<void> _loadVideoPosts() async {
    try {
      final List<Map<String, dynamic>> localVideos = List.generate(16, (index) {
        final videoNum = index + 1;
        return {
          'type': 'video_post',
          'id': 'vid_$videoNum',
          'author': 'Joy Scroll',
          'avatar': 'J',
          'title': _getVideoTitle(videoNum),
          'content': _getVideoContent(videoNum),
          'created_at': DateTime.now().subtract(Duration(hours: index * 2)).toIso8601String(),
          'likes': 100 + (index * 50),
          'isLiked': false,
          'video_url': 'assets/videos/ajay$videoNum.mp4',
        };
      });
      if (mounted) setState(() => _videoPosts = localVideos);
    } catch (e) {
      print('❌ Error loading videos: $e');
    }
  }

  String _getVideoTitle(int num) {
    final titles = [
      'Finding Joy in Small Moments ✨',
      'Morning Walk in the Hills 🌿',
      'Golden Hour Magic 🌅',
      'Random Acts of Kindness 💚',
      'Street Food Adventures 🍜',
      'Monsoon Vibes ☔',
      'Weekend Creativity 🎨',
      'Fitness Journey Update 💪',
      'Coffee & Conversations ☕',
      'Behind the Scenes 🎬',
      'Weekly Recap & Gratitude 🙏',
      'Nature Photography Tips 📸',
      'Sunset Chasing 🌇',
      'Street Art Discovery 🎨',
      'Local Music Scene 🎵',
      'Weekend Vibes 🌟',
    ];
    return titles[(num - 1) % titles.length];
  }

  String _getVideoContent(int num) {
    final contents = [
      'Sometimes happiness is hidden in the simplest things.',
      'Peaceful moments captured during my morning hike.',
      'Caught the most beautiful sunset today.',
      'Witnessed something beautiful that restored my faith.',
      'Exploring local flavors and the stories behind them.',
      'There\'s something magical about the first rains.',
      'Spent my weekend creating something new.',
      'Small progress is still progress!',
      'Had an inspiring conversation about life and dreams.',
      'Here\'s how I create content!',
      'Reflecting on an amazing week filled with blessings.',
      'Capturing the beauty of nature one frame at a time.',
      'The best moments happen at golden hour.',
      'Found amazing street art in the city today.',
      'Discovered incredible local talent performing live.',
      'Making the most of every moment this weekend.',
    ];
    return contents[(num - 1) % contents.length];
  }

  void _updateDisplayedItems() {
    if (!mounted) return;
    setState(() {
      if (_selectedTabIndex == 0) {
        _displayedItems = List.from(_videoPosts);
      } else if (_selectedTabIndex == 1) {
        if (_selectedCategoryId == null) {
          _displayedItems = List.from(_allArticles);
        } else {
          _displayedItems = _allArticles
              .where((article) => article['category_id'] == _selectedCategoryId)
              .toList();
          if (_displayedItems.length < 5 && _hasMore && !_isLoadingMore) {
            Future.delayed(Duration.zero, () => _loadArticles());
          }
        }
      } else if (_selectedTabIndex == 2) {
        _displayedItems = List.from(_socialPosts);
      } else {
        _displayedItems = [];
      }
    });
  }

  void _selectCategory(int? categoryId) async {
    if (categoryId == _selectedCategoryId) return;

    setState(() {
      _selectedTabIndex = 1;
      _selectedCategoryId = categoryId;
      _currentIndex = 0;
    });

    if (categoryId != null) {
      setState(() {
        _allArticles.clear();
        _nextCursor = null;
        _hasMore = true;
      });
      await _loadArticles(isInitial: true);
    }

    _updateDisplayedItems();

    if (_displayedItems.isNotEmpty && mounted) {
      _preloadImages(_displayedItems, 0);
    }

    // ✅ CRITICAL: Navigate to category page AND scroll chip to center
    _scrollToCategoryPage(categoryId);
  }

  void _scrollToCategoryPage(int? categoryId) {
    final categoryList = _buildCategoryList();
    final index = categoryList.indexWhere((cat) => cat['id'] == categoryId);
    if (index != -1) {
      final targetPage = 1 + index;
      // Use jumpToPage for immediate response instead of animateToPage
      _horizontalPageController.jumpToPage(targetPage);
      _scrollCategoryChipsToIndex(index);
    } else if (categoryId == null) {
      // For "All" category (null), go to page 1
      _horizontalPageController.jumpToPage(1);
      _scrollCategoryChipsToIndex(0); // Assuming "All" is at index 0
    }
  }

  void _scrollCategoryChipsToIndex(int index) {
    // ✅ Immediate execution without delay for better responsiveness
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_categoryScrollController.hasClients) return;

      final categoryList = _buildCategoryList();
      final totalCategories = categoryList.length;

      // Don't scroll if there are 5 or fewer categories (all fit on screen)
      if (totalCategories <= 5) {
        _categoryScrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
        return;
      }

      final itemWidth = 80.0; // Approximate chip width
      final spacing = 16.0; // Spacing between chips
      final totalItemWidth = itemWidth + spacing;

      double targetOffset;

      // ✅ SLIDING WINDOW LOGIC: Always show 5 categories at a time
      // Categories are grouped in sets of 5
      // Index 0-4: Show 0-4 (All, Cat1, Cat2, Cat3, Cat4)
      // Index 5-9: Show 5-9 (Cat5, Cat6, Cat7, Cat8, Cat9)
      // Index 10-14: Show 10-14, etc.

      // Calculate which "window" of 5 categories we're in
      final windowStart = (index ~/ 5) * 5;

      // Scroll to show this window (starting from windowStart)
      targetOffset = windowStart * totalItemWidth;

      // Clamp to valid scroll range
      final maxScroll = _categoryScrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);

      // ✅ SMOOTH ANIMATION
      _categoryScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final dragEnd = details.primaryVelocity ?? 0;
    if (dragEnd.abs() < 300) return;
    if (dragEnd < -300 && _currentIndex < _displayedItems.length - 1) {
      _currentIndex++;
    } else if (dragEnd > 300 && _currentIndex > 0) {
      _currentIndex--;
    }
  }

  void _toggleSpeedDial() {
    setState(() {
      _isSpeedDialOpen = !_isSpeedDialOpen;
      _isSpeedDialOpen ? _animationController.forward() : _animationController.reverse();
    });
  }

  // ✅ FIXED: Video tab navigation now works from ANY tab
  void _onTabChanged(int index) {
    final now = DateTime.now();
    final wasDoubleTap = _lastTappedTabIndex == index &&
        _lastTabTapTime != null &&
        now.difference(_lastTabTapTime!) < Duration(milliseconds: 300);

    // Double tap: refresh the specific tab
    if (wasDoubleTap) {
      _handleTabSpecificRefresh(index);
      return;
    }

    _lastTabTapTime = now;
    _lastTappedTabIndex = index;

    final categoryList = _buildCategoryList();
    final totalNewsPages = categoryList.length;
    int targetPage;

    // ✅ CRITICAL FIX: Calculate target page BEFORE state update
    if (index == 0) {
      targetPage = 0; // Video tab → Page 0
    } else if (index == 1) {
      targetPage = 1; // News tab → Page 1 (All category)
    } else if (index == 2) {
      targetPage = totalNewsPages + 1; // Social tab
    } else {
      targetPage = totalNewsPages + 2; // Profile tab
    }

    // Update tab state AFTER calculating target page
    if (_selectedTabIndex != index) {
      setState(() {
        _selectedTabIndex = index;
        _selectedCategoryId = (index == 1) ? null : null;
      });
      _updateDisplayedItems();
    }

    // Force page navigation - use jumpToPage for immediate response
    if (_horizontalPageController.hasClients) {
      _horizontalPageController.jumpToPage(targetPage);
    }
  }

  Future<void> _handleTabSpecificRefresh(int tabIndex) async {
    setState(() => _isRefreshing = true);
    try {
      if (tabIndex == 0) {
        await _loadVideoPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Videos refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (tabIndex == 1) {
        _preloadedImages.clear();
        _allArticles.clear();
        _nextCursor = null;
        _hasMore = true;
        await _loadArticles(isInitial: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ News refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (tabIndex == 2) {
        await _loadSocialPosts();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Social posts refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (tabIndex == 3) {
        await _loadProfileData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✨ Profile refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Refresh error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  // ✅ FIXED: Category chips auto-scroll when swiping + always show 5 at a time
  void _onHorizontalPageChanged(int pageIndex) {
    final previousPage = _previousPageIndex ?? pageIndex;
    _previousPageIndex = pageIndex;

    final categoryList = _buildCategoryList();
    final totalNewsPages = categoryList.length;
    final socialPageIndex = totalNewsPages + 1;
    final profilePageIndex = totalNewsPages + 2;

    // When swiping LEFT from Social tab → News tab, force "All" category
    if (previousPage == socialPageIndex &&
        pageIndex >= 1 &&
        pageIndex <= totalNewsPages &&
        pageIndex != 1) {
      Future.delayed(Duration.zero, () {
        if (mounted && _horizontalPageController.hasClients) {
          _horizontalPageController.jumpToPage(1);
          _previousPageIndex = 1;
          // ✅ Scroll to "All" category (index 0)
          _scrollCategoryChipsToIndex(0);
        }
      });
      return;
    }

    int newTabIndex;
    int? newCategoryId;

    if (pageIndex == 0) {
      newTabIndex = 0;
      newCategoryId = null;
    } else if (pageIndex >= 1 && pageIndex <= totalNewsPages) {
      newTabIndex = 1;
      final categoryIndex = pageIndex - 1;
      newCategoryId = categoryList[categoryIndex]['id'];

      // ✅ CRITICAL FIX: Update category selection immediately to sync UI
      if (newCategoryId != _selectedCategoryId) {
        setState(() {
          _selectedCategoryId = newCategoryId;
        });
      }
      
      // Scroll category chips immediately without delay for better sync
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _categoryScrollController.hasClients) {
          _scrollCategoryChipsToIndex(categoryIndex);
        }
      });
    } else if (pageIndex == socialPageIndex) {
      newTabIndex = 2;
      newCategoryId = null;
    } else if (pageIndex == profilePageIndex) {
      newTabIndex = 3;
      newCategoryId = null;
      if (_selectedTabIndex != 3) {
        _loadProfileData();
      }
    } else {
      newTabIndex = 1;
      newCategoryId = null;
    }

    // Always update the selected state when page changes to ensure sync
    if (newTabIndex != _selectedTabIndex || newCategoryId != _selectedCategoryId) {
      setState(() {
        _selectedTabIndex = newTabIndex;
        _selectedCategoryId = newCategoryId;
      });
    }
    _updateDisplayedItems();

    if (_displayedItems.isNotEmpty && mounted) {
      _preloadImages(_displayedItems, 0);
    }

    // Auto-play first video when Video tab becomes visible
    if (pageIndex == 0 && _videoPosts.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          final firstId = _videoPosts[0]['id'];
          final key = _videoKeys[firstId];
          key?.currentState?.forcePlay();
        }
      });
    }
  }

  int _getTotalPageCount() {
    final categoryList = _buildCategoryList();
    return 1 + categoryList.length + 2;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadInitialData,
        ),
      ),
    );
  }

  void _shareArticle(Map<String, dynamic> article) {
    final title = article['title'] ?? '';
    final summary = article['content'] ?? '';
    final url = article['source_url'] ?? '';
    final shareText = '''
🗞 joy scroll!
$title
${summary.length > 100 ? summary.substring(0, 100) + '...' : summary}
${url.isNotEmpty ? '🔗 $url' : ''}
''';
    Share.share(shareText);
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final postId = int.parse(post['id']);
    final bool wasLiked = post['isLiked'];
    final int currentLikes = post['likes'];
    setState(() {
      post['isLiked'] = !wasLiked;
      post['likes'] = wasLiked ? currentLikes - 1 : currentLikes + 1;
    });
    try {
      final response = wasLiked
          ? await SocialApiService.unlikePost(postId)
          : await SocialApiService.likePost(postId);
      if (response['status'] == 'success') {
        if (!wasLiked) {
          PreferencesService.saveLikedPost(postId);
        } else {
          PreferencesService.removeLikedPost(postId);
        }
        if (response['likes_count'] != null && mounted) {
          setState(() => post['likes'] = response['likes_count']);
        }
      } else {
        if (mounted) {
          setState(() {
            post['isLiked'] = wasLiked;
            post['likes'] = currentLikes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          post['isLiked'] = wasLiked;
          post['likes'] = currentLikes;
        });
      }
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (e) {
      return 'Just now';
    }
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToSettings() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (mounted) await _loadInitialData();
  }

  void _navigateToArticle(int articleId) {
    final index = _displayedItems.indexWhere(
          (item) => item['type'] == 'article' && item['id'] == articleId,
    );
    if (index != -1) {
      setState(() => _currentIndex = index);
    }
  }

  void _handleCreatePost() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreatePostScreen()),
    );
    if (result == true && mounted) {
      await _loadSocialPosts();
      _updateDisplayedItems();
    }
  }

  List<Map<String, dynamic>> _buildCategoryList() {
    final List<Map<String, dynamic>> categoryList = [
      {'id': null, 'name': 'All'},
    ];
    if (_selectedCategoryIds.isNotEmpty) {
      for (var categoryId in _selectedCategoryIds) {
        if (_categoryMap.containsKey(categoryId)) {
          categoryList.add({'id': categoryId, 'name': _categoryMap[categoryId]!});
        }
      }
    } else {
      categoryList.addAll(
        _categoryMap.entries.map((e) => {'id': e.key, 'name': e.value}).toList(),
      );
    }
    return categoryList;
  }

  // PROFILE UI BUILDERS
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
      await _loadProfileData();
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
          color: primaryColor.withOpacity(0.15),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.25) : Colors.grey.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildArticlesReadCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    return GestureDetector(
      onTap: () async {
        try {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const ReadingHistoryScreen(),
            ),
          );
          if (result != null &&
              result is Map &&
              result['action'] == 'read_article' &&
              mounted) {
            _horizontalPageController.animateToPage(
              1,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            setState(() {
              _selectedTabIndex = 1;
              _selectedCategoryId = null;
            });
            Future.delayed(Duration(milliseconds: 400), () {
              if (mounted) {
                _navigateToArticle(result['article_id']);
              }
            });
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
            color: primaryColor.withOpacity(0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.25) : Colors.grey.withOpacity(0.12),
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

  Widget _buildProfilePage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    if (_isProfileLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text(
              'Loading profile...',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
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
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
        SliverToBoxAdapter(
          child: _isStatsLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _buildArticlesReadCard(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
        SliverToBoxAdapter(
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
                    if (result != null &&
                        result is Map &&
                        result['action'] == 'read_article' &&
                        mounted) {
                      _horizontalPageController.animateToPage(
                        1,
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      setState(() {
                        _selectedTabIndex = 1;
                        _selectedCategoryId = null;
                      });
                      Future.delayed(Duration(milliseconds: 400), () {
                        if (mounted) {
                          _navigateToArticle(result['article_id']);
                        }
                      });
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
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final categoryList = _buildCategoryList();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _buildMainContent(categoryList),
            if (_showFab && _selectedTabIndex == 2) _buildSpeedDial(),
            if (_isLoadingMore &&
                !_isInitialLoading &&
                _loadingStartTime != null &&
                DateTime.now().difference(_loadingStartTime!).inMilliseconds > 300)
              Positioned(
                bottom: 85,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text('Loading...', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    return Container(
      height: isSmallScreen ? 60 : 65,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(
              icon: Icons.video_library_outlined,
              activeIcon: Icons.video_library,
              label: 'Video',
              isActive: _selectedTabIndex == 0,
              onTap: () => _onTabChanged(0),
            ),
            _buildNavItem(
              icon: Icons.article_outlined,
              activeIcon: Icons.article,
              label: 'News',
              isActive: _selectedTabIndex == 1,
              onTap: () => _onTabChanged(1),
            ),
            _buildNavItem(
              icon: Icons.people_outline,
              activeIcon: Icons.people,
              label: 'Social',
              isActive: _selectedTabIndex == 2,
              onTap: () => _onTabChanged(2),
            ),
            _buildNavItem(
              icon: Icons.person_outline,
              activeIcon: Icons.person,
              label: 'Profile',
              isActive: _selectedTabIndex == 3,
              onTap: () => _onTabChanged(3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: primaryColor.withOpacity(0.2),
        highlightColor: primaryColor.withOpacity(0.1),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSmallScreen ? 5 : 7),
                decoration: BoxDecoration(
                  color: isActive ? primaryColor.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: isActive
                      ? primaryColor
                      : isDark
                      ? Colors.white70
                      : Colors.grey[600],
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
              SizedBox(height: isSmallScreen ? 1 : 2),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9 : 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: isActive
                        ? primaryColor
                        : isDark
                        ? Colors.white60
                        : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> categoryList) {
    final pageCount = _getTotalPageCount();
    return RefreshIndicator(
      onRefresh: () async => _handleTabSpecificRefresh(_selectedTabIndex),
      color: Theme.of(context).colorScheme.primary,
      strokeWidth: 2.5,
      child: _isInitialLoading
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : PageView.builder(
        controller: _horizontalPageController,
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        itemCount: pageCount,
        onPageChanged: _onHorizontalPageChanged,
        itemBuilder: (context, pageIndex) {
          final totalNewsPages = categoryList.length;
          if (pageIndex == 0) {
            return _buildTabContent(
              items: _videoPosts,
              itemBuilder: _buildVideoPost,
            );
          } else if (pageIndex >= 1 && pageIndex <= totalNewsPages) {
            final categoryIndex = pageIndex - 1;
            final category = categoryList[categoryIndex];
            final categoryId = category['id'];
            List<Map<String, dynamic>> filteredArticles;
            if (categoryId == null) {
              filteredArticles = _allArticles;
            } else {
              filteredArticles = _allArticles
                  .where((article) => article['category_id'] == categoryId)
                  .toList();
            }
            return _buildNewsTabContent(
              categoryName: category['name'],
              items: filteredArticles,
              showEmptyState: filteredArticles.isEmpty && !_isLoadingMore,
              categoryList: categoryList,
              activeCategoryIndex: categoryIndex,
            );
          } else if (pageIndex == totalNewsPages + 1) {
            return _buildTabContent(
              items: _socialPosts,
              itemBuilder: _buildSocialPost,
            );
          } else if (pageIndex == totalNewsPages + 2) {
            return _buildProfilePage();
          } else {
            return Container();
          }
        },
      ),
    );
  }

  Widget _buildNewsTabContent({
    required String categoryName,
    required List<Map<String, dynamic>> items,
    required bool showEmptyState,
    required List<Map<String, dynamic>> categoryList,
    required int activeCategoryIndex,
  }) {
    return Column(
      children: [
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.builder(
            controller: _categoryScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categoryList.length,
            itemBuilder: (context, index) {
              final category = categoryList[index];
              final isSelected = index == activeCategoryIndex;
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final primaryColor = Theme.of(context).colorScheme.primary;
              return Padding(
                padding: EdgeInsets.only(right: MediaQuery.of(context).size.width * 0.04), // Responsive padding based on screen width
                child: GestureDetector(
                  onTap: () {
                    _selectCategory(category['id']);
                    _scrollCategoryChipsToIndex(index);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category['name'],
                        style: TextStyle(
                          color: isSelected
                              ? primaryColor
                              : isDark ? Colors.white60 : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: isSelected 
                              ? MediaQuery.of(context).size.width * 0.04  // Responsive font size
                              : MediaQuery.of(context).size.width * 0.035, // Responsive font size
                        ),
                      ),
                      if (isSelected)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Container(
                            height: 2.5,
                            width: MediaQuery.of(context).size.width * 0.15, // Responsive width based on screen size
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Expanded(
          child: GestureDetector(
            onVerticalDragEnd: _onVerticalDragEnd,
            child: PageView.builder(
              scrollDirection: Axis.vertical,
              physics: const ClampingScrollPhysics(),
              itemCount: items.isEmpty && showEmptyState ? 1 : items.length,
              itemBuilder: (context, index) {
                if (items.isEmpty && showEmptyState) {
                  return _buildEmptyStateForTab(categoryName);
                }
                final item = items[index];
                return _buildArticle(item);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent({
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return GestureDetector(
      onVerticalDragEnd: _onVerticalDragEnd,
      child: PageView.builder(
        scrollDirection: Axis.vertical,
        physics: const ClampingScrollPhysics(),
        itemCount: items.isEmpty ? 1 : items.length,
        itemBuilder: (context, index) {
          if (items.isEmpty) {
            return _buildEmptyStateForTab(
              _selectedTabIndex == 0 ? 'Video' : _selectedTabIndex == 2 ? 'Social' : 'News',
            );
          }
          final item = items[index];
          return itemBuilder(item);
        },
      ),
    );
  }

  Widget _buildArticle(Map<String, dynamic> article) {
    return RepaintBoundary(
      child: ArticleCardWidget(
        article: article,
        onTrackRead: (_) {},
        onShare: _shareArticle,
      ),
    );
  }

  // ✅ FIXED: Updated _buildSocialPost with onOpenCommentPage callback
  Widget _buildSocialPost(Map<String, dynamic> post) {
    final postId = post['id'] as String;
    _commentControllers.putIfAbsent(postId, () => TextEditingController());
    return RepaintBoundary(
      child: SocialPostCardWidget(
        post: post,
        commentController: _commentControllers[postId]!,
        onToggleLike: _toggleLike,
        onShare: _shareArticle,
        onAddFriend: (post) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now following ${post['author']}!'),
              backgroundColor: Colors.green,
            ),
          );
        },
        onShowFullImage: _showFullImageDialog,
        onOpenCommentPage: (postId, post) {
          // ✅ Navigate to CommentPage
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CommentPage(
                postId: postId,
                post: post,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPost(Map<String, dynamic> post) {
    final key = _videoKeys.putIfAbsent(post['id'], () => GlobalKey<_VideoPostWidgetState>());
    return RepaintBoundary(
      child: _VideoPostWidget(
        key: key,
        post: post,
        onToggleLike: () => _toggleLike(post),
        onToggleComments: () {}, // No-op for videos
        onShare: () => _shareArticle(post),
      ),
    );
  }

  Widget _buildSpeedDial() {
    return SpeedDialWidget(
      isOpen: _isSpeedDialOpen,
      rotationAnimation: _rotationAnimation,
      onToggle: _toggleSpeedDial,
      actions: [
        SpeedDialAction(
          bottom: 160,
          icon: Icons.post_add_outlined,
          label: 'Friends Posts',
          onTap: () {
            _toggleSpeedDial();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FriendsPostsScreen()),
            );
          },
        ),
        SpeedDialAction(
          bottom: 210,
          icon: Icons.person_add,
          label: 'Add Friend',
          onTap: () {
            _toggleSpeedDial();
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const FriendsModal(),
            );
          },
        ),
        SpeedDialAction(
          bottom: 260,
          icon: Icons.edit,
          label: 'Create Post',
          onTap: () {
            _toggleSpeedDial();
            _handleCreatePost();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyStateForTab(String tabName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String message = '';
    String subMessage = '';
    IconData icon = Icons.info_outline;
    VoidCallback? onPressed;
    String buttonText = '';
    IconData buttonIcon = Icons.refresh;

    if (tabName == 'Video') {
      message = 'No videos yet!';
      subMessage = 'Videos will appear here soon!';
      icon = Icons.video_library_outlined;
      onPressed = null;
      buttonText = 'Coming Soon';
    } else if (tabName == 'News' || tabName == 'All') {
      message = 'No articles yet!';
      subMessage = _hasMore ? 'Loading...' : 'Try a different category.';
      icon = Icons.article_outlined;
      onPressed = () => _handleTabSpecificRefresh(1);
      buttonText = 'Refresh';
    } else if (tabName == 'Social') {
      message = 'No social posts yet!';
      subMessage = 'Be the first to share something positive!';
      icon = Icons.people_outline;
      onPressed = _handleCreatePost;
      buttonText = 'Create Post';
      buttonIcon = Icons.edit;
    } else {
      message = 'No articles in $tabName';
      subMessage = 'Try another category.';
      icon = Icons.category_outlined;
      onPressed = () => _selectCategory(null);
      buttonText = 'View All';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white54 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (onPressed != null)
              ElevatedButton.icon(
                onPressed: onPressed,
                icon: Icon(buttonIcon),
                label: Text(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==================== VIDEO POST WIDGET ====================
class _VideoPostWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleComments;
  final VoidCallback onShare;

  const _VideoPostWidget({
    required this.post,
    required this.onToggleLike,
    required this.onToggleComments,
    required this.onShare,
    Key? key,
  }) : super(key: key);

  @override
  State<_VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<_VideoPostWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializeVideoFromStart() async {
    if (_isInitializing || _isInitialized) return;
    _isInitializing = true;
    if (_controller != null) {
      await _controller!.pause();
      await _controller!.dispose();
      _controller = null;
    }
    try {
      _controller = VideoPlayerController.asset(widget.post['video_url'])..setVolume(1.0);
      await _controller!.initialize();
      if (!mounted) {
        _isInitializing = false;
        return;
      }
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
        });
      }
    } finally {
      _isInitializing = false;
    }
  }

  void forcePlay() {
    if (!_isInitialized) {
      _initializeVideoFromStart().then((_) {
        if (mounted && _controller != null) {
          _controller!.seekTo(Duration.zero);
          _controller!.play();
        }
      });
    } else if (_controller != null) {
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return VisibilityDetector(
      key: Key(widget.post['id'].toString()),
      onVisibilityChanged: (visibilityInfo) {
        final visibleFraction = visibilityInfo.visibleFraction;
        if (visibleFraction > 0.4 && !_isInitialized && !_isInitializing) {
          _initializeVideoFromStart();
        }
        if (visibleFraction > 0.6) {
          if (_isInitialized && _controller != null) {
            if (!_controller!.value.isPlaying) {
              _controller!.seekTo(Duration.zero);
              _controller!.play();
            }
          }
        } else {
          if (_controller != null && _controller!.value.isPlaying) {
            _controller!.pause();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          if (_controller == null || !_isInitialized) return;
          if (_controller!.value.isPlaying) {
            _controller!.pause();
          } else {
            _controller!.play();
          }
        },
        child: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasError)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text('Video not available', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                )
              else if (_isInitialized && _controller != null)
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                )
              else
                Container(color: Colors.black),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 120,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 220,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 30,
                left: 16,
                right: 16,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white,
                                child: Text(
                                  widget.post['avatar'] as String,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  widget.post['author'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.post['title'],
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.post['content'],
                            style: const TextStyle(color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatTimestamp(widget.post['created_at']),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionButton(
                          icon: widget.post['isLiked'] == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          label: _formatCount(widget.post['likes']),
                          color: widget.post['isLiked'] == true ? Colors.red : Colors.white,
                          onTap: widget.onToggleLike,
                        ),
                        const SizedBox(height: 20),
                        _buildActionButton(
                          icon: Icons.chat_bubble_outline,
                          label: 'Comment',
                          color: Colors.white,
                          onTap: widget.onToggleComments,
                        ),
                        const SizedBox(height: 20),
                        _buildActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          color: Colors.white,
                          onTap: widget.onShare,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dateTime);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (e) {
      return 'Just now';
    }
  }
}