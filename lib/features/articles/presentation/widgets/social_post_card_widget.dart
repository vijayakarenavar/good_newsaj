import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:good_news/core/themes/app_theme.dart';
import 'package:good_news/core/services/api_service.dart';

/// 📸 INSTAGRAM STYLE - Content-sized card only
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

  Future<int?> _extractUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    final directUserId = widget.post['user_id'] ??
        widget.post['author_id'] ??
        widget.post['created_by'] ??
        widget.post['posted_by_id'] ??
        widget.post['posted_by'] ??
        widget.post['creator_id'] ??
        widget.post['userId'] ??
        widget.post['authorId'];

    if (directUserId != null) {
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

    final authorName = widget.post['author'] ?? widget.post['display_name'];
    if (authorName != null && authorName.toString().isNotEmpty) {
      try {
        final searchResult =
        await ApiService.searchFriends(authorName.toString());
        if (searchResult['status'] == 'success' &&
            searchResult['data'] is List) {
          final users = searchResult['data'] as List;
          if (users.isNotEmpty) {
            var matchedUser = users.firstWhere(
                  (user) =>
              user['display_name']?.toString().toLowerCase() ==
                  authorName.toString().toLowerCase() ||
                  user['name']?.toString().toLowerCase() ==
                      authorName.toString().toLowerCase(),
              orElse: () => users.first,
            );
            final foundId = matchedUser['id'] ?? matchedUser['user_id'];
            if (foundId != null) {
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
        //'❌ Search failed: $e');
      }
    }
    return null;
  }

  Future<void> _sendFriendRequest() async {
    setState(() => _isSendingRequest = true);
    try {
      final userId = await _extractUserId();
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Unable to send friend request'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'Friend request sent to ${widget.post['author']}!')),
            ]),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else {
        setState(() => _isSendingRequest = false);
        if (mounted) {
          final errorMsg = response['message']?.toString() ??
              response['error']?.toString() ??
              'Failed to send friend request';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      setState(() => _isSendingRequest = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.post['id'] as String;
    final imageUrl = widget.post['image_url'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width > 600;

    final hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;
    final content = widget.post['content']?.toString().trim() ?? '';
    final hasContent = content.isNotEmpty;

    return Container(
      width: double.infinity,
      // ✅ FIX 2: horizontal padding around each card
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 16.0 : 12.0,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(isTablet ? 12.0 : 10.0),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          if (hasImage) _buildImage(context, imageUrl),
          _buildActions(context, postId),
          if (hasContent) _buildCaption(context, content),
          _buildTimestamp(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeColor = Theme.of(context).colorScheme.primary;
    final isTablet = MediaQuery.of(context).size.width > 600;
    final avatarRadius = isTablet ? 22.0 : 20.0;

    return Padding(
      padding: EdgeInsets.all(isTablet ? 12.0 : 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: themeColor,
            child: Text(
              widget.post['avatar'] ?? '',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: avatarRadius * 0.9,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.post['author'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16.0 : 15.0,
                    color: isDark ? Colors.white : const Color(0xFF262626),
                  ),
                ),
                Text(
                  _formatTimestamp(widget.post['created_at']),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? const Color(0xFFA8A8A8)
                        : const Color(0xFF8E8E8E),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeColor.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 13, color: themeColor),
                const SizedBox(width: 5),
                Text('Social',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: themeColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, dynamic imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showFullImage(context, imageUrl.toString()),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CachedNetworkImage(
          imageUrl: imageUrl.toString(),
          fit: BoxFit.cover,
          width: double.infinity,
          memCacheWidth: 800,
          memCacheHeight: 800,
          placeholder: (context, url) => Container(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFF0F0F0),
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFF0F0F0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded,
                    size: 48,
                    color: isDark
                        ? const Color(0xFF737373)
                        : const Color(0xFF8E8E8E)),
                const SizedBox(height: 8),
                Text('Failed to load image',
                    style: TextStyle(
                        color: isDark
                            ? const Color(0xFF737373)
                            : const Color(0xFF8E8E8E),
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : const Color(0xFF262626);
    final isTablet = MediaQuery.of(context).size.width > 600;
    final iconSize = isTablet ? 26.0 : 24.0;
    final likes = widget.post['likes'] ?? 0;
    final comments = widget.post['comments'] ?? 0;
    final pad = isTablet ? 12.0 : 8.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 6, pad, 4),
      child: Row(
        // ✅ FIX 1: crossAxisAlignment.center keeps all icons on same line
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ✅ FIX 1: Icon + count stacked, but icon row never shifts up
          // We use a fixed-height container for the icon+count block
          _actionButton(
            icon: widget.post['isLiked']
                ? Icons.favorite
                : Icons.favorite_border,
            color: widget.post['isLiked'] ? Colors.red : iconColor,
            size: iconSize,
            count: likes > 0 ? likes : null,
            isDark: isDark,
            onTap: () => widget.onToggleLike(widget.post),
          ),

          const SizedBox(width: 8),

          _actionButton(
            icon: Icons.mode_comment_outlined,
            color: iconColor,
            size: iconSize,
            count: comments > 0 ? comments : null,
            isDark: isDark,
            onTap: () => widget.onOpenCommentPage(postId, widget.post),
          ),

          const SizedBox(width: 8),

          // ✅ Share — wrapped same way so it aligns with others
          _actionButton(
            icon: Icons.send_outlined,
            color: iconColor,
            size: iconSize,
            count: null, // no count ever
            isDark: isDark,
            onTap: () => widget.onShare(widget.post),
          ),

          const Spacer(),

          // Add Friend button
          if (widget.onAddFriend != null)
            _isSendingRequest
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : TextButton(
              onPressed: _requestSent ? null : _sendFriendRequest,
              style: TextButton.styleFrom(
                backgroundColor: _requestSent
                    ? (isDark
                    ? const Color(0xFF262626)
                    : const Color(0xFFEFEFEF))
                    : Theme.of(context).colorScheme.primary,
                foregroundColor: _requestSent
                    ? (isDark
                    ? const Color(0xFFA8A8A8)
                    : const Color(0xFF8E8E8E))
                    : Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
                minimumSize: const Size(60, 30),
              ),
              child: Text(
                _requestSent ? 'Sent ✓' : 'Add',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ FIX 1: _actionButton — icon always at TOP, count below
  // All buttons have same structure so they never misalign
  Widget _actionButton({
    required IconData icon,
    required Color color,
    required double size,
    required int? count,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start, // ✅ icon always at top
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ✅ Icon always same size regardless of count
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: size),
          ),
        ),
        // ✅ Count: always same fixed height (14px) so spacing is consistent
        // Empty text when no count keeps height same as when count exists
        SizedBox(
          height: 14,
          child: count != null
              ? Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? const Color(0xFFA8A8A8)
                  : const Color(0xFF8E8E8E),
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCaption(BuildContext context, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF262626),
            height: 1.25,
          ),
          children: [
            TextSpan(
              text: '${widget.post['author']} ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: content),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestamp(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Text(
        _formatTimestamp(widget.post['created_at']).toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          color: isDark ? const Color(0xFFA8A8A8) : const Color(0xFF8E8E8E),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'just now';
    try {
      final dateTime = HttpDate.parse(timestamp);
      final diff = DateTime.now().difference(dateTime);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      return '${(diff.inDays / 30).floor()}mo ago';
    } catch (_) {
      return 'just now';
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
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
                  placeholder: (context, url) => Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 48),
                  ),
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
                      color: Colors.black54, shape: BoxShape.circle),
                  child:
                  const Icon(Icons.close, color: Colors.white, size: 24),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
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
                      Colors.transparent
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
                          backgroundColor:
                          Theme.of(context).colorScheme.primary,
                          child: Text(widget.post['avatar'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.post['author'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Colors.white)),
                              Text(
                                  _formatTimestamp(widget.post['created_at']),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.post['content'] ?? '',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, height: 1.4),
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