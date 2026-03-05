// lib/features/videos/presentation/widgets/video_reel_widget.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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

  // ✅ Thumbnail असलेले videos फक्त
  List<Map<String, dynamic>> get _filteredVideos => widget.videos
      .where((v) => (v['thumbnail_url'] as String? ?? '').isNotEmpty)
      .toList();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
      _isSwiping = false;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isSwiping) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -300) {
      _isSwiping = true;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else if (velocity > 300) {
      _isSwiping = true;
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
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
        // ✅ itemCount: null = infinite scroll
        itemCount: null,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          // ✅ FIX #1: actualIndex वापरा — loop मध्ये same widget reuse होतो
          final actualIndex = index % videos.length;
          final video = videos[actualIndex];
          final isActive = index == _currentPage;

          // ✅ FIX #2: Adjacent pages preload करा (thumbnail पुढे load होते)
          final isPreload = (index - _currentPage).abs() == 1;

          return RepaintBoundary(
            child: _VideoReelItem(
              // ✅ FIX #3: actualIndex key — नवीन player unnecessarily बनत नाही
              key: ValueKey('reel_${actualIndex}_${video['id']}'),
              video: video,
              isActive: isActive,
              isPreload: isPreload,
              onToggleLike: () => widget.onToggleLike(video),
              onShare: () => widget.onShare(video),
            ),
          );
        },
      ),
    );
  }
}

// ─── Single Reel Item ─────────────────────────────────────────────────────

class _VideoReelItem extends StatefulWidget {
  final Map<String, dynamic> video;
  final bool isActive;
  final bool isPreload; // ✅ FIX: next video thumbnail preload साठी
  final VoidCallback onToggleLike;
  final VoidCallback onShare;

  const _VideoReelItem({
    Key? key,
    required this.video,
    required this.isActive,
    required this.isPreload,
    required this.onToggleLike,
    required this.onShare,
  }) : super(key: key);

  @override
  State<_VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<_VideoReelItem> {
  YoutubePlayerController? _controller;
  bool _isPlayerReady = false;
  bool _isPlaying = false;
  bool _showThumbnail = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initPlayer();
  }

  @override
  void didUpdateWidget(_VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _initPlayer();
    } else if (!widget.isActive && oldWidget.isActive) {
      _destroyPlayer();
    }
  }

  void _initPlayer() {
    final videoId = widget.video['video_id'] as String?;
    if (videoId == null || videoId.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }
    _controller?.removeListener(_onStateChanged);
    _controller?.dispose();
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true,
        hideThumbnail: true,
        disableDragSeek: true,
        loop: true,
        enableCaption: false,
        forceHD: false,               // ✅ FIX: HD बंद → faster load
        useHybridComposition: false,  // ✅ FIX: Android WebView faster
      ),
    )..addListener(_onStateChanged);
    if (mounted) {
      setState(() {
        _showThumbnail = true;
        _hasError = false;
        _isPlayerReady = false;
        _isPlaying = false;
      });
    }
  }

  void _destroyPlayer() {
    _controller?.removeListener(_onStateChanged);
    _controller?.dispose();
    _controller = null;
    if (mounted) {
      setState(() {
        _isPlayerReady = false;
        _isPlaying = false;
        _showThumbnail = true;
      });
    }
  }

  void _onStateChanged() {
    if (!mounted || _controller == null) return;
    final isPlaying = _controller!.value.isPlaying;
    if (_isPlaying != isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
        if (isPlaying) _showThumbnail = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isPlayerReady) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onStateChanged);
    _controller?.dispose();
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

          // 1. VIDEO PLAYER — फक्त isActive असताना
          if (widget.isActive && !_hasError && _controller != null)
            Positioned.fill(
              child: IgnorePointer(
                child: YoutubePlayer(
                  controller: _controller!,
                  showVideoProgressIndicator: false,
                  onReady: () {
                    if (mounted) {
                      setState(() => _isPlayerReady = true);
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
          // ✅ FIX: isPreload असताना पण thumbnail दाखवतो — next video ready राहतो
          if (_showThumbnail || !widget.isActive || widget.isPreload)
            Positioned.fill(child: _buildThumbnail()),

          // 3. TOP GRADIENT
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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

          // 4. BOTTOM GRADIENT
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
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

          // 5. VIDEO INFO + BUTTONS
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildVideoInfo()),
                const SizedBox(width: 16),
                _buildActionButtons(),
              ],
            ),
          ),

          // 6. TAP → play/pause
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.isActive ? _togglePlayPause : null,
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
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
        // ✅ FIX: memCacheWidth — memory कमी वापरतो, faster decode
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
            width: 36,
            height: 36,
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
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Text(
                category,
                style:
                const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ]),
      ],
    );
  }

  Widget _buildActionButtons() {
    // final isLiked = widget.video['isLiked'] == true;
    // final likes = widget.video['likes'] as int? ?? 0;
    // final comments = widget.video['comments'] as int? ?? 0;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      // ✅ LIKE BUTTON — तात्पुरता बंद
      // _buildActionBtn(
      //   icon: isLiked ? Icons.favorite : Icons.favorite_border,
      //   label: likes > 0 ? _formatCount(likes) : '',
      //   color: isLiked ? Colors.red : Colors.white,
      //   onTap: widget.onToggleLike,
      // ),
      // const SizedBox(height: 20),

      // ✅ COMMENT BUTTON — तात्पुरता बंद
      // _buildActionBtn(
      //   icon: Icons.chat_bubble_outline_rounded,
      //   label: comments > 0 ? _formatCount(comments) : '',
      //   color: Colors.white,
      //   onTap: () {},
      // ),
      // const SizedBox(height: 20),

      // Share button चालू
      _buildActionBtn(
        icon: Icons.share_rounded,
        label: 'Share',
        color: Colors.white,
        onTap: widget.onShare,
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.black38,
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
    } catch (e) {
      return 'Just now';
    }
  }
}