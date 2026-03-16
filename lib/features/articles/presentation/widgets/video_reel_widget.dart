// lib/features/videos/presentation/widgets/video_reel_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

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

  // FIX 3: Cached list instead of recomputed getter
  List<Map<String, dynamic>> _filteredVideos = [];

  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  int _nextPage = 2;

  final Map<int, YoutubePlayerController> _controllerCache = {};

  void _updateFilteredVideos() {
    _filteredVideos = _allVideos
        .where((v) => (v['thumbnail_url'] ?? '').isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _allVideos = List<Map<String, dynamic>>.from(widget.videos);
    if (widget.hasMore != null) _hasMorePages = widget.hasMore!;

    // FIX 3: Build cached list once on init
    _updateFilteredVideos();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _initControllers(0);
  }

  @override
  void didUpdateWidget(VideoReelFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasMore != null && widget.hasMore != oldWidget.hasMore) {
      _hasMorePages = widget.hasMore!;
    }
    if (widget.videos != oldWidget.videos) {
      for (final c in _controllerCache.values) c.dispose();
      _controllerCache.clear();
      setState(() {
        _allVideos = List<Map<String, dynamic>>.from(widget.videos);
        _nextPage = 2;
        _hasMorePages = widget.hasMore ?? true;
        _currentPage = 0;
        // FIX 3: Rebuild cached list when videos change
        _updateFilteredVideos();
      });
      _pageController.jumpToPage(0);
      _initControllers(0);
    }
  }

  void _initControllers(int rawIndex) {
    if (_filteredVideos.isEmpty) return;

    for (final offset in [-1, 0, 1]) {
      final ri = rawIndex + offset;
      if (ri < 0) continue;
      if (_controllerCache.containsKey(ri)) continue;

      final videoId =
          _filteredVideos[ri % _filteredVideos.length]['video_id'] ?? '';
      if (videoId.isEmpty) continue;

      _controllerCache[ri] = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: false,
          mute: false,
          hideControls: true,
          hideThumbnail: true,
          disableDragSeek: true,
          // FIX 2: loop flag removed — no effect in v9, onEnded handles looping
          enableCaption: false,
          useHybridComposition: true,
        ),
      );
    }

    final toDispose = _controllerCache.keys
        .where((key) => (key - rawIndex).abs() > 2)
        .toList();
    for (final key in toDispose) {
      _controllerCache[key]?.dispose();
      _controllerCache.remove(key);
    }
  }

  void _onPageChanged(int index) {
    if (_filteredVideos.isEmpty) return;

    _currentPage = index;

    // Recreates controller if disposed while away
    _initControllers(index);

    // Pause all non-active controllers immediately
    _controllerCache.forEach((key, controller) {
      if (key != index) controller.pause();
    });

    // FIX 1: Removed _playController call here entirely.
    // _pendingPlay + _tryPlay() in _VideoReelItemState handles
    // all play triggers safely without conflicting with WebView readiness.

    _loadMoreIfNeeded(index);

    Future.microtask(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadMoreIfNeeded(int rawIndex) async {
    if (!_hasMorePages ||
        _isLoadingMore ||
        widget.onLoadMore == null ||
        rawIndex < _filteredVideos.length - 5) return;

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
          // FIX 3: Rebuild cached list when new videos arrive
          _updateFilteredVideos();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMore = false);
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

  @override
  Widget build(BuildContext context) {
    if (_filteredVideos.isEmpty) {
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

    return Stack(children: [
      PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: 1000000,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final actualIndex = index % _filteredVideos.length;
          final video = _filteredVideos[actualIndex];

          return RepaintBoundary(
            key: ValueKey('reel_$index'),
            child: _VideoReelItem(
              video: video,
              isActive: index == _currentPage,
              controller: _controllerCache[index],
              onToggleLike: () => widget.onToggleLike(video),
              onShare: () => widget.onShare(video),
            ),
          );
        },
      ),
      if (_isLoadingMore)
        const Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white54),
          ),
        ),
    ]);
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
    Key? key,
    required this.video,
    required this.isActive,
    required this.controller,
    required this.onToggleLike,
    required this.onShare,
  }) : super(key: key);

  @override
  State<_VideoReelItem> createState() => _VideoReelItemState();
}

class _VideoReelItemState extends State<_VideoReelItem> {
  bool _showThumbnail = true;
  bool _isPlaying = false;
  bool _pendingPlay = false;

  YoutubePlayerController? get _ctrl => widget.controller;

  @override
  void initState() {
    super.initState();
    _ctrl?.addListener(_onStateChanged);
  }

