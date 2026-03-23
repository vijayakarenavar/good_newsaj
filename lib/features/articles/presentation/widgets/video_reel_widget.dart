// lib/features/videos/presentation/widgets/video_reel_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
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
    super.key,
    required this.videos,
    required this.onToggleLike,
    required this.onShare,
    required this.onRefresh,
    this.onLoadMore,
    this.hasMore,
  });

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
  bool _useHybridComposition = true;
  bool _deviceDetected = false;

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

    _detectAndInit();
  }

  Future<void> _detectAndInit() async {
    if (Platform.isAndroid) {
      try {
        final info = await DeviceInfoPlugin().androidInfo;
        _useHybridComposition = info.version.sdkInt < 29;
      } catch (_) {
        _useHybridComposition = true;
      }
    } else {
      _useHybridComposition = false;
    }

    if (!mounted) return;

    _buildFreshController(0);

    setState(() {
      _deviceDetected = true; // ✅ एकाच setState मध्ये
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controllerCache[0]?.play();
    });
  }

  // ✅ Crash-safe fresh controller
  YoutubePlayerController? _buildFreshController(int actualIndex) {
    final videos = _filteredVideos;

    // ✅ Fix 1 — index out of range — null return, crash नाही
    if (actualIndex < 0 || actualIndex >= videos.length) return null;

    final videoId = videos[actualIndex]['video_id'] as String? ?? '';

    // ✅ Fix 2 — empty videoId — null return, crash नाही
    if (videoId.isEmpty) return null;

    // जुना असेल तर dispose कर
    _controllerCache[actualIndex]?.dispose();
    _controllerCache.remove(actualIndex);

    final ctrl = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        hideControls: true,
        hideThumbnail: true,
        disableDragSeek: true,
        loop: true,
        enableCaption: false,
        forceHD: false,
        useHybridComposition: _useHybridComposition,
      ),
    );

    _controllerCache[actualIndex] = ctrl;
    return ctrl;
  }

  void _preloadNeighbors(int currentActualIndex) {
    final videos = _filteredVideos;
    if (videos.isEmpty) return;

    for (final offset in [1, -1]) {
      final idx = (currentActualIndex + offset + videos.length) % videos.length;
      if (_controllerCache.containsKey(idx)) continue;

      final videoId = videos[idx]['video_id'] as String? ?? '';
      if (videoId.isEmpty) continue;

      _controllerCache[idx] = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: true,
          hideThumbnail: true,
          disableDragSeek: true,
          loop: true,
          enableCaption: false,
          forceHD: false,
          useHybridComposition: _useHybridComposition,
        ),
      );
    }

    // दूर गेलेले dispose
    final toDispose = _controllerCache.keys.where((key) {
      final diff = (key - currentActualIndex + videos.length) % videos.length;
      return diff > 2 && diff < videos.length - 1;
    }).toList();
    for (final key in toDispose) {
      _controllerCache[key]?.dispose();
      _controllerCache.remove(key);
    }
  }

  @override
  void didUpdateWidget(VideoReelFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasMore != null && widget.hasMore != oldWidget.hasMore) {
      setState(() => _hasMorePages = widget.hasMore!);
    }
    if (widget.videos != oldWidget.videos) {
      for (final c in _controllerCache.values) {
        c.dispose();
      }
      _controllerCache.clear();
      setState(() {
        _allVideos = List<Map<String, dynamic>>.from(widget.videos);
        _nextPage = 2;
        _hasMorePages = widget.hasMore ?? true;
      });
      if (_deviceDetected) {
        _buildFreshController(0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _controllerCache[0]?.play();
        });
      }
    }
  }

  Future<void> _loadMoreIfNeeded(int rawIndex, int actualIndex) async {
    final videos = _filteredVideos;
    if (!_hasMorePages ||
        _isLoadingMore ||
        widget.onLoadMore == null ||
        rawIndex < videos.length - 5) {
      return;
    }

    setState(() => _isLoadingMore = true);
    try {
      final newVideos = await widget.onLoadMore!(_nextPage);
      if (!mounted) return;
      if (newVideos == null || newVideos.isEmpty) {
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
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onPageChanged(int index) {
    final videos = _filteredVideos;
    if (videos.isEmpty || !_deviceDetected) return;

    final actualIndex = index % videos.length;
    final prevActualIndex = _currentPage % videos.length;

    // Previous video pause
    _controllerCache[prevActualIndex]?.pause();

    // ✅ Fix 3 — एकाच setState मध्ये सगळं
    _buildFreshController(actualIndex);
    _preloadNeighbors(actualIndex);

    setState(() {
      _currentPage = index;
    });

    // Play after short delay (WebView ready होण्यासाठी)
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _controllerCache[actualIndex]?.play();
    });

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
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _pageController.dispose();
    for (final c in _controllerCache.values) {
      c.dispose();
    }
    _controllerCache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videos = _filteredVideos;

    if (videos.isEmpty || !_deviceDetected) {
      return Container(
        color: Colors.black,
        child: Center(
          child: !_deviceDetected
              ? const SizedBox.shrink()
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
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
          itemCount: 1000000,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final actualIndex = index % videos.length;
            final video = videos[actualIndex];
            final isActive = index == _currentPage;
            final ctrl = _controllerCache[actualIndex];

            return RepaintBoundary(
              key: ValueKey('reel_${actualIndex}_${ctrl?.hashCode ?? 0}'),
              child: _VideoReelItem(
                video: video,
                isActive: isActive,
                controller: ctrl,
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
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _VideoReelItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final YoutubePlayerController? controller;
  final VoidCallback onToggleLike;
  final VoidCallback onShare;

  const _VideoReelItem({
    required this.video,
    required this.isActive,
    required this.controller,
    required this.onToggleLike,
    required this.onShare,
  });

  @override
  State<_VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<_VideoReelItem> {
  bool _showThumbnail = true;
  bool _isPlaying = false;
  final bool _hasError = false;
  bool _showNetworkError = false;
  bool _userManuallyStopped = false;
  Timer? _loadTimeoutTimer;

  YoutubePlayerController? get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _ctrl?.addListener(_onStateChanged);
    if (widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isActive) {
          _ctrl?.play();
          _startTimeout();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onStateChanged);
      _ctrl?.addListener(_onStateChanged);
      if (mounted) {
        setState(() {
          _showThumbnail = true;
          _isPlaying = false;
          _showNetworkError = false;
        });
      }
    }

    if (widget.isActive && !oldWidget.isActive) {
      if (mounted) {
        setState(() {
          _showThumbnail = true;
          _isPlaying = false;
          _userManuallyStopped = false;
          _showNetworkError = false;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _ctrl?.play();
        _startTimeout();
      });
    } else if (!widget.isActive && oldWidget.isActive) {
      _loadTimeoutTimer?.cancel();
      _ctrl?.pause();
      if (mounted) {
        setState(() {
          _showThumbnail = true;
          _isPlaying = false;
          _showNetworkError = false;
        });
      }
    }
  }

  void _startTimeout() {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(const Duration(seconds: 8), () async {
      if (!mounted) return;
      if (_ctrl?.value.isPlaying ?? false) return;

      final hasInternet = await _checkInternet();
      if (!mounted) return;

      if (!hasInternet) {
        setState(() => _showNetworkError = true);
      } else {
        _ctrl?.play();
      }
    });
  }

  Future<bool> _checkInternet() async {
    try {
      final s = await Socket.connect('8.8.8.8', 53,
          timeout: const Duration(seconds: 3));
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _ctrl?.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted || _ctrl == null) return;
    final playing = _ctrl!.value.isPlaying;
    final hasError = _ctrl!.value.hasError;

    if (hasError) {
      _loadTimeoutTimer?.cancel();
      return;
    }

    if (_isPlaying != playing) {
      setState(() {
        _isPlaying = playing;
        if (playing) {
          _loadTimeoutTimer?.cancel();
          _showThumbnail = false;
          _showNetworkError = false;
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_ctrl == null) return;
    if (_isPlaying) {
      _userManuallyStopped = true;
      _ctrl!.pause();
    } else {
      _userManuallyStopped = false;
      _ctrl!.play();
    }
  }

  void _shareVideo() {
    final title = widget.video['title'] as String? ?? '';
    final videoId = widget.video['video_id'] as String? ?? '';
    final author = widget.video['author'] as String? ?? '';
    final url = videoId.isNotEmpty
        ? 'https://www.youtube.com/watch?v=$videoId'
        : '';
    SharePlus.instance.share(ShareParams(
      text: [
        if (title.isNotEmpty) '🎬 $title',
        if (author.isNotEmpty) '👤 $author',
        if (url.isNotEmpty) '🔗 $url',
        '📲 Check it out on Joy Scroll!',
      ].join('\n'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Colors.black),

        if (!_hasError && _ctrl != null)
          Positioned.fill(
            child: IgnorePointer(
              child: YoutubePlayer(
                controller: _ctrl!,
                showVideoProgressIndicator: false,
                onReady: () {
                  if (mounted && widget.isActive) _ctrl?.play();
                },
                onEnded: (_) {
                  if (widget.isActive) {
                    _ctrl?.seekTo(Duration.zero);
                    _ctrl?.play();
                  }
                },
              ),
            ),
          ),

        if (_showThumbnail)
          Positioned.fill(child: _buildThumbnail()),

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
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
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
                  ],
                ),
              ),
            ),
          ),
        ),

        Positioned.fill(
          child: GestureDetector(
            onTap: _togglePlayPause,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),

        // Network error popup
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
                    onTap: () {
                      setState(() => _showNetworkError = false);
                      _ctrl?.play();
                      _startTimeout();
                    },
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

        // Video info + share
        if (widget.isActive)
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
      ]),
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
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(children: [
          Text(_formatTimestamp(createdAt),
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          if (category.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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