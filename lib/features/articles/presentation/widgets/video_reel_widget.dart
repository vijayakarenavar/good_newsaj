// lib/features/articles/presentation/widgets/video_reel_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:async';
import 'dart:io';

class VideoReelFeed extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final Function(Map<String, dynamic>) onToggleLike;
  final Function(Map<String, dynamic>) onShare;
  final VoidCallback onRefresh;
  final Future<List<Map<String, dynamic>>?> Function(int page)? onLoadMore;
  final bool hasMore;

  const VideoReelFeed({
    Key? key,
    required this.videos,
    required this.onToggleLike,
    required this.onShare,
    required this.onRefresh,
    this.onLoadMore,
    this.hasMore = true,
  }) : super(key: key);

  @override
  State<VideoReelFeed> createState() => _VideoReelFeedState();
}

class _VideoReelFeedState extends State<VideoReelFeed>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late List<Map<String, dynamic>> _allVideos;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  int _nextPage = 2;
  int _lastFetchedOffset = -1;

  final Map<int, YoutubePlayerController> _controllerCache = {};

  List<Map<String, dynamic>> get _videos => _allVideos;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _allVideos = List<Map<String, dynamic>>.from(widget.videos);
    _hasMorePages = widget.hasMore;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    _preloadControllers(0, count: 4);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controllerCache[_currentPage];
    if (controller == null) return;
    if (state == AppLifecycleState.paused) {
      controller.pause();
    } else if (state == AppLifecycleState.resumed) {
      controller.play();
    }
  }

  @override
  void didUpdateWidget(VideoReelFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasMore != oldWidget.hasMore) {
      _hasMorePages = widget.hasMore;
    }
    if (widget.videos == oldWidget.videos) return;

    final bool isFullRefresh = widget.videos.isEmpty ||
        widget.videos.length < oldWidget.videos.length ||
        (oldWidget.videos.isNotEmpty &&
            widget.videos.isNotEmpty &&
            widget.videos.first['id'] != oldWidget.videos.first['id']);

    if (isFullRefresh) {
      for (final c in _controllerCache.values) c.dispose();
      _controllerCache.clear();
      _lastFetchedOffset = -1;
      setState(() {
        _allVideos = List<Map<String, dynamic>>.from(widget.videos);
        _nextPage = 2;
        _hasMorePages = widget.hasMore;
        _currentPage = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        _preloadControllers(0, count: 4);
      });
    }
  }

  Future<void> _loadMoreIfNeeded(int currentIndex) async {
    final videos = _videos;
    if (!_hasMorePages ||
        _isLoadingMore ||
        widget.onLoadMore == null ||
        currentIndex < videos.length - 3) return;

    final currentOffset = videos.length;
    if (currentOffset == _lastFetchedOffset) return;
    _lastFetchedOffset = currentOffset;

    setState(() => _isLoadingMore = true);
    try {
      final newVideos = await widget.onLoadMore!(_nextPage);
      if (!mounted) return;
      if (newVideos == null) {
        _lastFetchedOffset = -1;
        setState(() => _isLoadingMore = false);
      } else if (newVideos.isEmpty) {
        setState(() {
          _hasMorePages = false;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _allVideos.addAll(newVideos);
          _nextPage++;
          _isLoadingMore = false;
        });
        _preloadControllers(currentIndex, count: 3);
      }
    } catch (_) {
      if (mounted) {
        _lastFetchedOffset = -1;
        setState(() => _isLoadingMore = false);
      }
    }
  }

  YoutubePlayerController _buildController(String videoId,
      {bool autoPlay = false}) {
    return YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: autoPlay,
        mute: false,
        hideControls: true,
        hideThumbnail: true,
        disableDragSeek: true,
        loop: true,
        enableCaption: false,
        forceHD: false,
        useHybridComposition: true,
      ),
    );
  }

  void _preloadControllers(int currentIndex, {int count = 3}) {
    final videos = _videos;
    if (videos.isEmpty) return;

    for (int offset = 0; offset < count; offset++) {
      final idx = currentIndex + offset;
      if (idx >= videos.length) break;
      if (_controllerCache.containsKey(idx)) continue;
      final videoId = videos[idx]['video_id'] as String? ?? '';
      if (videoId.isEmpty) continue;
      _controllerCache[idx] =
          _buildController(videoId, autoPlay: idx == currentIndex);
    }

    final toDispose = <int>[];
    for (final key in _controllerCache.keys) {
      if ((key - currentIndex).abs() > 4) toDispose.add(key);
    }
    for (final key in toDispose) {
      _controllerCache[key]?.dispose();
      _controllerCache.remove(key);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pageController.dispose();
    for (final c in _controllerCache.values) c.dispose();
    _controllerCache.clear();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_videos.isEmpty) return;
    if (_currentPage != index) setState(() => _currentPage = index);
    _preloadControllers(index, count: 3);
    _loadMoreIfNeeded(index);
  }

  // ✅ Original scrolling — velocity 150
  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -150) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    } else if (velocity > 150) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;

    if (videos.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.video_library_outlined,
                color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            const Text('No videos yet!',
                style: TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black),
            ),
          ]),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: _onVerticalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: videos.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            if (index >= videos.length) return const SizedBox.shrink();
            final video = videos[index];
            final isActive = index == _currentPage;
            return RepaintBoundary(
              child: _VideoReelItem(
                key: ValueKey('reel_${video['id']}'),
                video: video,
                isActive: isActive,
                cachedController: _controllerCache[index],
                onToggleLike: () => widget.onToggleLike(video),
                onShare: () => widget.onShare(video),
              ),
            );
          },
        ),
        if (_isLoadingMore)
          const Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white54))),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VideoReelItem — Single video item
