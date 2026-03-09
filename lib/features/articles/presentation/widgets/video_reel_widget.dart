// lib/features/videos/presentation/widgets/video_reel_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoReelFeed extends StatefulWidget {
  final List<Map<String, dynamic>> videos;
  final Function(Map<String, dynamic>) onToggleLike;
  final Function(Map<String, dynamic>) onShare;
  final VoidCallback onRefresh;

  const VideoReelFeed({
    Key? key,
    required this.videos,
    required this.onToggleLike,
    required this.onShare,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<VideoReelFeed> createState() => _VideoReelFeedState();
}

class _VideoReelFeedState extends State<VideoReelFeed> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isSwiping = false;

  final Map<int, YoutubePlayerController> _controllerCache = {};

  List<Map<String, dynamic>> get _filteredVideos => widget.videos
      .where((v) => (v['thumbnail_url'] as String? ?? '').isNotEmpty)
      .toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadControllers(0);
    });
  }

  void _preloadControllers(int currentActualIndex) {
    final videos = _filteredVideos;
    if (videos.isEmpty) return;

    for (int offset = 0; offset <= 1; offset++) {
      final idx = (currentActualIndex + offset) % videos.length;
      if (_controllerCache.containsKey(idx)) continue;

      final videoId = videos[idx]['video_id'] as String? ?? '';
      if (videoId.isEmpty) continue;

      final controller = YoutubePlayerController(
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
      _controllerCache[idx] = controller;
    }

    final toDispose = <int>[];
    for (final key in _controllerCache.keys) {
      final diff = (key - currentActualIndex + videos.length) % videos.length;
      if (diff > 2 && diff < videos.length - 1) {
        toDispose.add(key);
      }
    }
    for (final key in toDispose) {
      _controllerCache[key]?.dispose();
      _controllerCache.remove(key);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllerCache.values) {
      c.dispose();
    }
    _controllerCache.clear();
    super.dispose();
  }

  void _onPageChanged(int index) {
    final videos = _filteredVideos;
    if (videos.isEmpty) return;
    final actualIndex = index % videos.length;
    setState(() {
      _currentPage = index;
      _isSwiping = false;
    });
    _preloadControllers(actualIndex);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isSwiping) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      _isSwiping = true;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else if (velocity > 300) {
      _isSwiping = true;
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
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
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: _onVerticalDragEnd,
      behavior: HitTestBehavior.opaque,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: null,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final actualIndex = index % videos.length;
          final video = videos[actualIndex];
          final isActive = index == _currentPage;
          final isPreload = (index - _currentPage).abs() == 1;

          return RepaintBoundary(
            child: _VideoReelItem(
              key: ValueKey('reel_${actualIndex}_${video['id']}'),
              video: video,
              isActive: isActive,
              isPreload: isPreload,
              cachedController: _controllerCache[actualIndex],
              onToggleLike: () => widget.onToggleLike(video),
              onShare: () => widget.onShare(video),
            ),
          );
        },
      ),
    );
  }
}

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
    final controller = YoutubePlayerController(
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
    _controller = controller;
    _controller!.addListener(_onStateChanged);
    if (mounted) setState(() {});
  }

  void _startPlaying() {
    if (_controller == null) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      _controller?.play();
    });
  }

  void _pauseAndReset() {
    _controller?.pause();
    _controller?.seekTo(Duration.zero);
    if (mounted) setState(() => _showThumbnail = true);
  }

  void _onStateChanged() {
    if (!mounted || _controller == null) return;
    final playing = _controller!.value.isPlaying;
    if (_isPlaying != playing) {
      setState(() {
        _isPlaying = playing;
        if (playing) _showThumbnail = false;
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

  void _shareVideo() {
    final title = widget.video['title'] as String? ?? '';
    final videoId = widget.video['video_id'] as String? ?? '';
    final author = widget.video['author'] as String? ?? '';

    final youtubeUrl = videoId.isNotEmpty
        ? 'https://www.youtube.com/watch?v=$videoId'
        : '';

    final shareText = [
      if (title.isNotEmpty) '🎬 $title',
      if (author.isNotEmpty) '👤 $author',
      if (youtubeUrl.isNotEmpty) '🔗 $youtubeUrl',
      '📱 Joy Scroll वर बघा!',
    ].join('\n');

    Share.share(shareText);
  }

  @override
  void dispose() {
    _detachController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 0. BLACK BACKGROUND
          const ColoredBox(color: Colors.black),

          // 1. VIDEO PLAYER
          if (widget.isActive && !_hasError && _controller != null)
            Positioned.fill(
              child: IgnorePointer(
                child: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: false,
                  onReady: () {
                    if (mounted && widget.isActive) {
                      _controller?.play();
                    }
                  },
                  onEnded: (_) {
                    _controller?.seekTo(Duration.zero);
                    _controller?.play();
                  },
                ),
              ),
            ),

          // 2. THUMBNAIL
          if (_showThumbnail || !widget.isActive || widget.isPreload)
            Positioned.fill(child: _buildThumbnail()),

          // 3. TOP GRADIENT
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

          // 4. BOTTOM GRADIENT
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

          // 5. ✅ PLAY/PAUSE — फक्त action buttons सोडून बाकी area
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.isActive ? _togglePlayPause : null,
              // ✅ KEY FIX: opaque नाही — children ला tap जाऊ देतो
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),
          ),

          // 6. ✅ VIDEO INFO + ACTION BUTTONS — सर्वात वर (layer 6)
          // play/pause GestureDetector नंतर ठेवलं — त्यामुळे buttons clickable
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
        memCacheWidth: 720,
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
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '@$author',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        if (title.isNotEmpty)
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        if (content.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        Row(children: [
          Text(
            _formatTimestamp(createdAt),
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (category.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Text(
                category,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
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
    // ✅ AbsorbPointer नाही — tap directly जातो
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque, // ✅ opaque — tap confirm होतो
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ]),
    );
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
    } catch (_) {
      return 'Just now';
    }
  }
}