  @override
  void didUpdateWidget(_VideoReelItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_onStateChanged);
      setState(() {
        _showThumbnail = true;
        _isPlaying = false;
        _pendingPlay = false;
      });
      widget.controller?.addListener(_onStateChanged);
    }

    if (widget.isActive && !oldWidget.isActive) {
      setState(() {
        _showThumbnail = true;
        _pendingPlay = true;
      });
      _tryPlay();
    }

    if (!widget.isActive && oldWidget.isActive) {
      setState(() {
        _showThumbnail = true;
        _pendingPlay = false;
      });
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onStateChanged);
    super.dispose();
  }

  // Plays immediately if controller is ready.
  // If not ready, sets _pendingPlay — _onStateChanged will fire play()
  // as soon as the controller reaches a playable state.
  void _tryPlay() {
    final ctrl = _ctrl;
    if (ctrl == null) return;

    final state = ctrl.value.playerState;
    final isReady = state == PlayerState.paused ||
        state == PlayerState.cued ||
        state == PlayerState.ended ||
        state == PlayerState.buffering;

    if (isReady) {
      ctrl.seekTo(Duration.zero);
      ctrl.play();
      setState(() => _pendingPlay = false);
    } else {
      // PlayerState.unknown — WebView not ready yet.
      // onReady callback or _onStateChanged will consume _pendingPlay.
      setState(() => _pendingPlay = true);
    }
  }

  void _onStateChanged() {
    if (!mounted || _ctrl == null) return;

    final playing = _ctrl!.value.isPlaying;
    final state = _ctrl!.value.playerState;

    // Consume pending play as soon as controller becomes ready.
    // This handles the revisit case — onReady only fires once per
    // controller lifetime, so this listener is the trigger on revisit.
    if (_pendingPlay && widget.isActive) {
      final isReady = state == PlayerState.paused ||
          state == PlayerState.cued ||
          state == PlayerState.ended ||
          state == PlayerState.buffering;
      if (isReady) {
        _ctrl!.seekTo(Duration.zero);
        _ctrl!.play();
        _pendingPlay = false;
        return;
      }
    }

    if (_isPlaying != playing) {
      setState(() {
        _isPlaying = playing;
        if (playing) _showThumbnail = false;
      });
    }
  }

  void _togglePlayPause() {
    if (_ctrl == null) return;
    _isPlaying ? _ctrl!.pause() : _ctrl!.play();
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

  @override
  Widget build(BuildContext context) {
    final thumb = widget.video['thumbnail_url'] ?? '';
    final author = widget.video['author'] as String? ?? 'JoyScroll';
    final title = widget.video['title'] as String? ?? '';
    final content = widget.video['content'] as String? ?? '';
    final category = widget.video['category'] as String? ?? '';
    final createdAt = widget.video['created_at'] as String?;

    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: Colors.black),

      if (_ctrl != null)
        YoutubePlayerBuilder(
          player: YoutubePlayer(
            controller: _ctrl!,
            showVideoProgressIndicator: false,
            onReady: () {
              // Fires once per controller lifetime on first load.
              // For revisits, _pendingPlay + _onStateChanged handles it.
              if (mounted && widget.isActive) {
                _ctrl?.seekTo(Duration.zero);
                _ctrl?.play();
                setState(() => _pendingPlay = false);
              }
            },
            onEnded: (_) {
              // FIX 2: Manual loop since loop flag is ignored in v9
              if (widget.isActive) {
                _ctrl?.seekTo(Duration.zero);
                _ctrl?.play();
              }
            },
          ),
          builder: (context, player) => IgnorePointer(child: player),
        ),

      // Thumbnail visible until video starts playing
      if (_showThumbnail && thumb.isNotEmpty)
        CachedNetworkImage(
          imageUrl: thumb,
          fit: BoxFit.cover,
          memCacheWidth: 720,
          memCacheHeight: 1280,
        ),

      // Top gradient
      Positioned(
        top: 0, left: 0, right: 0,
        child: IgnorePointer(
          child: Container(
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xAA000000), Colors.transparent],
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
            height: 300,
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

      // Tap to play/pause
      Positioned.fill(
        child: GestureDetector(
          onTap: _togglePlayPause,
          behavior: HitTestBehavior.translucent,
        ),
      ),

      // Bottom info row
      Positioned(
        bottom: 24, left: 16, right: 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [

            // Left — video info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Author
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
                        author,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4)
                          ],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),

                  const SizedBox(height: 10),

                  // Title
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 4)
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      content.length > 120
                          ? '${content.substring(0, 120)}...'
                          : content,
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

                  // Timestamp + category
                  Row(children: [
                    Text(
                      _formatTimestamp(createdAt),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12),
                    ),
                    if (category.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: Colors.white24, width: 0.5),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ),
                    ],
                  ]),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Right — share button
            GestureDetector(
              onTap: widget.onShare,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(color: Colors.black54, blurRadius: 4)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}