import 'package:flutter/material.dart';
import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/social_api_service.dart';
import 'package:good_news/core/services/preferences_service.dart';

/// 🟢 ATTRACTIVE COMMENT PAGE WITH GREEN THEME AND FULL API INTEGRATION
class CommentPage extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> post;

  const CommentPage({
    Key? key,
    required this.postId,
    required this.post,
  }) : super(key: key);

  @override
  State<CommentPage> createState() => _CommentPageState();
}

class _CommentPageState extends State<CommentPage> {
  final TextEditingController _commentController = TextEditingController();

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = false;
  bool _isPostingComment = false;

  String? _currentUserName;
  String? _currentUserProfilePicture;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// 👤 Load current user info
  Future<void> _loadCurrentUser() async {
    try {
      final userName = await PreferencesService.getUserDisplayName();
      setState(() {
        _currentUserName = userName ?? 'You';
        // Profile picture can be added later if available in preferences
        _currentUserProfilePicture = null;
      });
    } catch (e) {
      //'Error loading current user: $e');
    }
  }

  /// 📥 Load comments from API using SocialApiService
  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
    });

    try {
      final postIdInt = int.tryParse(widget.postId);

      if (postIdInt == null) {
        throw Exception('Invalid post ID: ${widget.postId}');
      }

      //'📥 Loading comments for post: $postIdInt');

      // ✅ Use SocialApiService.getComments
      final response = await SocialApiService.getComments(postIdInt);

      //'✅ Comments response: $response');

      if (response['status'] == 'success') {
        final commentsList = response['comments'] as List? ?? [];

        setState(() {
          _comments = commentsList
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
          _isLoadingComments = false;
        });

        //'✅ Loaded ${_comments.length} comments');
      } else {
        setState(() {
          _comments = [];
          _isLoadingComments = false;
        });

        //'⚠️ Failed to load comments: ${response['error']}');
      }
    } catch (e) {
      //'❌ Error loading comments: $e');
      setState(() {
        _comments = [];
        _isLoadingComments = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load comments'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 📤 Post comment to API using SocialApiService
  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isPostingComment = true;
    });

    try {
      final commentText = _commentController.text.trim();
      final postIdInt = int.tryParse(widget.postId);

      if (postIdInt == null) {
        throw Exception('Invalid post ID: ${widget.postId}');
      }

      //'📤 Posting comment on post: $postIdInt');
      //'📝 Comment text: $commentText');

      // ✅ Use SocialApiService.createComment which uses 'content' field
      final response = await SocialApiService.createComment(postIdInt, commentText);

      //'✅ Post comment response: $response');
      //'📊 Response status: ${response['status']}');

      if (response['status'] == 'success') {
        _commentController.clear();

        //'✅ Comment posted successfully, reloading comments...');

        // Reload comments to get the latest list
        await _loadComments();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Comment posted successfully! ✅'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        //'⚠️ Comment post failed: ${response['error']}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['error']?.toString() ?? 'Failed to post comment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      //'❌ Error posting comment: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPostingComment = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Comments',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // 🎨 Green gradient header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2E7D32),
                  const Color(0xFF4CAF50),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: widget.post['profile_picture'] != null
                      ? NetworkImage(widget.post['profile_picture'])
                      : null,
                  backgroundColor: Colors.white,
                  child: widget.post['profile_picture'] == null
                      ? const Icon(Icons.person, color: Color(0xFF2E7D32))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post['full_name'] ?? widget.post['author'] ?? 'Unknown User',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${_comments.length} ${_comments.length == 1 ? 'Comment' : 'Comments'}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 💬 Comments list
          Expanded(
            child: _isLoadingComments
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2E7D32),
              ),
            )
                : _comments.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: 64,
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No comments yet',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to comment!',
                    style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              color: const Color(0xFF2E7D32),
              onRefresh: _loadComments,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _comments.length,
                itemBuilder: (context, index) {
                  final comment = _comments[index];
                  return _buildCommentItem(comment);
                },
              ),
            ),
          ),

          // ✍️ Comment input section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: _currentUserProfilePicture != null
                        ? NetworkImage(_currentUserProfilePicture!)
                        : null,
                    backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                    child: _currentUserProfilePicture == null
                        ? const Icon(
                      Icons.person,
                      size: 20,
                      color: Color(0xFF2E7D32),
                    )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
                        filled: true,
                        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF2E7D32),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isPostingComment,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: _isPostingComment ? null : _postComment,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: _isPostingComment
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                            : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎨 Build individual comment item
  Widget _buildCommentItem(Map<String, dynamic> comment) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment['profile_picture'] != null
                ? NetworkImage(comment['profile_picture'])
                : null,
            backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
            child: comment['profile_picture'] == null
                ? const Icon(
              Icons.person,
              size: 20,
              color: Color(0xFF2E7D32),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment['full_name'] ?? comment['display_name'] ?? comment['author'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                      Text(
                        _formatTimestamp(comment['created_at']),
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    comment['comment_text'] ?? comment['text'] ?? comment['content'] ?? '',
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🕒 Format timestamp
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Just now';

    try {
      DateTime commentTime;
      if (timestamp is String) {
        commentTime = DateTime.parse(timestamp);
      } else if (timestamp is DateTime) {
        commentTime = timestamp;
      } else {
        return 'Just now';
      }

      final now = DateTime.now();
      final difference = now.difference(commentTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${(difference.inDays / 7).floor()}w ago';
      }
    } catch (e) {
      return 'Just now';
    }
  }
}