// ─────────────────────────────────────────────────────────────────────────────
class _VideoReelItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final YoutubePlayerController? cachedController;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;

  const _VideoReelItem({
    Key? key,
    required this.video,
    required this.isActive,
    required this.cachedController,
    required this.onToggleLike,
    required this.onShare,
  }) : super(key: key);

  @override
  State<_VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<_VideoReelItem> {
  YoutubePlayerController? _controller;

  bool _isPlaying = false;
  bool _hasEverPlayed = false;
  bool _showThumbnail = true;
  bool _showSkeleton = true;
  bool _hasError = false;
  bool _showNetworkError = false;

  Timer? _loadTimeoutTimer;
  Timer? _bufferDebounceTimer;
  Timer? _autoRetryTimer;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(_VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cachedController != oldWidget.cachedController) {
      _detachController();
      _attachController();
      return;
    }
    if (widget.isActive && !oldWidget.isActive) {
      _startPlaying();
    } else if (!widget.isActive && oldWidget.isActive) {
      _pauseAndReset();
    }
  }

  void _attachController() {
    if (widget.cachedController != null) {
      _controller = widget.cachedController;
      _controller!.addListener(_onStateChanged);
      if (widget.isActive) _startPlaying();
    } else {
      _buildFallbackController();
    }
  }

  void _detachController() {
    _controller?.removeListener(_onStateChanged);
    _controller = null;
  }

  void _buildFallbackController() {
    final videoId = widget.video['video_id'] as String? ?? '';
    if (videoId.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: widget.isActive,
        mute: false,
        hideControls: true,
        hideThumbnail: true,
        disableDragSeek: true,
        loop: true,
        enableCaption: false,
        forceHD: false,
        useHybridComposition: true,
      ),
    );
    _controller!.addListener(_onStateChanged);
    if (mounted) setState(() {});
    if (widget.isActive) _startPlaying();
  }

  void _startPlaying() {
    if (_controller == null) return;
    _cancelAllTimers();

    if (mounted) {
      setState(() {
        _showNetworkError = false;
        _hasError = false;
        if (!_hasEverPlayed) _showSkeleton = true;
      });
    }

    _controller!.play();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || !widget.isActive) return;
      if (!(_controller?.value.isPlaying ?? false)) _controller?.play();
    });

    // ✅ Back navigation fix — paused state मधून extra push
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || !widget.isActive) return;
      if (!(_controller?.value.isPlaying ?? false)) _controller?.play();
    });

    _loadTimeoutTimer = Timer(const Duration(seconds: 6), () async {
      if (!mounted || !widget.isActive) return;
      if (_controller?.value.isPlaying ?? false) return;
      final hasNet = await _checkInternet();
      if (!mounted || !widget.isActive) return;
      if (!hasNet) {
        setState(() {
          _showSkeleton = false;
          _showNetworkError = true;
        });
      } else {
        _reloadController();
      }
    });
  }

  void _reloadController() {
    if (!mounted) return;
    final videoId = widget.video['video_id'] as String? ?? '';
    if (videoId.isEmpty) return;

    _detachController();
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true,
        hideThumbnail: true,
        disableDragSeek: true,
        loop: true,
        enableCaption: false,
        forceHD: false,
        useHybridComposition: true,
      ),
    );
    _controller!.addListener(_onStateChanged);
    if (mounted) setState(() {});
  }

  Future<bool> _checkInternet() async {
    try {
      final socket = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 3));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _retryPlay() {
    if (mounted) {
      setState(() {
        _showNetworkError = false;
        _hasError = false;
        if (!_hasEverPlayed) _showSkeleton = true;
      });
    }
    _reloadController();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && widget.isActive) _startPlaying();
    });
  }

  // ✅ FIX: seekTo(Duration.zero) काढला — back navigation bug fix
  void _pauseAndReset() {
    _cancelAllTimers();
    _controller?.pause();
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _showNetworkError = false;
        _showThumbnail = true;
        _showSkeleton = false;
      });
    }
  }

  void _onStateChanged() {
    if (!mounted || _controller == null) return;
    final value = _controller!.value;

    if (value.hasError) {
      _cancelAllTimers();
      if (mounted) {
        setState(() {
          _showSkeleton = false;
          _isPlaying = false;
        });
      }
      _autoRetryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && widget.isActive && !_showNetworkError) {
          _reloadController();
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && widget.isActive) _controller?.play();
          });
        }
      });
      return;
    }

    if (value.isPlaying && !_isPlaying) {
      _bufferDebounceTimer?.cancel();
      _loadTimeoutTimer?.cancel();
      _autoRetryTimer?.cancel();
      setState(() {
        _isPlaying = true;
        _hasEverPlayed = true;
        _showThumbnail = false;
        _showSkeleton = false;
        _showNetworkError = false;
      });
    } else if (!value.isPlaying && _isPlaying) {
      _bufferDebounceTimer?.cancel();
      _bufferDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        if (!(_controller?.value.isPlaying ?? false)) {
          setState(() => _isPlaying = false);
          if (widget.isActive) {
            _autoRetryTimer?.cancel();
            _autoRetryTimer = Timer(const Duration(seconds: 3), () {
              if (mounted && widget.isActive &&
                  !(_controller?.value.isPlaying ?? false)) {
                _controller?.play();
              }
            });
          }
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  void _cancelAllTimers() {
    _loadTimeoutTimer?.cancel();
    _bufferDebounceTimer?.cancel();
    _autoRetryTimer?.cancel();
  }

  void _shareVideo() {
    final title = widget.video['title'] as String? ?? '';
    final videoId = widget.video['video_id'] as String? ?? '';
    final author = widget.video['author'] as String? ?? '';
    final youtubeUrl =
    videoId.isNotEmpty ? 'https://www.youtube.com/watch?v=$videoId' : '';
    Share.share([
      if (title.isNotEmpty) '🎬 $title',
      if (author.isNotEmpty) '👤 $author',
      if (youtubeUrl.isNotEmpty) '🔗 $youtubeUrl',
      '📱 Check it out on Joy Scroll!',
    ].join('\n'));
  }

  @override
  void dispose() {
    _cancelAllTimers();
    _detachController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: एकदा video play झाला (_hasEverPlayed=true) की
    // thumbnail कधीच player वर overlay होणार नाही
    // हाच "audio येतो video नाही" bug चा root cause होता
    final bool showThumb = !widget.isActive || (_showThumbnail && !_hasEverPlayed);

    return SizedBox.expand(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),

        // Step 1: Thumbnail — player च्या खाली
        if (showThumb)
          Positioned.fill(child: _buildThumbnail()),

        // Step 2: YouTube Player — thumbnail च्या वर
        if (widget.isActive && !_hasError && _controller != null)
          Positioned.fill(
            child: IgnorePointer(
              child: YoutubePlayer(
                controller: _controller!,
                showVideoProgressIndicator: false,
                onReady: () {
                  if (mounted && widget.isActive) _controller?.play();
                },
                onEnded: (_) {
                  if (mounted && widget.isActive) {
                    _controller?.seekTo(Duration.zero);
                    _controller?.play();
                  }
                },
              ),
            ),
          ),

        // Step 3: Skeleton — player च्या वर, फक्त first load
        if (widget.isActive &&
            _showSkeleton &&
            !_hasEverPlayed &&
            !_showNetworkError &&
            !_hasError)
          Positioned.fill(child: _buildSkeletonLoader()),

        // Top gradient
        Positioned(
          top: 0, left: 0, right: 0,
          child: IgnorePointer(
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xCC000000), Colors.transparent])),
            ),
          ),
        ),

        // Bottom gradient
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: IgnorePointer(
            child: Container(
              height: 280,
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0xDD000000),
                        Color(0x88000000),
                        Colors.transparent,
                      ])),
            ),
          ),
        ),

        // Tap to play/pause
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.isActive ? _togglePlayPause : null,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // Network error UI
        if (widget.isActive && _showNetworkError)
          Positioned.fill(
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded,
                      color: Colors.white70, size: 40),
                  const SizedBox(height: 12),
                  const Text('No Internet Connection',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text('Check your connection and try again.',
                      style: TextStyle(
                          color: Colors.white60, fontSize: 13, height: 1.4),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _retryPlay,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20)),
                      child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                color: Colors.black, size: 18),
                            SizedBox(width: 6),
                            Text('Try again',
                                style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ),
                ]),
              ),
            ),
          ),

        // Video info + action buttons
        Positioned(
          bottom: 24, left: 16, right: 16,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: _buildVideoInfo()),
            const SizedBox(width: 16),
            _buildActionButtons(),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSkeletonLoader() {
    return Container(
      color: Colors.black,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Container(width: 120, height: 14, color: Colors.white),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                      width: double.infinity, height: 16, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(
                      width: MediaQuery.of(context).size.width * 0.7,
                      height: 16,
                      color: Colors.white),
                  const SizedBox(height: 12),
                  Container(width: 80, height: 12, color: Colors.white),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final thumbUrl = widget.video['thumbnail_url'] as String? ?? '';
    if (thumbUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbUrl,
        fit: BoxFit.cover,
        memCacheWidth: 1080,
        memCacheHeight: 1920,
        placeholder: (_, __) => Container(color: Colors.black),
        errorWidget: (_, __, ___) => Container(color: Colors.black),
      );
    }
    return Container(color: Colors.black);
  }

  Widget _buildVideoInfo() {
    final author = widget.video['author'] as String? ?? 'JoyScroll';
    final title = widget.video['title'] as String? ?? '';
    final content = widget.video['content'] as String? ?? '';
    final category = widget.video['category'] as String? ?? '';
    final createdAt = widget.video['created_at'] as String?;

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  color: Colors.white24),
              child: Center(
                  child: Text(
                      author.isNotEmpty ? author[0].toUpperCase() : 'J',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))),
            ),
            const SizedBox(width: 8),
            Flexible(
                child: Text('@$author',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                    overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 10),
          if (title.isNotEmpty)
            Text(title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
                content.length > 120
                    ? '${content.substring(0, 120)}…'
                    : content,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Text(_formatTimestamp(createdAt),
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (category.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24, width: 0.5)),
                child: Text(category,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ),
            ],
          ]),
        ]);
  }

  Widget _buildActionButtons() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _buildActionBtn(
          icon: Icons.share_rounded,
          label: 'Share',
          color: Colors.white,
          onTap: _shareVideo),
    ]);
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: Colors.black54, shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 26),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)])),
        ],
      ]),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return 'Recently';
    try {
      DateTime? date = DateTime.tryParse(timestamp);
      if (date == null) {
        final ms = int.tryParse(timestamp);
        if (ms != null) {
          date = ms > 1e12
              ? DateTime.fromMillisecondsSinceEpoch(ms)
              : DateTime.fromMillisecondsSinceEpoch(ms * 1000);
        }
      }
      if (date == null) return 'Recently';
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (_) {
      return 'Recently';
    }
  }
}