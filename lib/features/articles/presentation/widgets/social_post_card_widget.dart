import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/social_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FriendStatus { none, pending, friend }

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
  bool _isCancellingRequest = false;
  bool _isCheckingStatus = true;
  FriendStatus _friendStatus = FriendStatus.none;
  int? _cachedUserId;

  static const String _prefPrefix = 'friend_status_';

  @override
  void initState() {
    super.initState();
    _initFriendStatus();
  }

  Future<void> _initFriendStatus() async {
    final userId = await _extractUserId();

    if (userId == null) {
      if (mounted) setState(() => _isCheckingStatus = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedStatus = prefs.getString('$_prefPrefix$userId');

    if (savedStatus == 'friend') {
      if (mounted) {
        setState(() {
          _friendStatus = FriendStatus.friend;
          _isCheckingStatus = false;
        });
      }
      return;
    }

    if (savedStatus == 'pending') {
      if (mounted) {
        setState(() {
          _friendStatus = FriendStatus.pending;
          _isCheckingStatus = false;
        });
      }
      _checkIfNowFriend(userId);
      return;
    }

    await _checkFriendStatusFromAPI(userId);
    if (mounted) setState(() => _isCheckingStatus = false);
  }

  Future<void> _checkFriendStatusFromAPI(int userId) async {
    try {
      final response = await SocialApiService.getFriends();
      if (response['status'] == 'success') {
        final friendsList = response['data'] as List? ?? [];
        final isFriend = friendsList.any((friend) {
          final fId = friend['id'] ?? friend['user_id'] ?? friend['friend_id'];
          if (fId == null) return false;
          final fIdInt = fId is int ? fId : int.tryParse(fId.toString());
          return fIdInt == userId;
        });
        if (isFriend) {
          await _saveFriendStatus(userId, FriendStatus.friend);
          if (mounted) setState(() => _friendStatus = FriendStatus.friend);
          return;
        }
      }
      if (mounted) setState(() => _friendStatus = FriendStatus.none);
    } catch (e) {
      print('❌ _checkFriendStatusFromAPI failed: $e');
      if (mounted) setState(() => _friendStatus = FriendStatus.none);
    }
  }

  Future<void> _checkIfNowFriend(int userId) async {
    try {
      final response = await SocialApiService.getFriends();
      if (response['status'] == 'success') {
        final friendsList = response['data'] as List? ?? [];
        final isFriend = friendsList.any((friend) {
          final fId = friend['id'] ?? friend['user_id'] ?? friend['friend_id'];
          if (fId == null) return false;
          final fIdInt = fId is int ? fId : int.tryParse(fId.toString());
          return fIdInt == userId;
        });
        if (isFriend) {
          await _saveFriendStatus(userId, FriendStatus.friend);
          if (mounted) setState(() => _friendStatus = FriendStatus.friend);
        }
      }
    } catch (e) {
      print('❌ _checkIfNowFriend failed: $e');
    }
  }

  Future<void> _saveFriendStatus(int userId, FriendStatus status) async {
    final prefs = await SharedPreferences.getInstance();
    String value;
    switch (status) {
      case FriendStatus.pending:
        value = 'pending';
        break;
      case FriendStatus.friend:
        value = 'friend';
        break;
      default:
        value = 'none';
    }
    await prefs.setString('$_prefPrefix$userId', value);
  }

  Future<int?> _extractUserId() async {
    if (_cachedUserId != null) return _cachedUserId;

    final directUserId = widget.post['user_id'] ??
        widget.post['author_id'] ??
        widget.post['created_by'] ??
        widget.post['posted_by_id'] ??
        widget.post['creator_id'];

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
        final searchResult = await ApiService.searchFriends(authorName.toString());
        if (searchResult['status'] == 'success' && searchResult['data'] is List) {
          final users = searchResult['data'] as List;
          if (users.isNotEmpty) {
            final matchedUser = users.firstWhere(
                  (user) =>
              user['display_name']?.toString().toLowerCase() ==
                  authorName.toString().toLowerCase() ||
                  user['name']?.toString().toLowerCase() ==
                      authorName.toString().toLowerCase(),
              orElse: () => users.first,
            );
            final foundId = matchedUser['id'] ?? matchedUser['user_id'];
            if (foundId != null) {
              final parsed = foundId is int ? foundId : int.tryParse(foundId.toString());
              if (parsed != null) {
                _cachedUserId = parsed;
                return parsed;
              }
            }
          }
        }
      } catch (e) {
        print('❌ Search failed: $e');
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
            content: const Text('Unable to find user. Please try again.'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
          setState(() => _isSendingRequest = false);
        }
        return;
      }

      final response = await ApiService.sendFriendRequest(userId);

      if (response['status'] == 'success') {
        await _saveFriendStatus(userId, FriendStatus.pending);
        if (mounted) {
          setState(() {
            _friendStatus = FriendStatus.pending;
            _isSendingRequest = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Friend request sent to ${widget.post['author']}!')),
            ]),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      } else {
        if (mounted) {
          setState(() => _isSendingRequest = false);
          final errorMsg = response['message']?.toString() ??
              response['error']?.toString() ??
              'Failed to send friend request';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingRequest = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  // ✅ NO POPUP - Sent click केलं तर directly Add button येतो
  Future<void> _cancelFriendRequest() async {
    final userId = await _extractUserId();
    if (userId == null) return;

    setState(() => _isCancellingRequest = true);

    try {
      final response = await ApiService.cancelFriendRequest(userId);
      await _saveFriendStatus(userId, FriendStatus.none);
      if (mounted) {
        setState(() {
          _friendStatus = FriendStatus.none;
          _isCancellingRequest = false;
        });
      }
    } catch (e) {
      await _saveFriendStatus(userId, FriendStatus.none);
      if (mounted) {
        setState(() {
          _friendStatus = FriendStatus.none;
          _isCancellingRequest = false;
        });
      }
      print('⚠️ Cancel request failed, cancelled locally: $e');
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
      margin: EdgeInsets.symmetric(horizontal: isTablet ? 16.0 : 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF262626) : const Color(0xFFDBDBDB),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(isTablet ? 12.0 : 10.0),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.06),
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
            child: Text(widget.post['avatar'] ?? '',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: avatarRadius * 0.9)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.post['author'] ?? '',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 16.0 : 15.0,
                        color: isDark ? Colors.white : const Color(0xFF262626))),
                Text(_formatTimestamp(widget.post['created_at']),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFFA8A8A8) : const Color(0xFF8E8E8E))),
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
                Text('Social', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: themeColor)),
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
            child: Center(child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary, strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            color: isDark ? const Color(0xFF262626) : const Color(0xFFF0F0F0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_rounded, size: 48,
                    color: isDark ? const Color(0xFF737373) : const Color(0xFF8E8E8E)),
                const SizedBox(height: 8),
                Text('Failed to load image',
                    style: TextStyle(
                        color: isDark ? const Color(0xFF737373) : const Color(0xFF8E8E8E),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _actionButton(
            icon: widget.post['isLiked'] ? Icons.favorite : Icons.favorite_border,
            color: widget.post['isLiked'] ? Colors.red : iconColor,
            size: iconSize, count: likes > 0 ? likes : null, isDark: isDark,
            onTap: () => widget.onToggleLike(widget.post),
          ),
          const SizedBox(width: 8),
          _actionButton(
            icon: Icons.mode_comment_outlined, color: iconColor, size: iconSize,
            count: comments > 0 ? comments : null, isDark: isDark,
            onTap: () => widget.onOpenCommentPage(postId, widget.post),
          ),
          const SizedBox(width: 8),
          _actionButton(
            icon: Icons.send_outlined, color: iconColor, size: iconSize,
            count: null, isDark: isDark, onTap: () => widget.onShare(widget.post),
          ),
          const Spacer(),
          if (widget.onAddFriend != null)
            (_isCheckingStatus || _isSendingRequest || _isCancellingRequest)
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : _buildFriendButton(context, isDark),
        ],
      ),
    );
  }

  Widget _buildFriendButton(BuildContext context, bool isDark) {
    switch (_friendStatus) {

    // STATE 1: Already Friends
      case FriendStatus.friend:
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A3A5C) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade300, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 5),
                Text('Friends',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade600)),
              ],
            ),
          ),
        );

    // STATE 2: Sent - click केलं तर direct Add button (no popup)
      case FriendStatus.pending:
        return GestureDetector(
          onTap: _cancelFriendRequest,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 13,
                      color: isDark ? Colors.white54 : Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text('Sent',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.grey.shade600)),
                  const SizedBox(width: 3),
                  Icon(Icons.close, size: 11,
                      color: isDark ? Colors.white38 : Colors.grey.shade400),
                ],
              ),
            ),
          ),
        );

    // STATE 3: Add Button - Green Glow
      case FriendStatus.none:
      default:
        return GestureDetector(
          onTap: _sendFriendRequest,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF43A047)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.45),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_1, size: 13, color: Colors.white),
                  SizedBox(width: 5),
                  Text('Add',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
          ),
        );
    }
  }

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
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: color, size: size),
          ),
        ),
        SizedBox(
          height: 14,
          child: count != null
              ? Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFFA8A8A8) : const Color(0xFF8E8E8E)))
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
              height: 1.25),
          children: [
            TextSpan(
                text: '${widget.post['author']} ',
                style: const TextStyle(fontWeight: FontWeight.w600)),
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
            letterSpacing: 0.2),
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
                          color: Theme.of(context).colorScheme.primary)),
                  errorWidget: (context, url, error) =>
                  const Center(child: Icon(Icons.error, color: Colors.white, size: 48)),
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
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
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
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
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
                            Text(_formatTimestamp(widget.post['created_at']),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ]),
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
