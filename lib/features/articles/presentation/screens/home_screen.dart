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
import 'package:good_news/core/services/app_info_service.dart';
import '../../../../widgets/speed_dial_fab.dart';
import '../widgets/video_reel_widget.dart';

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

  // ΓöÇΓöÇΓöÇ Video Pagination ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ
  // Γ£à FIX 1: 100 ΓåÆ 20 (αñ¬αñ╣αñ┐αñ▓αÑç αñ½αñòαÑìαññ 20 videos load, UI αñ▓αñùαÑçαñÜ αñªαñ┐αñ╕αÑçαñ▓)
  static const int _kVideoPageSize = 20; // ΓåÉ WAS 100
  int _videoOffset = 0;
  bool _videoHasMore = true;
  bool _videoLoadingMore = false;
  bool _videoAllLoaded = false;
  // ΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇΓöÇ

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;
  bool _isProfileLoading = true;
  int _articlesReadCount = 0;
  bool _isStatsLoading = true;

  final Set<dynamic> _readArticleIds = {};

  List<Map<String, dynamic>> _friends = [];
  bool _isFriendsLoading = true;
  int _friendRequestsCount = 0;
  bool _isFriendRequestsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _categoryScrollController = ScrollController();
    _selectedTabIndex = 1;
    _horizontalPageController = PageController(initialPage: 1);
    _videoPageController = PageController(keepPage: false, initialPage: 0);
    _previousPageIndex = 1;
    _refreshUserDisplayName();
    _loadInitialData();
    _loadProfileData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
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
      } else if ((item['type'] == 'social_post' ||
          item['type'] == 'video_post') &&
          item['image_url'] != null) {
        imageUrl = item['image_url'];
      }
      if (imageUrl != null &&
          imageUrl.isNotEmpty &&
          !_preloadedImages.contains(imageUrl)) {
        _preloadedImages.add(imageUrl);
        try {
          await precacheImage(
            CachedNetworkImageProvider(imageUrl,
                cacheKey: imageUrl, maxWidth: 600, maxHeight: 600),
            context,
          );
        } catch (e) {}
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
      if (categoryResponse['status'] == 'success' &&
          categoryResponse['categories'] != null) {
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
      _loadVideoPosts();
      await Future.wait([
        _loadArticles(isInitial: true),
        _loadSocialPosts(),
      ]);
      _updateDisplayedItems();
      if (_displayedItems.isNotEmpty && mounted) {
        _preloadImages(_displayedItems, 0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollCategoryChipsToIndex(0);
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
      await Future.wait([
        _loadUserProfile(),
        _loadUserStats(),
        _loadFriends(),
        _loadFriendRequestsCount()
      ]);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load profile'),
            backgroundColor: Colors.red));
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
      if (mounted)
        setState(() {
          _friendRequestsCount = 0;
          _isFriendRequestsLoading = false;
        });
    }
  }

  Future<void> _loadArticles({bool isInitial = false}) async {
    if (_isLoadingMore) return;
    try {
      if (mounted) setState(() => _isLoadingMore = true);
      if (isInitial) {
        final categoryIds = [null, ..._categoryMap.keys];
        final responses = await Future.wait(categoryIds.map((categoryId) =>
            ApiService.getUnifiedFeed(
                limit: 9999, cursor: null, categoryId: categoryId)));
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
        final lists =
        categoryArticles.values.where((l) => l.isNotEmpty).toList();
        int maxLen =
        lists.fold(0, (max, l) => l.length > max ? l.length : max);
        for (int i = 0; i < maxLen; i++) {
          for (final list in lists) {
            if (i < list.length) interleaved.add(list[i]);
          }
        }
        final seen = <dynamic>{};
        final unique = interleaved.where((a) => seen.add(a['id'])).toList();
        if (mounted)
          setState(() {
            _allArticles = unique;
            _hasMore = false;
            _nextCursor = null;
          });
      }
    } catch (e) {
      debugPrint('Γ¥î Articles load error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadSocialPosts() async {
    try {
      final response = await SocialApiService.getPosts();
      if (response['status'] == 'success') {
        final postsList = response['posts'] as List;
        final List<int> locallyLikedPosts =
        await PreferencesService.getLikedPosts();
        if (mounted)
          setState(() {
            _socialPosts = postsList
                .map((post) => _formatSocialPost(post, locallyLikedPosts))
                .toList();
          });
      }
    } catch (e) {
      debugPrint('Γ¥î Social posts error: $e');
    }
  }

  Map<String, dynamic> _formatSocialPost(
      Map<String, dynamic> post, List<int> locallyLikedPosts) {
    final authorName = post['display_name'] ?? 'Unknown';
    final postId = post['id'] is int
        ? post['id']
        : int.tryParse(post['id'].toString()) ?? 0;
    final apiLiked =
        post['user_has_liked'] == 1 || post['user_has_liked'] == true;
    return {
      'type': 'social_post',
      'id': postId.toString(),
      'author': authorName,
      'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
      'title': post['title'] ?? '',
      'content': post['content'] ?? '',
      'created_at': post['created_at'],
      'likes': post['likes_count'] ?? 0,
      'comments': post['comments_count'] ?? post['comments'] ?? 0,
      'isLiked': apiLiked || locallyLikedPosts.contains(postId),
      'image_url': post['image_url'],
      'user_id': post['user_id'] ?? post['author_id'],
    };
  }

  Map<String, dynamic> _mapVideo(Map<String, dynamic> v) {
    final rawAuthor = v['channel_name'] ??
        v['uploaded_by_name'] ??
        v['display_name'] ??
        v['user_display_name'] ??
        v['user_name'] ??
        v['username'] ??
        v['author'] ??
        v['author_name'] ??
        v['uploader'] ??
        v['uploader_name'] ??
        v['owner'] ??
        v['owner_name'] ??
        v['posted_by'] ??
        v['creator'] ??
        v['creator_name'] ??
        v['added_by'] ??
        v['uploaded_by'];
    final userId = v['user_id'];
    final authorName =
    (rawAuthor != null && rawAuthor.toString().isNotEmpty)
        ? rawAuthor.toString()
        : (userId != null ? 'User $userId' : 'Joy Scroll');
    return {
      'type': 'video_post',
      'id': v['id'].toString(),
      'api_id': v['id'],
      'author': authorName,
      'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'J',
      'user_id': userId,
      'title': v['title'] ?? '',
      'content': v['description'] ?? '',
      'created_at': v['created_at'] ??
          v['published_at'] ??
          v['publishedAt'] ??
          v['upload_date'] ??
          v['uploaded_at'] ??
          v['date'] ??
          v['publish_date'],
      'likes': v['like_count'] ?? 0,
      'isLiked': false,
      'video_id': v['video_id'],
      'thumbnail_url': v['thumbnail_url'] ?? '',
      'duration': v['duration'] ?? 0,
      'category': v['category'] ?? '',
    };
  }

  Future<void> _loadVideoPosts({int retryCount = 0}) async {
    if (!mounted) return;
    _videoOffset = 0;
    _videoHasMore = true;
    _videoLoadingMore = false;
    _videoAllLoaded = false;
    setState(() => _isVideoLoading = true);

    final stopwatch = Stopwatch()..start();

    try {
      final response = await ApiService.getVideoFeed(
        limit: _kVideoPageSize, // Γ£à 20
        offset: _videoOffset,
      );

      stopwatch.stop();
      debugPrint('ΓÅ▒∩╕Å Video API time: ${stopwatch.elapsedMilliseconds}ms');

      if (!mounted) return;

      if (response['status'] == 'success') {
        final raw = response['videos'] as List? ?? [];

        if (raw.isEmpty) {
          if (retryCount < 2) {
            await Future.delayed(const Duration(milliseconds: 500));
            return _loadVideoPosts(retryCount: retryCount + 1);
          }
          if (mounted)
            setState(() {
              _videoPosts = [];
              _isVideoLoading = false;
              _videoAllLoaded = true;
            });
          return;
        }

        final mapped =
        raw.map((v) => _mapVideo(v as Map<String, dynamic>)).toList();
        _videoOffset += mapped.length;
        _videoHasMore = response['has_more'] == true;

        if (mounted)
          setState(() {
            _videoPosts = mapped;
            _isVideoLoading = false;
          });

        // Γ£à scroll-based onLoadMore handles pagination ΓÇö no background loop needed
      } else {
        if (retryCount < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
          return _loadVideoPosts(retryCount: retryCount + 1);
        }
        if (mounted)
          setState(() {
            _videoPosts = [];
            _isVideoLoading = false;
            _videoAllLoaded = true;
          });
      }
    } catch (e) {
      stopwatch.stop();
      debugPrint('Γ¥î Video load error: $e (${stopwatch.elapsedMilliseconds}ms)');
      if (retryCount < 2 && mounted) {
        await Future.delayed(const Duration(milliseconds: 500));
        return _loadVideoPosts(retryCount: retryCount + 1);
      }
      if (mounted)
        setState(() {
          _videoPosts = [];
          _isVideoLoading = false;
          _videoAllLoaded = true;
        });
    }
  }


  // Γ£à FIXED: scroll trigger αñ¥αñ╛αñ▓αÑìαñ»αñ╛αñ╡αñ░ αñ¬αÑüαñóαñÜαÑç 20 videos fetch αñòαñ░αññαÑï
  Future<List<Map<String, dynamic>>?> _onVideoLoadMore(int page) async {
    // Guard: already loading or no more pages
    if (!_videoHasMore || _videoLoadingMore || !mounted) {
      debugPrint('ΓÅ¡∩╕Å onLoadMore skipped: hasMore=$_videoHasMore loading=$_videoLoadingMore');
      return null;
    }
    _videoLoadingMore = true;
    debugPrint('≡ƒôÑ Loading more videos: offset=$_videoOffset page=$page');

    try {
      final response = await ApiService.getVideoFeed(
        limit: _kVideoPageSize, // 20
        offset: _videoOffset,
      );

      if (!mounted) return null;

      if (response['status'] != 'success') {
        debugPrint('Γ¥î onVideoLoadMore: API error');
        return null;
      }

      final raw = response['videos'] as List? ?? [];
      debugPrint('≡ƒôª Got ${raw.length} videos at offset $_videoOffset');

      if (raw.isEmpty) {
        _videoHasMore = false;
        if (mounted) setState(() => _videoAllLoaded = true);
        return null;
      }

      final mapped =
      raw.map((v) => _mapVideo(v as Map<String, dynamic>)).toList();

      // Duplicate filter ΓÇö offset mismatch αñàαñ╕αÑçαñ▓ αññαñ░ safety net
      final existingIds = _videoPosts.map((p) => p['id']).toSet();
      final fresh =
      mapped.where((v) => !existingIds.contains(v['id'])).toList();

      _videoOffset += mapped.length;
      _videoHasMore = response['has_more'] == true;

      debugPrint('Γ£à Fresh: ${fresh.length}, hasMore: $_videoHasMore, newOffset: $_videoOffset');

      if (fresh.isNotEmpty && mounted) {
        setState(() => _videoPosts = [..._videoPosts, ...fresh]);
      }

      if (!_videoHasMore && mounted) {
        setState(() => _videoAllLoaded = true);
      }

      return fresh.isNotEmpty ? fresh : null;
    } catch (e) {
      debugPrint('Γ¥î onVideoLoadMore error: $e');
      return null;
    } finally {
      _videoLoadingMore = false;
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
          _displayedItems = _allArticles
              .where((a) => a['category_id'] == _selectedCategoryId)
              .toList();
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
    setState(() {
      _selectedTabIndex = 1;
      _selectedCategoryId = categoryId;
      _currentIndex = 0;
    });
    _updateDisplayedItems();
    if (categoryId != null) {
      final existing =
      _allArticles.where((a) => a['category_id'] == categoryId).toList();
      if (existing.isEmpty && _hasMore && !_isLoadingMore)
        _loadArticles(isInitial: false);
    }
    _scrollToCategoryPage(categoryId);
  }

  void _scrollToCategoryPage(int? categoryId) {
    final categoryList = _buildCategoryList();
    final index = categoryList.indexWhere((cat) => cat['id'] == categoryId);
    if (index != -1) {
      _horizontalPageController.animateToPage(1 + index,
          duration: Duration(milliseconds: 300), curve: Curves.easeInOut);
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
      final targetOffset =
          (index * totalItemWidth) - (screenWidth / 2) + (itemWidth / 2);
      final maxScroll = _categoryScrollController.position.maxScrollExtent;
      final clamped = targetOffset.clamp(0.0, maxScroll);
      final distance = (clamped - _categoryScrollController.offset).abs();
      _categoryScrollController.animateTo(
        clamped,
        duration: distance < 100
            ? const Duration(milliseconds: 180)
            : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 300) return;
    if (v < -300 && _currentIndex < _displayedItems.length - 1)
      _currentIndex++;
    else if (v > 300 && _currentIndex > 0) _currentIndex--;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    if (v.abs() < 250) return;
    if (v < -250)
      _switchToNextCategory();
    else if (v > 250) _switchToPreviousCategory();
  }

  void _switchToNextCategory() {
    final categoryList = _buildCategoryList();
    if (categoryList.isEmpty) return;
    int ci = categoryList.indexWhere((c) => c['id'] == _selectedCategoryId);
    if (ci != -1 && ci == categoryList.length - 1)
      _onTabChanged(3);
    else if (ci != -1 && ci < categoryList.length - 1)
      _selectCategory(categoryList[ci + 1]['id']);
  }

  void _switchToPreviousCategory() {
    final categoryList = _buildCategoryList();
    if (categoryList.isEmpty) return;
    int ci = categoryList.indexWhere((c) => c['id'] == _selectedCategoryId);
    if (ci == 0)
      _onTabChanged(0);
    else if (ci > 0) _selectCategory(categoryList[ci - 1]['id']);
  }

  void _onTabChanged(int index) {
    final now = DateTime.now();
    final wasDoubleTap = _lastTappedTabIndex == index &&
        _lastTabTapTime != null &&
        now.difference(_lastTabTapTime!) < Duration(milliseconds: 300);
    if (wasDoubleTap) {
      _handleTabSpecificRefresh(index);
      return;
    }
    _lastTabTapTime = now;
    _lastTappedTabIndex = index;
    final categoryList = _buildCategoryList();
    int targetPage = index == 0
        ? 0
        : index == 1
        ? 1
        : index == 3
        ? categoryList.length + 1
        : 1;
    if (_selectedTabIndex != index) {
      setState(() {
        _selectedTabIndex = index;
        _selectedCategoryId = null;
      });
      _updateDisplayedItems();
    }
    if (_horizontalPageController.hasClients)
      _horizontalPageController.jumpToPage(targetPage);
  }

  Future<void> _handleTabSpecificRefresh(int tabIndex) async {
    setState(() => _isRefreshing = true);
    try {
      if (tabIndex == 0) {
        await _loadVideoPosts();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Γ£¿ Videos refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green));
      } else if (tabIndex == 1) {
        _preloadedImages.clear();
        _allArticles.clear();
        _nextCursor = null;
        _hasMore = true;
        await _loadArticles(isInitial: true);
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Γ£¿ News refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green));
      } else if (tabIndex == 2) {
        await _loadSocialPosts();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Γ£¿ Posts refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green));
      } else if (tabIndex == 3) {
        await _loadProfileData();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Γ£¿ Profile refreshed!'),
              duration: Duration(seconds: 1),
              backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Refresh failed.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _onHorizontalPageChanged(int pageIndex) {
    final previousPage = _previousPageIndex ?? pageIndex;
    _previousPageIndex = pageIndex;
    final categoryList = _buildCategoryList();
    final totalNewsPages = categoryList.length;
    final profilePageIndex = totalNewsPages + 1;
    int newTabIndex;
    int? newCategoryId;
    int? categoryIndexToScroll;

    if (pageIndex == 0) {
      newTabIndex = 0;
      newCategoryId = null;
    } else if (pageIndex >= 1 && pageIndex <= totalNewsPages) {
      newTabIndex = 1;
      final categoryIndex = pageIndex - 1;
      if (previousPage == profilePageIndex) {
        newCategoryId = null;
        categoryIndexToScroll = 0;
        Future.delayed(Duration.zero, () {
          if (mounted && _horizontalPageController.hasClients) {
            _horizontalPageController.jumpToPage(1);
            _previousPageIndex = 1;
            _scrollCategoryChipsToIndex(0);
          }
        });
      } else {
        newCategoryId = categoryList[categoryIndex]['id'];
        final prevCatIdx = previousPage >= 1 && previousPage <= totalNewsPages
            ? previousPage - 1
            : null;
        if (prevCatIdx != categoryIndex) categoryIndexToScroll = categoryIndex;
      }
    } else if (pageIndex == profilePageIndex) {
      newTabIndex = 3;
      newCategoryId = null;
      if (_selectedTabIndex != 3) _loadProfileData();
    } else {
      newTabIndex = 1;
      newCategoryId = null;
    }

    if (newTabIndex != _selectedTabIndex ||
        newCategoryId != _selectedCategoryId) {
      setState(() {
        _selectedTabIndex = newTabIndex;
        _selectedCategoryId = newCategoryId;
      });
      _updateDisplayedItems();
    }
    if (categoryIndexToScroll != null) {
      Future.delayed(const Duration(milliseconds: 250), () {
        if (mounted && _categoryScrollController.hasClients)
          _scrollCategoryChipsToIndex(categoryIndexToScroll!);
      });
    }
    if (_displayedItems.isNotEmpty && mounted)
      _preloadImages(_displayedItems, 0);
  }

  int _getTotalPageCount() => 1 + _buildCategoryList().length + 1;

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 2),
      action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _loadInitialData),
    ));
  }

  void _shareArticle(Map<String, dynamic> article) {
    final title = article['title'] ?? '';
    final summary = article['content'] ?? '';
    final url = article['source_url'] ?? '';
    Share.share(
        '≡ƒù₧ joy scroll!\n$title\n${summary.length > 100 ? summary.substring(0, 100) + '...' : summary}\n${url.isNotEmpty ? '≡ƒöù $url' : ''}');
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
        if (!wasLiked)
          PreferencesService.saveLikedPost(postId);
        else
          PreferencesService.removeLikedPost(postId);
        if (response['likes_count'] != null && mounted)
          setState(() => post['likes'] = response['likes_count']);
      } else {
        if (mounted)
          setState(() {
            post['isLiked'] = wasLiked;
            post['likes'] = currentLikes;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          post['isLiked'] = wasLiked;
          post['likes'] = currentLikes;
        });
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
          child: Stack(children: [
            Center(
                child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (c, u) =>
                        const CircularProgressIndicator(),
                        errorWidget: (c, u, e) =>
                        const Icon(Icons.error, color: Colors.white)))),
            Positioned(
                top: 40,
                right: 16,
                child: IconButton(
                    icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 24)),
                    onPressed: () => Navigator.pop(context))),
          ]),
        ));
  }

  void _navigateToArticle(int articleId) {
    final index = _displayedItems.indexWhere(
            (item) => item['type'] == 'article' && item['id'] == articleId);
    if (index != -1) setState(() => _currentIndex = index);
  }

  Future<void> _trackArticleRead(Map<String, dynamic> article) async {
    try {
      final articleId = article['id'];
      if (articleId == null) return;
      if (_readArticleIds.contains(articleId)) return;
      _readArticleIds.add(articleId);
      await UserService.addToHistoryWithNewEntry(articleId);
      final history = await UserService.getHistory();
      if (mounted) setState(() => _articlesReadCount = history.length);
    } catch (e) {}
  }

  List<Map<String, dynamic>> _buildCategoryList() {
    final List<Map<String, dynamic>> list = [
      {'id': null, 'name': 'All'}
    ];
    if (_selectedCategoryIds.isNotEmpty) {
      for (var id in _selectedCategoryIds) {
        if (_categoryMap.containsKey(id))
          list.add({'id': id, 'name': _categoryMap[id]!});
      }
    } else {
      list.addAll(_categoryMap.entries
          .map((e) => {'id': e.key, 'name': e.value})
          .toList());
    }
    return list;
  }

  Future<void> _editProfile() async {
    if (_userProfile == null) return;
    final result = await Navigator.of(context).push(MaterialPageRoute(
        builder: (c) => EditProfileScreen(userProfile: _userProfile!)));
    if (result == true && mounted) await _loadProfileData();
  }

  void _showAboutDialog(BuildContext context) async {
    final version = await AppInfoService.getAppVersion();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: Color(0xFF68BB59), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Joy Scroll',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Version $version',
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 16),
            const Text(
              'Bringing you positive, AI-powered news stories that brighten your day.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
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
        await Navigator.of(context).push(
            MaterialPageRoute(builder: (c) => const ReadingHistoryScreen()));
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
        constraints: const BoxConstraints(maxWidth: 600),
        padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 20,
            vertical: isSmallScreen ? 16 : 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04)),
          boxShadow: [
            BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.2),
                        primaryColor.withOpacity(0.05)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.article_outlined,
                  color: primaryColor, size: isSmallScreen ? 24 : 28)),
          SizedBox(width: isSmallScreen ? 14 : 18),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Articles Read',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: (isDark
                                ? Colors.white
                                : theme.colorScheme.onSurface)
                                .withOpacity(0.85),
                            fontWeight: FontWeight.w500,
                            fontSize: isSmallScreen ? 14 : 16)),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text('$_articlesReadCount',
                        style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                            fontSize: isSmallScreen ? 28 : 32)),
                  ])),
          Icon(Icons.arrow_forward_ios,
              size: isSmallScreen ? 16 : 18,
              color: primaryColor.withOpacity(0.8)),
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
        border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : Colors.black.withOpacity(0.04)),
        boxShadow: [
          BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.2)
                  : Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        _buildMenuItem(context,
            title: 'Reading History',
            icon: Icons.history,
            isFirst: true,
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (c) => const ReadingHistoryScreen()));
            }),
        _buildDivider(isDark),
        _buildMenuItem(context,
            title: 'Settings',
            icon: Icons.settings_outlined,
            onTap: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute(builder: (c) => const SettingsScreen()));
              if (mounted) {
                _selectedCategoryIds =
                await PreferencesService.getSelectedCategories();
                _allArticles.clear();
                await _loadArticles(isInitial: true);
                _updateDisplayedItems();
              }
            }),
        _buildDivider(isDark),
        _buildMenuItem(context,
            title: 'About',
            icon: Icons.info_outline,
            isLast: true,
            onTap: () => _showAboutDialog(context)),
      ]),
    );
  }

  Widget _buildMenuItem(BuildContext context,
      {required String title,
        required IconData icon,
        required VoidCallback onTap,
        bool isFirst = false,
        bool isLast = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
            top: isFirst ? const Radius.circular(16) : Radius.zero,
            bottom: isLast ? const Radius.circular(16) : Radius.zero),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(icon,
                color: isDark ? Colors.white70 : Colors.black87, size: 24),
            const SizedBox(width: 16),
            Expanded(
                child: Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87))),
            Icon(Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black38, size: 24),
          ]),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    height: 1,
    color: isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.04),
  );

  Widget _buildProfilePage() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    if (_isProfileLoading) {
      return Center(
          child:
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            Text('Loading profile...',
                style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey[600],
                    fontSize: isSmallScreen ? 14 : 16)),
          ]));
    }
    final displayName = _userProfile?['display_name'] ?? 'Good News Reader';
    final email = _userProfile?['email'] ?? 'No email available';
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                      child:
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Stack(alignment: Alignment.bottomRight, children: [
                          CircleAvatar(
                              radius: isSmallScreen ? 50 : 60,
                              backgroundColor: primaryColor.withOpacity(0.15),
                              child: Text(displayName[0].toUpperCase(),
                                  style: TextStyle(
                                      fontSize: isSmallScreen ? 32 : 40,
                                      color: primaryColor,
                                      fontWeight: FontWeight.bold))),
                          Positioned(
                              bottom: 4,
                              right: 4,
                              child: GestureDetector(
                                  onTap: _editProfile,
                                  child: Container(
                                      padding: EdgeInsets.all(
                                          isSmallScreen ? 6 : 8),
                                      decoration: BoxDecoration(
                                          color: primaryColor,
                                          shape: BoxShape.circle),
                                      child: Icon(Icons.edit,
                                          size: isSmallScreen ? 16 : 18,
                                          color: Colors.white)))),
                        ]),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Text(displayName,
                            style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                fontSize: isSmallScreen ? 20 : 24),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(email,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.75),
                                fontSize: isSmallScreen ? 13 : 14),
                            textAlign: TextAlign.center),
                      ]))))),
      SliverToBoxAdapter(child: SizedBox(height: isSmallScreen ? 20 : 28)),
      SliverToBoxAdapter(
          child: _isStatsLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _buildArticlesReadCard()),
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
      floatingActionButton:
      _showFab && _selectedTabIndex == 2 ? SpeedDialFAB(actions: []) : null,
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
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, -2))
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
                    onDoubleTap: () => _handleTabSpecificRefresh(0)),
                _buildNavItem(
                    icon: Icons.article_outlined,
                    activeIcon: Icons.article,
                    label: 'News',
                    isActive: _selectedTabIndex == 1,
                    onTap: () => _onTabChanged(1),
                    onDoubleTap: () => _handleTabSpecificRefresh(1)),
                _buildNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                    isActive: _selectedTabIndex == 3,
                    onTap: () => _onTabChanged(3),
                    onDoubleTap: () => _handleTabSpecificRefresh(3)),
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
          child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(isSmallScreen ? 5 : 7),
                  decoration: BoxDecoration(
                    color: isActive
                        ? primaryColor.withOpacity(0.15)
                        : Colors.transparent,
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
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 9 : 10,
                        fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive
                            ? primaryColor
                            : isDark
                            ? Colors.white60
                            : Colors.grey[600],
                      )),
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
          ? Center(
          child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary))
          : GestureDetector(
        onHorizontalDragEnd: _selectedTabIndex == 0
            ? (details) {
          if ((details.primaryVelocity ?? 0) < -400) {
            _horizontalPageController.animateToPage(1,
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut);
          }
        }
            : null,
        child: PageView.builder(
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
                  : _allArticles
                  .where((a) => a['category_id'] == categoryId)
                  .toList();
              return _buildNewsTabContent(
                categoryName: category['name'],
                items: filteredArticles,
                showEmptyState: filteredArticles.isEmpty &&
                    !_isLoadingMore &&
                    !_isInitialLoading,
                categoryList: categoryList,
                activeCategoryIndex: pageIndex - 1,
              );
            }
            if (pageIndex == totalNewsPages + 1)
              return _buildProfilePage();
            return Container();
          },
        ),
      ),
    );
  }

  // Γ£à FIX: onLoadMore properly wired ΓÇö widget αñ╕αÑìαñ╡αññαñâ pagination trigger αñòαñ░αÑçαñ▓
  Widget _buildVideoTabContent() {
    if (_isVideoLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
      );
    }
    if (_videoPosts.isEmpty) return _buildEmptyStateForTab('Video');
    return VideoReelFeed(
      videos: _videoPosts,
      onToggleLike: _toggleLike,
      onShare: _shareArticle,
      onRefresh: () => _loadVideoPosts(),
      onLoadMore: _onVideoLoadMore,
      hasMore: _videoHasMore,
    );
  }

  Widget _buildNewsTabContent(
      {required String categoryName,
        required List<Map<String, dynamic>> items,
        required bool showEmptyState,
        required List<Map<String, dynamic>> categoryList,
        required int activeCategoryIndex}) {
    return Column(children: [
      Container(
        height: 50,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ]),
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
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () {
                  _selectCategory(category['id']);
                  _scrollCategoryChipsToIndex(index);
                },
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(category['name'],
                          style: TextStyle(
                              color: isSelected
                                  ? primaryColor
                                  : isDark
                                  ? Colors.white60
                                  : Colors.grey[600],
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: isSelected ? 15 : 13)),
                      if (isSelected)
                        Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                                height: 2.5,
                                width: 30,
                                decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius:
                                    BorderRadius.circular(1.5)))),
                    ]),
              ),
            );
          },
        ),
      ),
      Expanded(
          child: GestureDetector(
            onVerticalDragEnd: _onVerticalDragEnd,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: _isLoadingMore && items.isEmpty
                ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                          strokeWidth: 3),
                      const SizedBox(height: 16),
                      Text('Loading articles...',
                          style: TextStyle(
                              color: Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? Colors.white60
                                  : Colors.grey[600],
                              fontSize: 14)),
                    ]))
                : PageView.builder(
              scrollDirection: Axis.vertical,
              physics: const ClampingScrollPhysics(),
              itemCount: items.isEmpty && showEmptyState ? 1 : items.length,
              itemBuilder: (context, index) {
                if (items.isEmpty && showEmptyState)
                  return _buildEmptyStateForTab(categoryName);
                return _buildArticle(items[index]);
              },
            ),
          )),
    ]);
  }

  Widget _buildArticle(Map<String, dynamic> article) => RepaintBoundary(
      child: ArticleCardWidget(
          article: article,
          onTrackRead: _trackArticleRead,
          onShare: _shareArticle));

  Widget _buildEmptyStateForTab(String tabName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String message, subMessage, buttonText;
    IconData icon = Icons.info_outline;
    IconData buttonIcon = Icons.refresh;
    VoidCallback? onPressed;
    if (tabName == 'Video') {
      message = 'No videos yet!';
      subMessage = 'Videos will appear here soon!';
      icon = Icons.video_library_outlined;
      onPressed = () => _loadVideoPosts();
      buttonText = 'Retry';
    } else if (tabName == 'News' || tabName == 'All') {
      message = 'No articles yet!';
      subMessage = _hasMore ? 'Loading...' : 'Try a different category.';
      icon = Icons.article_outlined;
      onPressed = () => _handleTabSpecificRefresh(1);
      buttonText = 'Refresh';
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
          child:
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon,
                size: 64,
                color: isDark ? Colors.white38 : Colors.grey[400]),
            const SizedBox(height: 16),
            Text(message,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: isDark ? Colors.white70 : Colors.grey[600]),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(subMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white54 : Colors.grey[500]),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (onPressed != null)
              ElevatedButton.icon(
                  onPressed: onPressed,
                  icon: Icon(buttonIcon),
                  label: Text(buttonText),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12))),
          ])),
    );
  }
}