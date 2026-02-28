import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/user_service.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:good_news/core/services/social_api_service.dart';
import 'package:good_news/features/profile/presentation/screens/edit_profile_screen.dart';
import 'package:good_news/features/profile/presentation/screens/reading_history_screen.dart';
import 'package:good_news/features/settings/presentation/screens/settings_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:good_news/features/articles/presentation/widgets/article_card_widget.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../../../widgets/speed_dial_fab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
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
  bool _isVideoLoading = false;
  int _currentIndex = 0;

  int _selectedTabIndex = 1;
  int? _selectedCategoryId;
  List<int> _selectedCategoryIds = [];

  late PageController _horizontalPageController;
  late PageController _videoPageController;
  DateTime? _lastTabTapTime;
  int? _lastTappedTabIndex;
  late ScrollController _categoryScrollController;

  int? _previousPageIndex;

  // ─── FIX: Currently playing video index track करण्यासाठी ───
  int _currentVideoPage = 0;

  static const int LOAD_MORE_THRESHOLD = 3;
  static const int PAGE_SIZE = 9999;
  static const int PRELOAD_COUNT = 5;
  static const List<String> EXCLUDED_CATEGORIES = [
    'Education',
    'Environment',
    'International'
  ];

  final Map<String, TextEditingController> _commentControllers = {};
  final Set<String> _preloadedImages = {};
  final Map<String, GlobalKey<_VideoPostWidgetState>> _videoKeys = {};
  final Map<String, bool> _videoReadyStates = {};

  // ─── Video Pagination ───────────────────────────────────────────────────
  static const int _kVideoPageSize    = 10; // प्रत्येक batch मध्ये किती videos
  static const int _kVideoPreloadAt   = 3;  // शेवटापासून किती videos बाकी असताना next fetch
  int  _videoOffset       = 0;             // API offset
  bool _videoHasMore      = true;          // अजून videos आहेत का
  bool _videoLoadingMore  = false;         // background fetch चालू आहे का
  // ────────────────────────────────────────────────────────────────────────



  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;
  bool _isProfileLoading = true;
  int _articlesReadCount = 0;
  bool _isStatsLoading = true;
  List<Map<String, dynamic>> _friends = [];
  bool _isFriendsLoading = true;
  int _friendRequestsCount = 0;
  bool _isFriendRequestsLoading = true;

  // ─────────────────────────────────────────────────────────────────────────
  // VIDEO CONTROL HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// फक्त current page चा video play करा — बाकी सगळे pause
  void _playOnlyCurrentVideo() {
    final currentId = _videoPosts[_currentVideoPage]['id'] as String;
    for (final entry in _videoKeys.entries) {
      if (entry.key == currentId) {
        entry.value.currentState?.forcePlay();
      } else {
        entry.value.currentState?.hardStop();
      }
    }
  }

  /// सगळे videos hard stop (tab switch / background)
  void _stopAllVideos() {
    for (final key in _videoKeys.values) {
      key.currentState?.hardStop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _categoryScrollController = ScrollController();
    _horizontalPageController = PageController();
    _videoPageController = PageController(keepPage: true);
    _previousPageIndex = null;
    _refreshUserDisplayName();
    _loadInitialData();
    _loadProfileData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _stopAllVideos();
    }
    // Resume वर auto-play नाही — user swipe केल्यावरच forcePlay
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _categoryScrollController.dispose();
    _horizontalPageController.dispose();
    _videoPageController.dispose();
    for (var controller in _commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _preloadImages(
      List<Map<String, dynamic>> items, int startIndex) async {
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
        } catch (e) {}
      }
    }
  }

  Future<void> _refreshUserDisplayName() async {
    try { await UserService.refreshUserProfile(); } catch (e) {}
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
        _selectedCategoryIds = _selectedCategoryIds
            .where((id) => _categoryMap.containsKey(id))
            .toList();
      }
      await _loadVideoPosts();
      await Future.wait([
        _loadArticles(isInitial: true),
        _loadSocialPosts(),
      ]);
      _updateDisplayedItems();
      if (_displayedItems.isNotEmpty && mounted) {
        _preloadImages(_displayedItems, 0);
      }
      Future.delayed(Duration(milliseconds: 500), () {
        if (mounted && _horizontalPageController.hasClients) {
          _horizontalPageController.jumpToPage(1);
          setState(() { _selectedTabIndex = 1; _selectedCategoryId = null; });
          _scrollCategoryChipsToIndex(0);
        }
      });
    } catch (e) {
      if (mounted) _showSnackBar('Failed to load data. Please retry.');
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  Future<void> _loadProfileData() async {
    setState(() => _isProfileLoading = true);
    try {
      await Future.wait([_loadUserProfile(), _loadUserStats(), _loadFriends(), _loadFriendRequestsCount()]);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load profile'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProfileLoading = false);
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await UserService.getUserProfile();
      if (mounted) setState(() => _userProfile = profile);
    } catch (e) {}
  }

  Future<void> _loadUserStats() async {
    setState(() => _isStatsLoading = true);
    try {
      try {
        final stats = await UserService.getUserStats();
        if (stats != null && mounted) {
          setState(() { _articlesReadCount = stats['articles_read'] ?? 0; _userStats = stats; _isStatsLoading = false; });
          return;
        }
      } catch (e) {}
      final history = await UserService.getHistory();
      if (mounted) setState(() { _articlesReadCount = history.length; _isStatsLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _articlesReadCount = 0; _isStatsLoading = false; });
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
    } catch (e) { if (mounted) setState(() => _isFriendsLoading = false); }
  }

  Future<void> _loadFriendRequestsCount() async {
    setState(() => _isFriendRequestsLoading = true);
    try {
      final response = await SocialApiService.getFriendRequests();
      if (response['status'] == 'success' && mounted) {
        final data = response['data'] ?? [];
        setState(() { _friendRequestsCount = (data as List).length; _isFriendRequestsLoading = false; });
      }
    } catch (e) { if (mounted) setState(() { _friendRequestsCount = 0; _isFriendRequestsLoading = false; }); }
  }

  Future<void> _loadArticles({bool isInitial = false}) async {
    if (_isLoadingMore) return;
    try {
      if (mounted) setState(() => _isLoadingMore = true);
      if (isInitial) {
        final categoryIds = [null, ..._categoryMap.keys];
        final responses = await Future.wait(categoryIds.map((categoryId) =>
            ApiService.getUnifiedFeed(limit: 9999, cursor: null, categoryId: categoryId)));
        Map<int?, List<Map<String, dynamic>>> categoryArticles = {};
        for (int i = 0; i < categoryIds.length; i++) {
          final response = responses[i];
          if (response['status'] == 'success') {
            final items = response['items'] ?? [];
            categoryArticles[categoryIds[i]] = (items as List)
                .where((item) => item['type'] == 'article')
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
        }
        List<Map<String, dynamic>> interleaved = [];
        final lists = categoryArticles.values.where((l) => l.isNotEmpty).toList();
        int maxLen = lists.fold(0, (max, l) => l.length > max ? l.length : max);
        for (int i = 0; i < maxLen; i++) {
          for (final list in lists) { if (i < list.length) interleaved.add(list[i]); }
        }
        final seen = <dynamic>{};
        final unique = interleaved.where((a) => seen.add(a['id'])).toList();
        if (mounted) setState(() { _allArticles = unique; _hasMore = false; _nextCursor = null; });
      }
    } catch (e) { debugPrint('❌ Articles load error: $e'); }
    finally { if (mounted) setState(() => _isLoadingMore = false); }
  }

  Future<void> _loadSocialPosts() async {
    try {
      final response = await SocialApiService.getPosts();
      if (response['status'] == 'success') {
        final postsList = response['posts'] as List;
        final List<int> locallyLikedPosts = await PreferencesService.getLikedPosts();
        if (mounted) setState(() {
          _socialPosts = postsList.map((post) => _formatSocialPost(post, locallyLikedPosts)).toList();
        });
      }
    } catch (e) { debugPrint('❌ Social posts error: $e'); }
  }

  Map<String, dynamic> _formatSocialPost(Map<String, dynamic> post, List<int> locallyLikedPosts) {
    final authorName = post['display_name'] ?? 'Unknown';
    final postId = post['id'] is int ? post['id'] : int.tryParse(post['id'].toString()) ?? 0;
    final apiLiked = post['user_has_liked'] == 1 || post['user_has_liked'] == true;
    return {
      'type': 'social_post', 'id': postId.toString(), 'author': authorName,
      'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
      'title': post['title'] ?? '', 'content': post['content'] ?? '',
      'created_at': post['created_at'], 'likes': post['likes_count'] ?? 0,
      'comments': post['comments_count'] ?? post['comments'] ?? 0,
      'isLiked': apiLiked || locallyLikedPosts.contains(postId),
      'image_url': post['image_url'], 'user_id': post['user_id'] ?? post['author_id'],
    };
  }

  // ─── Video map helper (DRY) ───────────────────────────────────────────
  Map<String, dynamic> _mapVideo(Map<String, dynamic> v) {
    final rawAuthor = v['uploaded_by_name']
        ?? v['channel_name'] ?? v['display_name'] ?? v['user_display_name']
        ?? v['user_name'] ?? v['username'] ?? v['author'] ?? v['author_name']
        ?? v['uploader'] ?? v['uploader_name'] ?? v['owner'] ?? v['owner_name']
        ?? v['posted_by'] ?? v['creator'] ?? v['creator_name']
        ?? v['added_by'] ?? v['uploaded_by'];
    final userId    = v['user_id'];
    final authorName = (rawAuthor != null && rawAuthor.toString().isNotEmpty)
        ? rawAuthor.toString()
        : (userId != null ? 'User $userId' : 'Joy Scroll');
    return {
      'type': 'video_post',  'id': v['id'].toString(), 'api_id': v['id'],
      'author': authorName,  'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'J',
      'user_id': userId,     'title': v['title'] ?? '',
      'content': v['description'] ?? '', 'created_at': v['created_at'],
      'likes': v['like_count'] ?? 0, 'isLiked': false,
      'video_id': v['video_id'],     'thumbnail_url': v['thumbnail_url'] ?? '',
      'duration': v['duration'] ?? 0, 'category': v['category'] ?? '',
    };
  }

  // ─── Initial load: पहिले 10 videos ───────────────────────────────────
  Future<void> _loadVideoPosts({int retryCount = 0}) async {
    if (!mounted) return;
    // Reset pagination state
    _videoOffset    = 0;
    _videoHasMore   = true;
    _videoLoadingMore = false;
    setState(() => _isVideoLoading = true);
    try {
      final response = await ApiService.getVideoFeed(
        limit: _kVideoPageSize, offset: _videoOffset,
      );
      if (!mounted) return;
      if (response['status'] == 'success') {
        final raw = response['videos'] as List? ?? [];
        if (raw.isEmpty) {
          if (retryCount < 3) {
            await Future.delayed(Duration(seconds: retryCount + 1));
            return _loadVideoPosts(retryCount: retryCount + 1);
          }
          if (mounted) setState(() { _videoPosts = []; _isVideoLoading = false; });
          return;
        }
        final mapped = raw.map((v) => _mapVideo(v as Map<String, dynamic>)).toList();
        _videoOffset  += mapped.length;
        _videoHasMore  = mapped.length == _kVideoPageSize; // कमी आले = संपले
        if (mounted) setState(() { _videoPosts = mapped; _isVideoLoading = false; });
      } else {
        if (retryCount < 3) {
          await Future.delayed(Duration(seconds: retryCount + 1));
          return _loadVideoPosts(retryCount: retryCount + 1);
        }
        if (mounted) setState(() { _videoPosts = []; _isVideoLoading = false; });
      }
    } catch (e) {
      if (retryCount < 3 && mounted) {
        await Future.delayed(Duration(seconds: (retryCount + 1) * 2));
        return _loadVideoPosts(retryCount: retryCount + 1);
      }
      if (mounted) setState(() { _videoPosts = []; _isVideoLoading = false; });
    }
  }

  // ─── Background load: पुढचे 10 videos (user ला दिसणार नाही) ──────────
  Future<void> _loadMoreVideos() async {
    if (!_videoHasMore || _videoLoadingMore || !mounted) return;
    _videoLoadingMore = true;
    try {
      final response = await ApiService.getVideoFeed(
        limit: _kVideoPageSize, offset: _videoOffset,
      );
      if (!mounted) return;
      if (response['status'] == 'success') {
        final raw = response['videos'] as List? ?? [];
        if (raw.isEmpty) { _videoHasMore = false; return; }
        final mapped = raw.map((v) => _mapVideo(v as Map<String, dynamic>)).toList();

        // Duplicate filter — id check
        final existingIds = _videoPosts.map((p) => p['id']).toSet();
        final fresh = mapped.where((v) => !existingIds.contains(v['id'])).toList();

        _videoOffset += mapped.length;
        _videoHasMore = mapped.length == _kVideoPageSize;
        if (fresh.isNotEmpty && mounted) {
          setState(() => _videoPosts = [..._videoPosts, ...fresh]);
        }
      }
    } catch (e) {
      debugPrint('❌ loadMoreVideos error: $e');
    } finally {
      if (mounted) _videoLoadingMore = false;
    }
  }

  void _updateDisplayedItems() {
    if (!mounted) return;
    setState(() {
      if (_selectedTabIndex == 0) {
        if (_videoPosts.isNotEmpty) _displayedItems = List.from(_videoPosts);
      } else if (_selectedTabIndex == 1) {
        if (_selectedCategoryId == null) {
          _displayedItems = List.from(_allArticles);
        } else {
          _displayedItems = _allArticles.where((a) => a['category_id'] == _selectedCategoryId).toList();
          if (_displayedItems.length < 5 && _hasMore && !_isLoadingMore)
            Future.delayed(Duration.zero, () => _loadArticles());
        }
      } else {
        _displayedItems = [];
      }
    });
  }

  void _selectCategory(int? categoryId) async {
    if (categoryId == _selectedCategoryId) return;
    setState(() { _selectedTabIndex = 1; _selectedCategoryId = categoryId; _currentIndex = 0; });
    _updateDisplayedItems();
    if (categoryId != null) {
      final existing = _allArticles.where((a) => a['category_id'] == categoryId).toList();
      if (existing.isEmpty && _hasMore && !_isLoadingMore) _loadArticles(isInitial: false);
    }
    _scrollToCategoryPage(categoryId);
  }

  void _scrollToCategoryPage(int? categoryId) {
    final categoryList = _buildCategoryList();
    final index = categoryList.indexWhere((cat) => cat['id'] == categoryId);
    if (index != -1) {
      _horizontalPageController.animateToPage(1 + index, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
      _scrollCategoryChipsToIndex(index);
    }
  }

  void _scrollCategoryChipsToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_categoryScrollController.hasClients) return;
      final categoryList = _buildCategoryList();
      if (categoryList.length <= 5) return;
      final itemWidth = 80.0;
      final totalItemWidth = itemWidth + 16.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset = (index * totalItemWidth) - (screenWidth / 2) + (itemWidth / 2);
      final maxScroll = _categoryScrollController.position.maxScrollExtent;
      final clamped = targetOffset.clamp(0.0, maxScroll);
      final distance = (clamped - _categoryScrollController.offset).abs();
      _categoryScrollController.animateTo(
        clamped,
        duration: distance < 100 ? const Duration(milliseconds: 180) : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 300) return;
    if (v < -300 && _currentIndex < _displayedItems.length - 1) _currentIndex++;
    else if (v > 300 && _currentIndex > 0) _currentIndex--;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    if (v < -250) _switchToNextCategory();
    else if (v > 250) _switchToPreviousCategory();
  }

  void _switchToNextCategory() {
    final categoryList = _buildCategoryList();
    if (categoryList.isEmpty) return;
    int ci = categoryList.indexWhere((c) => c['id'] == _selectedCategoryId);
    if (ci != -1 && ci == categoryList.length - 1) _onTabChanged(3);
    else if (ci != -1 && ci < categoryList.length - 1) _selectCategory(categoryList[ci + 1]['id']);
  }

  void _switchToPreviousCategory() {
    final categoryList = _buildCategoryList();
    if (categoryList.isEmpty) return;
    int ci = categoryList.indexWhere((c) => c['id'] == _selectedCategoryId);
    if (ci == 0) _onTabChanged(0);
    else if (ci > 0) _selectCategory(categoryList[ci - 1]['id']);
  }

  void _onTabChanged(int index) {
    // Video tab सोडताना सगळे videos stop
    if (_selectedTabIndex == 0 && index != 0) {
      _stopAllVideos();
    }

    final now = DateTime.now();
    final wasDoubleTap = _lastTappedTabIndex == index &&
        _lastTabTapTime != null &&
        now.difference(_lastTabTapTime!) < Duration(milliseconds: 300);
    if (wasDoubleTap) { _handleTabSpecificRefresh(index); return; }
    _lastTabTapTime = now;
    _lastTappedTabIndex = index;
    final categoryList = _buildCategoryList();
    int targetPage = index == 0 ? 0 : index == 1 ? 1 : index == 3 ? categoryList.length + 1 : 1;
    if (_selectedTabIndex != index) {
      setState(() { _selectedTabIndex = index; _selectedCategoryId = null; });
      _updateDisplayedItems();
    }
    if (_horizontalPageController.hasClients) _horizontalPageController.jumpToPage(targetPage);
  }

  Future<void> _handleTabSpecificRefresh(int tabIndex) async {
    setState(() => _isRefreshing = true);
    try {
      if (tabIndex == 0) {
        // सगळे videos stop करा
        _stopAllVideos();
        // Page 0 ला jump करा — नवीन list येणार म्हणून
        _currentVideoPage = 0;
        if (_videoPageController.hasClients) {
          _videoPageController.jumpToPage(0);
        }
        // Keys clear — नवीन widgets येतील
        _videoKeys.clear();
        _videoReadyStates.clear();
        await _loadVideoPosts();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ Videos refreshed!'), duration: Duration(seconds: 1), backgroundColor: Colors.green),
        );
      } else if (tabIndex == 1) {
        _preloadedImages.clear(); _allArticles.clear(); _nextCursor = null; _hasMore = true;
        await _loadArticles(isInitial: true);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ News refreshed!'), duration: Duration(seconds: 1), backgroundColor: Colors.green));
      } else if (tabIndex == 2) {
        await _loadSocialPosts();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Posts refreshed!'), duration: Duration(seconds: 1), backgroundColor: Colors.green));
      } else if (tabIndex == 3) {
        await _loadProfileData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✨ Profile refreshed!'), duration: Duration(seconds: 1), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refresh failed.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _onHorizontalPageChanged(int pageIndex) {
    // Video tab सोडताना सगळे stop
    if (pageIndex != 0) {
      _stopAllVideos();
    }

    final previousPage = _previousPageIndex ?? pageIndex;
    _previousPageIndex = pageIndex;
    final categoryList = _buildCategoryList();
    final totalNewsPages = categoryList.length;
    final profilePageIndex = totalNewsPages + 1;
    int newTabIndex;
    int? newCategoryId;
    int? categoryIndexToScroll;

    if (pageIndex == 0) {
      newTabIndex = 0; newCategoryId = null;
    } else if (pageIndex >= 1 && pageIndex <= totalNewsPages) {
      newTabIndex = 1;
      final categoryIndex = pageIndex - 1;
      if (previousPage == profilePageIndex) {
        newCategoryId = null; categoryIndexToScroll = 0;
        Future.delayed(Duration.zero, () {
          if (mounted && _horizontalPageController.hasClients) {
            _horizontalPageController.jumpToPage(1);
            _previousPageIndex = 1;
            _scrollCategoryChipsToIndex(0);
          }
        });
      } else {
        newCategoryId = categoryList[categoryIndex]['id'];
        final prevCatIdx = previousPage >= 1 && previousPage <= totalNewsPages ? previousPage - 1 : null;
        if (prevCatIdx != categoryIndex) categoryIndexToScroll = categoryIndex;
      }
    } else if (pageIndex == profilePageIndex) {
      newTabIndex = 3; newCategoryId = null;
      if (_selectedTabIndex != 3) _loadProfileData();
    } else {
      newTabIndex = 1; newCategoryId = null;
    }

    if (newTabIndex != _selectedTabIndex || newCategoryId != _selectedCategoryId) {
      setState(() { _selectedTabIndex = newTabIndex; _selectedCategoryId = newCategoryId; });
      _updateDisplayedItems();
    }
    if (categoryIndexToScroll != null) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _categoryScrollController.hasClients) _scrollCategoryChipsToIndex(categoryIndexToScroll!);
      });
    }
    if (_displayedItems.isNotEmpty && mounted) _preloadImages(_displayedItems, 0);

    // Video tab ला आलो → current video play
    if (pageIndex == 0 && _videoPosts.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _playOnlyCurrentVideo();
      });
    }
  }

  int _getTotalPageCount() => 1 + _buildCategoryList().length + 1;

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message), backgroundColor: Colors.red,
      duration: const Duration(seconds: 2),
      action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _loadInitialData),
    ));
  }

  void _shareArticle(Map<String, dynamic> article) {
    final title = article['title'] ?? '';
    final summary = article['content'] ?? '';
    final url = article['source_url'] ?? '';
    Share.share('🗞 joy scroll!\n$title\n${summary.length > 100 ? summary.substring(0, 100) + '...' : summary}\n${url.isNotEmpty ? '🔗 $url' : ''}');
  }

  Future<void> _toggleLike(Map<String, dynamic> post) async {
    final postId = int.parse(post['id']);
    final bool wasLiked = post['isLiked'];
    final int currentLikes = post['likes'];
    setState(() { post['isLiked'] = !wasLiked; post['likes'] = wasLiked ? currentLikes - 1 : currentLikes + 1; });
    try {
      final response = wasLiked ? await SocialApiService.unlikePost(postId) : await SocialApiService.likePost(postId);
      if (response['status'] == 'success') {
        if (!wasLiked) PreferencesService.saveLikedPost(postId);
        else PreferencesService.removeLikedPost(postId);
        if (response['likes_count'] != null && mounted) setState(() => post['likes'] = response['likes_count']);
      } else {
        if (mounted) setState(() { post['isLiked'] = wasLiked; post['likes'] = currentLikes; });
      }
    } catch (e) {
      if (mounted) setState(() { post['isLiked'] = wasLiked; post['likes'] = currentLikes; });
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final diff = DateTime.now().difference(DateTime.parse(timestamp));
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (e) { return 'Just now'; }
  }

  void _showFullImageDialog(BuildContext context, String imageUrl) {
    showDialog(context: context, barrierColor: Colors.black87, builder: (context) => Dialog(
      backgroundColor: Colors.transparent, insetPadding: EdgeInsets.zero,
      child: Stack(children: [
        Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0,
            child: CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.contain,
                placeholder: (c, u) => const CircularProgressIndicator(),
                errorWidget: (c, u, e) => const Icon(Icons.error, color: Colors.white)))),
        Positioned(top: 40, right: 16, child: IconButton(
            icon: Container(padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 24)),
            onPressed: () => Navigator.pop(context))),
      ]),
    ));
  }

  void _navigateToArticle(int articleId) {
    final index = _displayedItems.indexWhere((item) => item['type'] == 'article' && item['id'] == articleId);
    if (index != -1) setState(() => _currentIndex = index);
  }

  Future<void> _trackArticleRead(Map<String, dynamic> article) async {
    try {
      final articleId = article['id'];
      if (articleId == null) return;
      try { await UserService.addToHistoryWithNewEntry(articleId); } catch (e) {}
      if (mounted) setState(() => _articlesReadCount++);
    } catch (e) {}
  }

  List<Map<String, dynamic>> _buildCategoryList() {
    final List<Map<String, dynamic>> list = [{'id': null, 'name': 'All'}];
    if (_selectedCategoryIds.isNotEmpty) {
      for (var id in _selectedCategoryIds) {
        if (_categoryMap.containsKey(id)) list.add({'id': id, 'name': _categoryMap[id]!});
      }
    } else {
      list.addAll(_categoryMap.entries.map((e) => {'id': e.key, 'name': e.value}).toList());
    }
    return list;
  }

  Future<void> _editProfile() async {
    if (_userProfile == null) return;
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (c) => EditProfileScreen(userProfile: _userProfile!)));
    if (result == true && mounted) await _loadProfileData();
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(context: context, applicationName: 'Joy Scroll App', applicationVersion: '1.0.0',
        applicationIcon: Container(width: 56, height: 56,
            decoration: const BoxDecoration(color: Color(0xFF68BB59), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Colors.white, size: 32)),
        children: const [Padding(padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Bringing you positive, AI-powered news stories that brighten your day.', textAlign: TextAlign.center))]);
  }

  Widget _buildSectionCard(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
        boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildArticlesReadCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    return GestureDetector(
      onTap: () async {
        try {
          final result = await Navigator.of(context).push(MaterialPageRoute(builder: (c) => const ReadingHistoryScreen()));
          if (result != null && result is Map && result['action'] == 'read_article' && mounted) {
            _horizontalPageController.animateToPage(1, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
            setState(() { _selectedTabIndex = 1; _selectedCategoryId = null; });
            Future.delayed(Duration(milliseconds: 400), () { if (mounted) _navigateToArticle(result['article_id']); });
          }
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open Reading History'), backgroundColor: Colors.red));
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
        constraints: const BoxConstraints(maxWidth: 600),
        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: isSmallScreen ? 16 : 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
          boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryColor.withOpacity(0.2), primaryColor.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.article_outlined, color: primaryColor, size: isSmallScreen ? 24 : 28)),
          SizedBox(width: isSmallScreen ? 14 : 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Articles Read', style: theme.textTheme.bodyLarge?.copyWith(color: (isDark ? Colors.white : theme.colorScheme.onSurface).withOpacity(0.85), fontWeight: FontWeight.w500, fontSize: isSmallScreen ? 14 : 16)),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text('$_articlesReadCount', style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: primaryColor, fontSize: isSmallScreen ? 28 : 32)),
          ])),
          Icon(Icons.arrow_forward_ios, size: isSmallScreen ? 16 : 18, color: primaryColor.withOpacity(0.8)),
        ]),
      ),
    );
  }

  Widget _buildMenuList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)),
        boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildMenuItem(context, title: 'Reading History', icon: Icons.history, isFirst: true, onTap: () async {
          try {
            final result = await Navigator.of(context).push(MaterialPageRoute(builder: (c) => const ReadingHistoryScreen()));
            if (result != null && result is Map && result['action'] == 'read_article' && mounted) {
              _horizontalPageController.animateToPage(1, duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
              setState(() { _selectedTabIndex = 1; _selectedCategoryId = null; });
              Future.delayed(Duration(milliseconds: 400), () { if (mounted) _navigateToArticle(result['article_id']); });
            }
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open Reading History'), backgroundColor: Colors.red));
          }
        }),
        _buildDivider(isDark),
        _buildMenuItem(context, title: 'Settings', icon: Icons.settings_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => const SettingsScreen()))),
        _buildDivider(isDark),
        _buildMenuItem(context, title: 'About', icon: Icons.info_outline, isLast: true, onTap: () => _showAboutDialog(context)),
      ]),
    );
  }

  Widget _buildMenuItem(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap, bool isFirst = false, bool isLast = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(top: isFirst ? const Radius.circular(16) : Radius.zero, bottom: isLast ? const Radius.circular(16) : Radius.zero),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(icon, color: isDark ? Colors.white70 : Colors.black87, size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
            Icon(Icons.chevron_right, color: isDark ? Colors.white38 : Colors.black38, size: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16), height: 1,
    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
  );

  Widget _buildProfilePage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    if (_isProfileLoading) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        CircularProgressIndicator(color: primaryColor), const SizedBox(height: 16),
        Text('Loading profile...', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[600], fontSize: isSmallScreen ? 14 : 16)),
      ]));
    }
    final displayName = _userProfile?['display_name'] ?? 'Good News Reader';
    final email = _userProfile?['email'] ?? 'No email available';
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
        child: Padding(padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Stack(alignment: Alignment.bottomRight, children: [
              CircleAvatar(radius: isSmallScreen ? 50 : 60, backgroundColor: primaryColor.withOpacity(0.15),
                  child: Text(displayName[0].toUpperCase(), style: TextStyle(fontSize: isSmallScreen ? 32 : 40, color: primaryColor, fontWeight: FontWeight.bold))),
              Positioned(bottom: 4, right: 4, child: GestureDetector(onTap: _editProfile,
                  child: Container(padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                      decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                      child: Icon(Icons.edit, size: isSmallScreen ? 16 : 18, color: Colors.white)))),
            ]),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Text(displayName, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontSize: isSmallScreen ? 20 : 24), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.75), fontSize: isSmallScreen ? 13 : 14), textAlign: TextAlign.center),
          ]),
        ),
      ))),
      SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 20 : 28)),
      SliverToBoxAdapter(child: _isStatsLoading ? Center(child: CircularProgressIndicator(color: primaryColor)) : _buildArticlesReadCard()),
      SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 20 : 28)),
      SliverToBoxAdapter(child: _buildMenuList(context)),
      SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 30 : 40)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final categoryList = _buildCategoryList();
    return Scaffold(
      body: SafeArea(child: _buildMainContent(categoryList)),
      floatingActionButton: _showFab && _selectedTabIndex == 2 ? SpeedDialFAB(actions: []) : null,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBottomNavigationBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    return Container(
      height: isSmallScreen ? 60 : 65,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(top: false, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        _buildNavItem(icon: Icons.video_library_outlined, activeIcon: Icons.video_library, label: 'Video', isActive: _selectedTabIndex == 0, onTap: () => _onTabChanged(0), onDoubleTap: () => _handleTabSpecificRefresh(0)),
        _buildNavItem(icon: Icons.article_outlined, activeIcon: Icons.article, label: 'News', isActive: _selectedTabIndex == 1, onTap: () => _onTabChanged(1), onDoubleTap: () => _handleTabSpecificRefresh(1)),
        _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', isActive: _selectedTabIndex == 3, onTap: () => _onTabChanged(3), onDoubleTap: () => _handleTabSpecificRefresh(3)),
      ])),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onDoubleTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSmallScreen = MediaQuery.of(context).size.width < 360;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 4 : 6),
          child: Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(isSmallScreen ? 5 : 7),
              decoration: BoxDecoration(
                color: isActive ? primaryColor.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isActive ? activeIcon : icon,
                color: isActive ? primaryColor : isDark ? Colors.white70 : Colors.grey[600],
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
                  color: isActive ? primaryColor : isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildMainContent(List<Map<String, dynamic>> categoryList) {
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
        itemCount: _getTotalPageCount(),
        onPageChanged: _onHorizontalPageChanged,
        itemBuilder: (context, pageIndex) {
          final totalNewsPages = categoryList.length;
          if (pageIndex == 0) return _buildVideoTabContent();
          if (pageIndex >= 1 && pageIndex <= totalNewsPages) {
            final category = categoryList[pageIndex - 1];
            final categoryId = category['id'];
            final filteredArticles = categoryId == null
                ? _allArticles
                : _allArticles.where((a) => a['category_id'] == categoryId).toList();
            return _buildNewsTabContent(
              categoryName: category['name'], items: filteredArticles,
              showEmptyState: filteredArticles.isEmpty && !_isLoadingMore && !_isInitialLoading,
              categoryList: categoryList, activeCategoryIndex: pageIndex - 1,
            );
          }
          if (pageIndex == totalNewsPages + 1) return _buildProfilePage();
          return Container();
        },
      ),
    );
  }

  Widget _buildVideoTabContent() {
    return _buildVideoFeedContent(items: _videoPosts);
  }

  Widget _buildNewsTabContent({required String categoryName, required List<Map<String, dynamic>> items, required bool showEmptyState, required List<Map<String, dynamic>> categoryList, required int activeCategoryIndex}) {
    return Column(children: [
      Container(
        height: 50, padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]),
        child: ListView.builder(
          controller: _categoryScrollController, scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categoryList.length,
          itemBuilder: (context, index) {
            final category = categoryList[index];
            final isSelected = index == activeCategoryIndex;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final primaryColor = Theme.of(context).colorScheme.primary;
            return Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () { _selectCategory(category['id']); _scrollCategoryChipsToIndex(index); },
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(category['name'], style: TextStyle(
                      color: isSelected ? primaryColor : isDark ? Colors.white60 : Colors.grey[600],
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: isSelected ? 15 : 13)),
                  if (isSelected) Padding(padding: const EdgeInsets.only(top: 4),
                      child: Container(height: 2.5, width: 30,
                          decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(1.5)))),
                ]),
              ),
            );
          },
        ),
      ),
      Expanded(child: GestureDetector(
        onVerticalDragEnd: _onVerticalDragEnd, onHorizontalDragEnd: _onHorizontalDragEnd,
        child: _isLoadingMore && items.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 3),
          const SizedBox(height: 16),
          Text('Loading articles...', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.grey[600], fontSize: 14)),
        ]))
            : PageView.builder(
          scrollDirection: Axis.vertical, physics: const ClampingScrollPhysics(),
          itemCount: items.isEmpty && showEmptyState ? 1 : items.length,
          itemBuilder: (context, index) {
            if (items.isEmpty && showEmptyState) return _buildEmptyStateForTab(categoryName);
            return _buildArticle(items[index]);
          },
        ),
      )),
    ]);
  }

  Widget _buildVideoFeedContent({required List<Map<String, dynamic>> items}) {
    if (_isVideoLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            SizedBox(height: 16),
            Text('Loading videos...', style: TextStyle(color: Colors.white60, fontSize: 14)),
          ]),
        ),
      );
    }

    if (items.isEmpty) return _buildEmptyStateForTab('Video');

    // Total items = videos + (hasMore असेल तर 1 loader page)
    final totalCount = items.length + (_videoHasMore ? 1 : 0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Horizontal left swipe → news tab
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -250) {
          _stopAllVideos();
          _horizontalPageController.animateToPage(
            1, duration: const Duration(milliseconds: 280), curve: Curves.easeOut,
          );
        }
      },
      // Vertical swipe → instant video switch
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200) {
          if (_currentVideoPage < items.length - 1) {
            _switchVideoInstant(_currentVideoPage + 1, items);
          } else if (_videoHasMore && !_videoLoadingMore) {
            // शेवटच्या video वर आहे पण more आहेत → load trigger
            _loadMoreVideos();
          }
        } else if (v > 200 && _currentVideoPage > 0) {
          _switchVideoInstant(_currentVideoPage - 1, items);
        }
      },
      child: PageView.builder(
        controller: _videoPageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          // Last page = loader (जेव्हा hasMore true आहे)
          if (index >= items.length) {
            return Container(
              color: Colors.black,
              child: const Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                  SizedBox(height: 12),
                  Text('Loading more videos...', style: TextStyle(color: Colors.white38, fontSize: 13)),
                ]),
              ),
            );
          }
          return _buildVideoPost(items[index]);
        },
      ),
    );
  }

  /// Instant video switch — कोणतीही animation नाही
  void _switchVideoInstant(int targetPage, List<Map<String, dynamic>> items) {
    if (targetPage < 0 || targetPage >= items.length) return;
    if (targetPage == _currentVideoPage) return;

    final prevId = items[_currentVideoPage]['id'] as String;
    final nextId = items[targetPage]['id'] as String;

    // 1. जुना video audio cut
    _videoKeys[prevId]?.currentState?.hardStop();

    // 2. Instant jump — NO animation
    _videoPageController.jumpToPage(targetPage);
    _currentVideoPage = targetPage;

    // 3. Next frame मध्ये new video play
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _videoKeys[nextId]?.currentState?.forcePlay();
    });

    // 4. ─── PAGINATION TRIGGER ───────────────────────────────────────────
    // शेवटापासून _kVideoPreloadAt videos बाकी असताना background load
    final remaining = items.length - 1 - targetPage;
    if (remaining <= _kVideoPreloadAt && _videoHasMore && !_videoLoadingMore) {
      _loadMoreVideos();
    }
    // ─────────────────────────────────────────────────────────────────────
  }

  Widget _buildArticle(Map<String, dynamic> article) => RepaintBoundary(child: ArticleCardWidget(article: article, onTrackRead: _trackArticleRead, onShare: _shareArticle));

  Widget _buildVideoPost(Map<String, dynamic> post) {
    final key = _videoKeys.putIfAbsent(post['id'], () => GlobalKey<_VideoPostWidgetState>());
    return RepaintBoundary(
      child: _VideoPostWidget(
        key: key,
        post: post,
        onToggleLike: () => _toggleLike(post),
        onToggleComments: () {},
        onShare: () => _shareArticle(post),
        onVideoReady: () {
          if (mounted) {
            setState(() => _videoReadyStates[post['id'] as String] = true);
            // Video ready झाला — जर हा current page असेल तर play
            if (_videoPosts.isNotEmpty &&
                _currentVideoPage < _videoPosts.length &&
                _videoPosts[_currentVideoPage]['id'] == post['id']) {
              _videoKeys[post['id']]?.currentState?.forcePlay();
            }
          }
        },
      ),
    );
  }

  Widget _buildEmptyStateForTab(String tabName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String message, subMessage, buttonText;
    IconData icon = Icons.info_outline;
    IconData buttonIcon = Icons.refresh;
    VoidCallback? onPressed;
    if (tabName == 'Video') {
      message = 'No videos yet!'; subMessage = 'Videos will appear here soon!'; icon = Icons.video_library_outlined;
      onPressed = () => _loadVideoPosts(); buttonText = 'Retry';
    } else if (tabName == 'News' || tabName == 'All') {
      message = 'No articles yet!'; subMessage = _hasMore ? 'Loading...' : 'Try a different category.'; icon = Icons.article_outlined;
      onPressed = () => _handleTabSpecificRefresh(1); buttonText = 'Refresh';
    } else {
      message = 'No articles in $tabName'; subMessage = 'Try another category.'; icon = Icons.category_outlined;
      onPressed = () => _selectCategory(null); buttonText = 'View All';
    }
    return Container(
      color: tabName == 'Video' ? Colors.black : null,
      child: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 64, color: tabName == 'Video' ? Colors.white38 : isDark ? Colors.white38 : Colors.grey[400]),
        const SizedBox(height: 16),
        Text(message, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: tabName == 'Video' ? Colors.white70 : isDark ? Colors.white70 : Colors.grey[600]), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(subMessage, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tabName == 'Video' ? Colors.white54 : isDark ? Colors.white54 : Colors.grey[500]), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (onPressed != null) ElevatedButton.icon(onPressed: onPressed, icon: Icon(buttonIcon), label: Text(buttonText),
            style: ElevatedButton.styleFrom(
                backgroundColor: tabName == 'Video' ? Colors.white : Theme.of(context).colorScheme.primary,
                foregroundColor: tabName == 'Video' ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
      ]))),
    );
  }
}

