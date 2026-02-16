import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:good_news/core/themes/app_theme.dart';
import 'package:good_news/core/services/api_service.dart';

/// 📸 INSTAGRAM STYLE - With all original features
class SocialPostCardWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  final TextEditingController commentController;
  final Function(Map<String, dynamic>) onToggleLike;
  final Function(Map<String, dynamic>) onShare;
  final Function(Map<String, dynamic>)? onAddFriend;
  final Function(BuildContext, String) onShowFullImage;
  final Function(String, Map<String, dynamic>) onOpenCommentPage;

  const SocialPostCardWidget({
    Key? key,
    required this.post,
    required this.commentController,
    required this.onToggleLike,
    required this.onShare,
    this.onAddFriend,
    required this.onShowFullImage,
    required this.onOpenCommentPage,
  }) : super(key: key);

  @override
  State<SocialPostCardWidget> createState() => _SocialPostCardWidgetState();
}

class _SocialPostCardWidgetState extends State<SocialPostCardWidget> {
  bool _isSendingRequest = false;
  bool _requestSent = false;
  int? _cachedUserId;

  /// Extract user_id from post using multiple strategies
  Future<int?> _extractUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    print('🔍 ========== EXTRACTING USER ID ==========');
    print('🔍 Available post keys: ${widget.post.keys.toList()}');

    // STRATEGY 1: Try common user_id field names
    final directUserId = widget.post['user_id'] ??
        widget.post['author_id'] ??
        widget.post['created_by'] ??
        widget.post['posted_by_id'] ??
        widget.post['posted_by'] ??
        widget.post['creator_id'] ??
        widget.post['userId'] ??
        widget.post['authorId'];

    if (directUserId != null) {
      print('✅ Found user_id directly: $directUserId');
      if (directUserId is int) {
        _cachedUserId = directUserId;
        return directUserId;
      } else if (directUserId is String) {
        final parsed = int.tryParse(directUserId);
        if (parsed != null) {
          _cachedUserId = parsed;
          return parsed;
        }
      }
    }

    // STRATEGY 2: Search by author name
    final authorName = widget.post['author'] ?? widget.post['display_name'];
    if (authorName != null && authorName.toString().isNotEmpty) {
      print('🔍 Attempting to search for user by name: $authorName');

      try {
        final searchResult = await ApiService.searchFriends(authorName.toString());

        if (searchResult['status'] == 'success' && searchResult['data'] is List) {
          final users = searchResult['data'] as List;
          if (users.isNotEmpty) {
            var matchedUser = users.firstWhere(
                  (user) => user['display_name']?.toString().toLowerCase() == authorName.toString().toLowerCase() ||
                  user['name']?.toString().toLowerCase() == authorName.toString().toLowerCase(),
              orElse: () => users.first,
            );

            final foundId = matchedUser['id'] ?? matchedUser['user_id'];
            if (foundId != null) {
              print('✅ Found user via search: ID = $foundId');
              if (foundId is int) {
                _cachedUserId = foundId;
                return foundId;
              } else if (foundId is String) {
                final parsed = int.tryParse(foundId);
                if (parsed != null) {
                  _cachedUserId = parsed;
                  return parsed;
                }
              }
            }
          }
        }
      } catch (e) {
        print('❌ Search failed: $e');
      }
    }

