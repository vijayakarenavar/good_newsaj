import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:good_news/core/themes/app_theme.dart';
import 'package:good_news/core/services/api_service.dart';

/// 🔥 SMART VERSION - Tries multiple methods to find user_id
/// This version will work with whatever fields your backend provides!
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
  int? _cachedUserId; // Cache the found user_id

  /// 🔥 SMART METHOD: Extract user_id from post using multiple strategies
  Future<int?> _extractUserId() async {
    // If already cached, return it
    if (_cachedUserId != null) return _cachedUserId;

    print('🔍 ========== EXTRACTING USER ID ==========');
    print('🔍 Available post keys: ${widget.post.keys.toList()}');
    print('🔍 Full post data: ${widget.post}');

    // ✅ STRATEGY 1: Try common user_id field names
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

      // Convert to int
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

    print('⚠️ No direct user_id found in post');

    // ✅ STRATEGY 2: Search by author name
    final authorName = widget.post['author'] ?? widget.post['display_name'];
    if (authorName != null && authorName.toString().isNotEmpty) {
      print('🔍 Attempting to search for user by name: $authorName');

      try {
        final searchResult = await ApiService.searchFriends(authorName.toString());

        if (searchResult['status'] == 'success' && searchResult['data'] is List) {
          final users = searchResult['data'] as List;
          print('🔍 Search returned ${users.length} users');

          if (users.isNotEmpty) {
            // Try to find exact match first
            var matchedUser = users.firstWhere(
                  (user) => user['display_name']?.toString().toLowerCase() == authorName.toString().toLowerCase() ||
                  user['name']?.toString().toLowerCase() == authorName.toString().toLowerCase(),
              orElse: () => users.first, // Fallback to first result
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

  /// 📤 Send friend request to post author
  Future<void> _sendFriendRequest() async {
    print('🚀 Starting friend request process...');

    setState(() {
      _isSendingRequest = true;
    });

    try {
      // Extract user_id using smart method
      final userId = await _extractUserId();

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unable to send friend request',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Could not find user ID for ${widget.post['author']}',
                      style: TextStyle(fontSize: 12)),
                  SizedBox(height: 4),
                  Text('Available fields: ${widget.post.keys.take(5).join(", ")}...',
                      style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }

        setState(() {
          _isSendingRequest = false;
        });
        return;
      }

      print('📤 Sending friend request to userId: $userId');

      // ✅ Use ApiService.sendFriendRequest
      final response = await ApiService.sendFriendRequest(userId);

      print('📥 Friend request response: $response');

      if (response['status'] == 'success') {
        setState(() {
          _requestSent = true;
          _isSendingRequest = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Friend request sent to ${widget.post['author']}! ✅'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isSendingRequest = false;
        });

        if (mounted) {
          final errorMsg = response['message']?.toString() ??
              response['error']?.toString() ??
              'Failed to send friend request';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Exception in _sendFriendRequest: $e');

      setState(() {
        _isSendingRequest = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.post['id'] as String;
    final imageUrl = widget.post['image_url'];
    final themeColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildHeader(context),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl != null && imageUrl.toString().isNotEmpty)
                    _buildImage(context, imageUrl),
                  _buildContent(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(context, postId, themeColor),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timestampColor = isDark ? Colors.white70 : Colors.grey[600];

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          child: Text(
            widget.post['avatar'],
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
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
                  fontSize: 18,
                ),
              ),
              Text(
                _formatTimestamp(widget.post['created_at']),
                style: TextStyle(
                  color: timestampColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '👥 Social',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImage(BuildContext context, dynamic imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderBgColor = isDark ? Colors.grey[850] : Colors.grey[200];
    final errorIconColor = isDark ? Colors.grey[600] : Colors.grey[400];
    final errorTextColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return GestureDetector(
      onTap: () => _showFullImageWithContent(context, imageUrl.toString()),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400),
        margin: const EdgeInsets.only(bottom: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl.toString(),
            fit: BoxFit.cover,
            width: double.infinity,
            memCacheWidth: 800,
            memCacheHeight: 900,
            placeholder: (context, url) => Container(
              height: 300,
              color: placeholderBgColor,
              child: Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: 300,
              color: placeholderBgColor,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.broken_image, size: 64, color: errorIconColor),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load image',
                    style: TextStyle(color: errorTextColor, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentColor = isDark ? Colors.white70 : Colors.grey[900];

    return Text(
      widget.post['content'],
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        height: 1.6,
        fontSize: 16,
        color: contentColor,
      ),
      maxLines: 10,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildActionButtons(BuildContext context, String postId, Color themeColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lighterThemeColor = themeColor.withOpacity(0.95);

    Widget _buildHeartIcon(IconData icon, bool isSelected, bool isLikeButton) {
      if (isLikeButton) {
        if (isSelected) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.favorite, size: 24, color: Colors.white),
              Icon(Icons.favorite, size: 22, color: Colors.red),
            ],
          );
        } else {
          return Icon(Icons.favorite_border, size: 22, color: Colors.white);
        }
      }
      return Icon(icon, size: 22, color: Colors.white);
    }

    Widget _buildSolidButton({
      IconData? icon,
      String? label,
      required VoidCallback onPressed,
      bool isLoading = false,
      bool isSelected = false,
      bool isLikeButton = false,
      bool isDisabled = false,
    }) {
      return Expanded(
        child: Container(
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isDisabled
                ? Colors.grey.withOpacity(0.5)
                : lighterThemeColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDisabled ? [] : [
              BoxShadow(
                color: lighterThemeColor.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: isDisabled ? null : onPressed,
              splashColor: Colors.white.withOpacity(0.3),
              child: Center(
                child: isLoading
                    ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : icon != null
                    ? _buildHeartIcon(icon, isSelected, isLikeButton)
                    : Text(
                  label ?? 'Add',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          _buildSolidButton(
            icon: widget.post['isLiked'] ? Icons.favorite : Icons.favorite_border,
            onPressed: () => widget.onToggleLike(widget.post),
            isSelected: widget.post['isLiked'],
            isLikeButton: true,
          ),
          _buildSolidButton(
            icon: Icons.comment_outlined,
            onPressed: () => widget.onOpenCommentPage(postId, widget.post),
          ),
          _buildSolidButton(
            icon: Icons.share_outlined,
            onPressed: () => widget.onShare(widget.post),
          ),
          if (widget.onAddFriend != null)
            _buildSolidButton(
              label: _requestSent ? 'Sent ✓' : 'Add',
              onPressed: _sendFriendRequest,
              isLoading: _isSendingRequest,
              isDisabled: _requestSent,
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'Just now';
    try {
      final dateTime = HttpDate.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Just now';
    }
  }

  void _showFullImageWithContent(BuildContext context, String imageUrl) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Flexible(
                flex: 3,
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.contain,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              child: Text(
                                widget.post['avatar'],
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
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
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  Text(
                                    _formatTimestamp(widget.post['created_at']),
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(
                          widget.post['content'],
                          style: TextStyle(
                            height: 1.6,
                            fontSize: 15,
                            color: isDark ? Colors.white70 : Colors.grey[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}