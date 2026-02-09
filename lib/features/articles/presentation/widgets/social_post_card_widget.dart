import 'package:flutter/material.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget for displaying a social post card with comments and friend actions
class SocialPostCardWidget extends StatelessWidget {
  final Map<String, dynamic> post;
  final List<Map<String, dynamic>> comments;
  final bool showComments;
  final bool isLoadingComments;
  final TextEditingController commentController;
  final Function(Map<String, dynamic>) onToggleLike;
  final Function(String) onToggleComments;
  final Function(String) onPostComment;
  final Function(Map<String, dynamic>) onShare;
  final Function(Map<String, dynamic>)? onAddFriend; // 👈 NEW: Optional add friend callback
  final Function(BuildContext, String) onShowFullImage;

  const SocialPostCardWidget({
    Key? key,
    required this.post,
    required this.comments,
    required this.showComments,
    required this.isLoadingComments,
    required this.commentController,
    required this.onToggleLike,
    required this.onToggleComments,
    required this.onPostComment,
    required this.onShare,
    this.onAddFriend, // 👈 NEW: Optional parameter
    required this.onShowFullImage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final postId = post['id'] as String;
    final imageUrl = post['image_url'];

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Header
          _buildHeader(context),

          const SizedBox(height: 24),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image
                  if (imageUrl != null && imageUrl.toString().isNotEmpty)
                    _buildImage(context, imageUrl),

                  // Content
                  _buildContent(context),

                  const SizedBox(height: 24),

                  // Comments Section
                  if (showComments) _buildCommentsSection(context),
                ],
              ),
            ),
          ),

          // Action Buttons - UPDATED WITH ADD FRIEND BUTTON (SAME SIZE + TEXT ONLY)
          _buildActionButtons(context, postId),
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
            post['avatar'],
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
                post['author'],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              Text(
                _formatTimestamp(post['created_at']),
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
      onTap: () => onShowFullImage(context, imageUrl.toString()),
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
      post['content'],
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        height: 1.6,
        fontSize: 16,
        color: contentColor,
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emptyTextColor = isDark ? Colors.grey[500] : Colors.grey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: isDark ? Colors.grey[800] : null),
        const SizedBox(height: 16),

        Row(
          children: [
            const Text(
              'Comments',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => onToggleComments(post['id'] as String),
              child: const Text('Hide'),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (isLoadingComments)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          )
        else if (comments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'No comments yet. Be the first!',
                style: TextStyle(color: emptyTextColor),
              ),
            ),
          )
        else
          ...comments.map((comment) => _buildCommentItem(context, comment)),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildCommentItem(BuildContext context, Map<String, dynamic> comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timestampColor = isDark ? Colors.white60 : Colors.grey[600];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            child: Text(
              comment['avatar'],
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment['author'],
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['content'],
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  comment['timestamp'],
                  style: TextStyle(
                    color: timestampColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED METHOD: Same size buttons + "Add" button with TEXT ONLY (no icon)
  Widget _buildActionButtons(BuildContext context, String postId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    // ✅ EXACT SAME COLORS AS YOUR ARTICLE CARD'S "READ FULL ARTICLE" BUTTON
    const Color PRIMARY_GREEN = Color(0xFF10B981);
    const Color PRIMARY_PINK = Color(0xFFEC4899);

    // 👇 REVISED: Gradient button builder with NULLABLE icon + fixed size
    Widget _buildGradientButton({
      IconData? icon, // ✅ Nullable - icon optional
      String? label,
      required VoidCallback onPressed,
      bool isLoading = false,
      bool isSelected = false,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withOpacity(0.2),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [PRIMARY_GREEN, PRIMARY_PINK],
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: PRIMARY_GREEN.withOpacity(0.6),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SizedBox(
              height: 40, // ✅ Fixed height for ALL buttons
              width: double.infinity,
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
                    ? Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.redAccent : Colors.white,
                )
                    : Text( // ✅ ONLY TEXT WHEN icon IS NULL
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
      padding: const EdgeInsets.only(top: 12, bottom: 10),
      child: Column(
        children: [
          // 👇 ALL BUTTONS SAME SIZE (60x40) + "Add" button TEXT ONLY
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like Button - ICON ONLY
              SizedBox(
                width: 60,
                child: _buildGradientButton(
                  icon: post['isLiked'] ? Icons.favorite : Icons.favorite_border,
                  onPressed: () => onToggleLike(post),
                  isSelected: post['isLiked'],
                ),
              ),

              // Comment Button - ICON ONLY
              SizedBox(
                width: 60,
                child: _buildGradientButton(
                  icon: showComments ? Icons.comment : Icons.comment_outlined,
                  onPressed: isLoadingComments ? () {} : () => onToggleComments(postId),
                  isLoading: isLoadingComments,
                ),
              ),

              // Share Button - ICON ONLY
              SizedBox(
                width: 60,
                child: _buildGradientButton(
                  icon: Icons.share_outlined,
                  onPressed: () => onShare(post),
                ),
              ),

              // 👉 Add Friend Button - TEXT ONLY (NO ICON)
              if (onAddFriend != null)
                SizedBox(
                  width: 60, // ✅ Same width as others
                  child: _buildGradientButton(
                    icon: null, // ✅ ICON NAKO - null pass kela
                    label: 'Add', // ✅ FKT TEXT
                    onPressed: () => onAddFriend!(post),
                  ),
                ),
            ],
          ),

          // Comment input (only visible when comments are open) - UNCHANGED
          if (showComments) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: commentController,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: borderColor!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onPostComment(postId),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15), // Match article card green
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => onPostComment(postId),
                    icon: const Icon(Icons.send, color: Color(0xFF10B981), size: 20),
                  ),
                ),
              ],
            ),
          ],
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
}