    print('❌ Could not extract user_id using any method');
    return null;
  }

  /// Send friend request to post author
  Future<void> _sendFriendRequest() async {
    setState(() => _isSendingRequest = true);

    try {
      final userId = await _extractUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to send friend request'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        setState(() => _isSendingRequest = false);
        return;
      }

      final response = await ApiService.sendFriendRequest(userId);

      if (response['status'] == 'success') {
        setState(() {
          _requestSent = true;
          _isSendingRequest = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Friend request sent to ${widget.post['author']}!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } else {
        setState(() => _isSendingRequest = false);
        if (mounted) {
          final errorMsg = response['message']?.toString() ??
              response['error']?.toString() ??
              'Failed to send friend request';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSendingRequest = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.post['id'] as String;
    final imageUrl = widget.post['image_url'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border.all(
          color: isDark ? Color(0xFF262626) : Color(0xFFDBDBDB),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInstagramHeader(context),
          if (imageUrl != null && imageUrl.toString().isNotEmpty)
            _buildInstagramImage(context, imageUrl),
          _buildInstagramActions(context, postId),
          _buildInstagramLikes(context),
          _buildInstagramCaption(context),
          _buildInstagramViewComments(context, postId),
          _buildInstagramTimestamp(context),
          _buildInstagramAddComment(context),
        ],
      ),
    );
  }

  /// 📱 Instagram Header
  Widget _buildInstagramHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Story Ring + Avatar
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  themeColor,
                  themeColor.withOpacity(0.7),
                ],
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.black : Colors.white,
              ),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: themeColor,
                child: Text(
                  widget.post['avatar'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.post['author'],
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDark ? Colors.white : Color(0xFF262626),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '📍 Article',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Color(0xFFA8A8A8) : Color(0xFF8E8E8E),
                  ),
                ),
              ],
            ),
          ),

          // More Button
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: isDark ? Colors.white : Color(0xFF262626),
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  /// 📷 Instagram Image
  Widget _buildInstagramImage(BuildContext context, dynamic imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _showFullImageWithContent(context, imageUrl.toString()),
      child: CachedNetworkImage(
        imageUrl: imageUrl.toString(),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 400,
        memCacheWidth: 800,
        memCacheHeight: 900,
        placeholder: (context, url) => Container(
          height: 400,
          color: isDark ? Color(0xFF262626) : Color(0xFFF0F0F0),
          child: Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          height: 400,
          color: isDark ? Color(0xFF262626) : Color(0xFFF0F0F0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_rounded,
                size: 48,
                color: isDark ? Color(0xFF737373) : Color(0xFF8E8E8E),
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load image',
                style: TextStyle(
                  color: isDark ? Color(0xFF737373) : Color(0xFF8E8E8E),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🎬 Instagram Actions (Like, Comment, Share, Save)
  Widget _buildInstagramActions(BuildContext context, String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Color(0xFF262626);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Like Button
          IconButton(
            icon: Icon(
              widget.post['isLiked'] ? Icons.favorite : Icons.favorite_border,
              color: widget.post['isLiked'] ? Colors.red : iconColor,
              size: 26,
            ),
            onPressed: () => widget.onToggleLike(widget.post),
          ),

          // Comment Button
          IconButton(
            icon: Icon(
              Icons.mode_comment_outlined,
              color: iconColor,
              size: 26,
            ),
            onPressed: () => widget.onOpenCommentPage(postId, widget.post),
          ),

          // Share Button
          IconButton(
            icon: Icon(
              Icons.send_outlined,
              color: iconColor,
              size: 26,
            ),
            onPressed: () => widget.onShare(widget.post),
          ),

          const Spacer(),

          // Add Friend Button (if available)
          if (widget.onAddFriend != null)
            _isSendingRequest
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            )
                : TextButton(
              onPressed: _requestSent ? null : _sendFriendRequest,
              style: TextButton.styleFrom(
                backgroundColor: _requestSent
                    ? (isDark ? Color(0xFF262626) : Color(0xFFEFEFEF))
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                minimumSize: Size(60, 32),
              ),
              child: Text(
                _requestSent ? 'Sent ✓' : 'Follow',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 💖 Instagram Likes Section
  Widget _buildInstagramLikes(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final likes = widget.post['likes'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        '$likes likes',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isDark ? Colors.white : Color(0xFF262626),
        ),
      ),
    );
  }

  /// 📝 Instagram Caption
  Widget _buildInstagramCaption(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = widget.post['content'] ?? '';
    final displayContent = content.length > 100 ? content.substring(0, 100) : content;
    final hasMore = content.length > 100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : Color(0xFF262626),
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: widget.post['author'] + ' ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: displayContent),
            if (hasMore)
              TextSpan(
                text: '... more',
                style: TextStyle(
                  color: isDark ? Color(0xFFA8A8A8) : Color(0xFF8E8E8E),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 💬 Instagram View Comments
  Widget _buildInstagramViewComments(BuildContext context, String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comments = widget.post['comments'] ?? 0;

    return GestureDetector(
      onTap: () => widget.onOpenCommentPage(postId, widget.post),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          'View all $comments comments',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Color(0xFFA8A8A8) : Color(0xFF8E8E8E),
          ),
        ),
      ),
    );
  }

  /// ⏰ Instagram Timestamp
  Widget _buildInstagramTimestamp(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        _formatTimestamp(widget.post['created_at']).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: isDark ? Color(0xFFA8A8A8) : Color(0xFF8E8E8E),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// ✍️ Instagram Add Comment
  Widget _buildInstagramAddComment(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Color(0xFF262626) : Color(0xFFEFEFEF),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Color(0xFFA8A8A8) : Color(0xFF8E8E8E),
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Color(0xFF262626),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Post',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  /// 🕐 Format Timestamp (Instagram style)
  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'just now';
    try {
      final dateTime = HttpDate.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()}w ago';
      } else {
        return '${(difference.inDays / 30).floor()}mo ago';
      }
    } catch (e) {
      return 'just now';
    }
  }

  /// 🖼️ Show Full Image with Content (Instagram Style)
  void _showFullImageWithContent(BuildContext context, String imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Image
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Icon(Icons.error, color: Colors.white, size: 48),
                  ),
                ),
              ),
            ),

            // Close Button
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Bottom Info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            widget.post['avatar'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.post['author'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _formatTimestamp(widget.post['created_at']),
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.post['content'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}