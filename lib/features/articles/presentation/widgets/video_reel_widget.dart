// lib/features/videos/presentation/widgets/video_reel_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'dart:async';
import 'dart:io';

class VideoReelFeed extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final Function(Map<String, dynamic>) onToggleLike;
  final Function(Map<String, dynamic>) onShare;
  final VoidCallback onRefresh;
  final Future<List<Map<String, dynamic>>?> Function(int page)? onLoadMore;
  final bool? hasMore;

  const VideoReelFeed({
    Key? key,
    required this.videos,
    required this.onToggleLike,
    required this.onShare,
    required this.onRefresh,
    this.onLoadMore,
    this.hasMore,
  }) : super(key: key);

  @override
  State<VideoReelFeed> createState() => _VideoReelFeedState();
}

class _VideoReelFeedState extends State<VideoReelFeed> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late List<Map<String, dynamic>> _allVideos;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  int _nextPage = 2;

  // FIX: controller cache keyed by actualIndex (0..N-1)
  // Widget key uses raw `index` so every visit = fresh widget + fresh play
  final Map<int, YoutubePlayerController> _controllerCache = {};

  List<Map<String, dynamic>> get _filteredVideos => _allVideos
      .where((v) => (v['thumbnail_url'] as String? ?? '').isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    _allVideos = List<Map<String, dynamic>>.from(widget.videos);
    if (widget.hasMore != null) _hasMorePages = widget.hasMore!;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _preloadControllers(0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _filteredVideos.isNotEmpty) {
        _controllerCache[0]?.play();
      }
    });
  }

  @override
  void didUpdateWidget(VideoReelFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasMore != null && widget.hasMore != oldWidget.hasMore) {
      setState(() => _hasMorePages = widget.hasMore!);
    }
    if (widget.videos != oldWidget.videos) {
      setState(() {
        _allVideos = List<Map<String, dynamic>>.from(widget.videos);
        _nextPage = 2;
        _hasMorePages = widget.hasMore ?? true;
      });
    }
  }

  // FIX: rawIndex (keeps growing) triggers load-more correctly.
  // actualIndex wraps 0..N-1 so it never reached videos.length-5.
  Future<void> _loadMoreIfNeeded(int rawIndex, int actualIndex) async {
    final videos = _filteredVideos;
    if (!_hasMorePages ||
        _isLoadingMore ||
        widget.onLoadMore == null ||
        rawIndex < videos.length - 5) return;

    setState(() => _isLoadingMore = true);
    try {
      final newVideos = await widget.onLoadMore!(_nextPage);
      if (!mounted) return;
      if (newVideos == null || newVideos.isEmpty) {
        setState(() { _hasMorePages = false; _isLoadingMore = false; });
      } else {
        setState(() {
          _allVideos.addAll(newVideos);
          _nextPage++;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // FIX: preload only current + 1 next (was 3), autoPlay:false everywhere.
  // Current video play triggered via Future.microtask to give WebView time.
  void _preloadControllers(int currentActualIndex) {
    final videos = _filteredVideos;
    if (videos.isEmpty) return;

    for (int offset = 0; offset <= 1; offset++) {
      final idx = (currentActualIndex + offset) % videos.length;
      if (_controllerCache.containsKey(idx)) continue;

      final videoId = videos[idx]['video_id'] as String? ?? '';
      if (videoId.isEmpty) continue;

      _controllerCache[idx] = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: true,
          hideThumbnail: true,
          disableDragSeek: true,
          loop: true,
          enableCaption: false,
          forceHD: false,
          useHybridComposition: false,
        ),
      );

      if (offset == 0) {
        Future.microtask(() {
          if (mounted) _controllerCache[idx]?.play();
        });
      }
    }

    // Dispose controllers that are far away (keep current ± 1)
    final toDispose = <int>[];
    for (final key in _controllerCache.keys) {
      final diff = (key - currentActualIndex + videos.length) % videos.length;
      if (diff > 2 && diff < videos.length - 1) toDispose.add(key);
    }
    for (final key in toDispose) {
      _controllerCache[key]?.dispose();
      _controllerCache.remove(key);
    }
  }

  @override
  void dispose() {
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
    final videos = _filteredVideos;
    if (videos.isEmpty) return;
    final actualIndex = index % videos.length;
    if (_currentPage != index) setState(() => _currentPage = index);
    _preloadControllers(actualIndex);
    _loadMoreIfNeeded(index, actualIndex);
  }

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
    final videos = _filteredVideos;

    if (videos.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: _onVerticalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: null,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final actualIndex = index % videos.length;
              final video = videos[actualIndex];
              final isActive = index == _currentPage;

              return RepaintBoundary(
                child: _VideoReelItem(
                  // FIX: key = raw `index` (not actualIndex).
                  // Back-scroll gives a NEW index → Flutter builds a fresh
                  // widget → fresh _attachController + _startPlaying → plays.
                  // Old key used actualIndex which wraps 0..N-1, so Flutter
                  // reused the old widget and isActive was stale → no play.
                  key: ValueKey('reel_$index'),
                  video: video,
                  isActive: isActive,
                  isPreload: (index - _currentPage).abs() <= 2,
                  cachedController: _controllerCache[actualIndex],
                  onToggleLike: () => widget.onToggleLike(video),
                  onShare: () => widget.onShare(video),
                ),
              );
            },
          ),

          if (_isLoadingMore)
            const Positioned(
              bottom: 8, left: 0, right: 0,
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white54),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VideoReelItem
// ─────────────────────────────────────────────────────────────────────────────
class _VideoReelItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final bool isPreload;
  final YoutubePlayerController? cachedController;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;

  const _VideoReelItem({
    Key? key,
    required this.video,
    required this.isActive,
    required this.isPreload,
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
  bool _showThumbnail = true;
  bool _hasError = false;
  bool _isLoading = false;
  // FIX: track user-initiated pause so scroll doesn't override it
  bool _userManuallyStopped = false;
  bool _showNetworkError = false;
  Timer? _loadTimeoutTimer;

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
        useHybridComposition: false,
      ),
    );
    _controller!.addListener(_onStateChanged);
    if (mounted) setState(() {});
  }

  void _startPlaying() {
    if (_controller == null) return;
    _loadTimeoutTimer?.cancel();
    _userManuallyStopped = false;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _showThumbnail = true;
        _showNetworkError = false;
      });
    }

    // Direct play — fresh widget (key=raw index) so controller is clean
    _controller?.play();

    // Retry at 300ms in case WebView is still warming up
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      if (!(_controller?.value.isPlaying ?? false)) _controller?.play();
    });

    // 8s timeout → check real internet before showing error popup
    _loadTimeoutTimer = Timer(const Duration(seconds: 8), () async {
      if (!mounted) return;
      if (_controller?.value.isPlaying ?? false) return;
      final hasInternet = await _checkInternet();
      if (!mounted) return;
      if (!hasInternet) {
        setState(() { _isLoading = false; _showNetworkError = true; });
      } else {
        _controller?.play();
      }
    });
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
    if (mounted) setState(() { _showNetworkError = false; _isLoading = true; });
    _startPlaying();
  }

  void _pauseAndReset() {
    _loadTimeoutTimer?.cancel();
    _controller?.pause();
    // FIX: don't seekTo(0) here — seekTo was putting the controller into a
    // reset state where the next play() call (on return) was silently ignored
    // by the WebView. _startPlaying() on the next fresh widget handles reset.
    if (mounted) {
      setState(() {
        _showThumbnail = true;
        _isLoading = false;
        _showNetworkError = false;
      });
    }
  }

  void _onStateChanged() {
    if (!mounted || _controller == null) return;
    final playing = _controller!.value.isPlaying;
    final hasError = _controller!.value.hasError;

    if (hasError && mounted) {
      _loadTimeoutTimer?.cancel();
      setState(() { _isLoading = false; });
      return;
    }

    if (_isPlaying != playing) {
      setState(() {
        _isPlaying = playing;
        if (playing) {
          _loadTimeoutTimer?.cancel();
          _showThumbnail = false;
          _isLoading = false;
          _showNetworkError = false;
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null) return;
    if (_isPlaying) {
      _userManuallyStopped = true;
      _controller!.pause();
    } else {
      _userManuallyStopped = false;
      _controller!.play();
    }
  }

  void _shareVideo() {
    final title = widget.video['title'] as String? ?? '';
    final videoId = widget.video['video_id'] as String? ?? '';
    final author = widget.video['author'] as String? ?? '';
    final youtubeUrl =
    videoId.isNotEmpty ? 'https://www.youtube.com/watch?v=$videoId' : '';
    final shareText = [
      if (title.isNotEmpty) '🎬 $title',
      if (author.isNotEmpty) '👤 $author',
      if (youtubeUrl.isNotEmpty) '🔗 $youtubeUrl',
      '📲 Check it out on Joy Scroll!',
    ].join('\n');
    Share.share(shareText);
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _detachController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),

          // VIDEO PLAYER
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
                    _controller?.seekTo(Duration.zero);
                    _controller?.play();
                  },
                ),
              ),
            ),

          // THUMBNAIL
          if (_showThumbnail || !widget.isActive)
            Positioned.fill(child: _buildThumbnail()),

          // TOP GRADIENT
          Positioned(
            top: 0, left: 0, right: 0,
            child: IgnorePointer(
              child: Container(
                height: 140,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xCC000000), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),

          // BOTTOM GRADIENT
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
                    ],
                  ),
                ),
              ),
            ),
          ),

          // PLAY/PAUSE GESTURE
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.isActive ? _togglePlayPause : null,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          // LOADING SPINNER
          if (widget.isActive && _isLoading && !_showNetworkError)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                ),
              ),
            ),

          // NETWORK ERROR POPUP
          if (widget.isActive && _showNetworkError)
            Positioned.fill(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.80),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 0.5),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // VIDEO INFO + ACTION BUTTONS
          Positioned(
            bottom: 24, left: 16, right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildVideoInfo()),
                const SizedBox(width: 16),
                _buildActionButtons(),
              ],
            ),
          ),
        ],
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
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              color: Colors.white24,
            ),
            child: Center(
              child: Text(
                author.isNotEmpty ? author[0].toUpperCase() : 'J',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text('@$author',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                overflow: TextOverflow.ellipsis),
          ),
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
                  ? '${content.substring(0, 120)}...'
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
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Text(category,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11)),
            ),
          ],
        ]),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _buildActionBtn(
        icon: Icons.share_rounded,
        label: 'Share',
        color: Colors.white,
        onTap: _shareVideo,
      ),
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
    } catch (e) {
      return 'Recently';
    }
  }
}