// ==================== VIDEO POST WIDGET ====================

class _VideoPostWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleComments;
  final VoidCallback onShare;
  final VoidCallback? onVideoReady;
  const _VideoPostWidget({
    required this.post,
    required this.onToggleLike,
    required this.onToggleComments,
    required this.onShare,
    this.onVideoReady,
    Key? key,
  }) : super(key: key);
  @override
  State<_VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<_VideoPostWidget>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  YoutubePlayerController? _ytController;
  bool _isInitialized = false;
  bool _hasError      = false;
  bool _tracked       = false;
  bool _isPlaying     = false;
  bool _showThumbnail = true;
  bool _isPlayerReady = false;
  bool _isBuffering   = false;

  // ─── हे flag आहे: controller initialized झाल्यावरच play/pause accept करा ───
  bool _canControl    = false;

  @override
  void initState() {
    super.initState();
    _initYouTube();
  }

  void _initYouTube() {
    final videoId = widget.post['video_id'] as String?;
    if (videoId == null || videoId.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    try {
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          // ── autoPlay: FALSE — HomeScreen onPageChanged control करतो ──
          autoPlay: false,
          mute: false,
          hideControls: true,
          hideThumbnail: true,
          disableDragSeek: true,
          loop: true,
          enableCaption: false,
          forceHD: true,
          useHybridComposition: true,
        ),
      );
      _ytController!.addListener(_onPlayerStateChanged);
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onPlayerStateChanged() {
    if (!mounted) return;
    final value = _ytController?.value;
    if (value == null) return;

    final isPlaying   = value.isPlaying;
    final isBuffering = value.playerState == PlayerState.buffering;

    if (_isPlaying != isPlaying || _isBuffering != isBuffering) {
      setState(() {
        _isPlaying   = isPlaying;
        _isBuffering = isBuffering;
        if (isPlaying) _showThumbnail = false;
      });
    }
  }

  // ─── HomeScreen call करतो: current video play ───
  // ─── HomeScreen: current video play + volume restore ───
  void forcePlay() {
    if (_ytController == null || !_canControl) return;
    _ytController!.setVolume(100); // hardStop ने mute केलेले unmute
    _ytController!.play();
  }

  // ─── HomeScreen: tab/swipe बदलताना INSTANT audio cut ───
  // setVolume(0) = guaranteed silent in <1 frame
  // load() वापरत नाही — race condition + unnecessary reload होतो
  void hardStop() {
    if (_ytController == null) return;
    _ytController!.setVolume(0); // तात्काळ mute
    _ytController!.pause();
    if (mounted) {
      setState(() { _showThumbnail = true; _isPlaying = false; _isBuffering = false; });
    }
    // Position reset — पुढच्या forcePlay() ला beginning पासून start
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _ytController != null) {
        _ytController!.seekTo(Duration.zero);
      }
    });
  }

  // ─── User tap: play ↔ pause toggle ───
  void _onVideoTap() {
    if (_ytController == null || !_canControl) return;
    if (_isPlaying) {
      _ytController!.pause();
    } else {
      _ytController!.play();
    }
  }

  void _trackWatch() {
    if (_tracked) return;
    _tracked = true;
    final apiId = widget.post['api_id'];
    if (apiId != null) ApiService.trackVideoWatch(apiId as int, 0, false);
  }

  @override
  void dispose() {
    _ytController?.removeListener(_onPlayerStateChanged);
    _ytController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // VisibilityDetector REMOVE केला — तो unreliable आहे YouTubePlayer WebView मध्ये
    // Control आता फक्त HomeScreen च्या onPageChanged + explicit methods मधून
    return SizedBox.expand(
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [

            // 1. VIDEO PLAYER
            if (!_hasError && _isInitialized && _ytController != null)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: true,
                  child: YoutubePlayer(
                    controller: _ytController!,
                    showVideoProgressIndicator: false,
                    onReady: () {
                      if (mounted) {
                        _canControl = true; // ← आता control safe आहे
                        setState(() => _isPlayerReady = true);
                        widget.onVideoReady?.call();
                        // onReady वर auto-play नाही — HomeScreen decide करतो
                        // (जर हा current page असेल तर HomeScreen forcePlay() call करतो)
                      }
                    },
                    onEnded: (_) {
                      // Loop: video संपल्यावर reload न करता seekTo(0) + play
                      _ytController?.seekTo(Duration.zero);
                      _ytController?.play();
                    },
                  ),
                ),
              )
            else if (_hasError)
              _buildErrorWidget()
            else
              _buildThumbnail(),

            // 2. THUMBNAIL OVERLAY — video play होईपर्यंत दाखवा
            if (_showThumbnail && !_isPlaying)
              Positioned.fill(child: _buildThumbnail()),

            // 3. LOADING OVERLAY
            // फक्त: player ready नाही किंवा actual YouTube buffering
            if ((!_isPlayerReady && !_hasError && _isInitialized) || _isBuffering)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.45),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),

            // 4. TOP GRADIENT
            Positioned(top: 0, left: 0, right: 0,
                child: Container(height: 140,
                    decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0xCC000000), Colors.transparent])))),

            // 5. BOTTOM GRADIENT
            Positioned(bottom: 0, left: 0, right: 0,
                child: Container(height: 280,
                    decoration: const BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.bottomCenter, end: Alignment.topCenter,
                        colors: [Color(0xDD000000), Color(0x88000000), Colors.transparent])))),

            // 6. BOTTOM INFO + ACTION BUTTONS
            Positioned(bottom: 24, left: 16, right: 16,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Container(width: 36, height: 36,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2), color: Colors.white24),
                          child: Center(child: Text(widget.post['avatar'] as String? ?? 'J',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
                      const SizedBox(width: 8),
                      Flexible(child: Text(
                          (widget.post['author'] as String? ?? '').isNotEmpty
                              ? '@' + (widget.post['author'] as String)
                              : '@JoyScroll',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 10),
                    Text(widget.post['title'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.3,
                            shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if ((widget.post['content'] ?? '').isNotEmpty)
                      Text(widget.post['content'] ?? '',
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(children: [
                      Text(_formatTimestamp(widget.post['created_at']),
                          style: const TextStyle(color: Colors.white54, fontSize: 12)),
                      if ((widget.post['category'] ?? '').isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: Colors.white12,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24, width: 0.5)),
                            child: Text(widget.post['category'],
                                style: const TextStyle(color: Colors.white70, fontSize: 11))),
                      ],
                    ]),
                  ])),
                  const SizedBox(width: 16),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    _buildActionButton(
                        icon: widget.post['isLiked'] == true ? Icons.favorite : Icons.favorite_border,
                        label: _formatCount(widget.post['likes'] ?? 0),
                        color: widget.post['isLiked'] == true ? Colors.red : Colors.white,
                        onTap: widget.onToggleLike),
                    const SizedBox(height: 20),
                    _buildActionButton(icon: Icons.chat_bubble_outline_rounded, label: 'Comment',
                        color: Colors.white, onTap: widget.onToggleComments),
                    const SizedBox(height: 20),
                    _buildActionButton(icon: Icons.share_rounded, label: 'Share',
                        color: Colors.white, onTap: widget.onShare),
                  ]),
                ])),

            // 7. TAP OVERLAY — play / pause toggle
            Positioned.fill(
              child: GestureDetector(
                onTap: _onVideoTap,
                behavior: HitTestBehavior.translucent,
                child: const SizedBox.expand(),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbUrl = widget.post['thumbnail_url'] as String? ?? '';
    if (thumbUrl.isNotEmpty) {
      return CachedNetworkImage(imageUrl: thumbUrl, fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: Colors.black,
              child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))),
          errorWidget: (_, __, ___) => Container(color: Colors.black));
    }
    return Container(color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2)));
  }

  Widget _buildErrorWidget() => Container(color: Colors.black,
      child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, color: Colors.white54, size: 48), SizedBox(height: 12),
        Text('Video not available', style: TextStyle(color: Colors.white54, fontSize: 14)),
      ])));

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500,
            shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
      ]),
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
      final diff = DateTime.now().difference(DateTime.parse(timestamp));
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${(diff.inDays / 7).floor()}w ago';
    } catch (e) { return 'Just now'; }
  }
}