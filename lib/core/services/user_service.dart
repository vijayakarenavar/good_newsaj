import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/preferences_service.dart';

class UserService {
  /// Get user profile from /user/profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');
      final response = await ApiService.authenticatedRequest(
        '/user/profile',
        method: 'GET',
        token: token,
      );
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to load user profile: $e');
    }
  }

  /// Get user stats from /user/stats
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      try {
        final response = await ApiService.authenticatedRequest(
          '/user/stats',
          method: 'GET',
          token: token,
        );
        if (response is Map) {
          return {
            'articles_read': response['read_articles'] ?? 0,
            'posts': response['posts_count'] ?? 0,
            'likes': response['likes_received'] ?? 0,
            'comments': response['comments_received'] ?? 0,
          };
        }
      } catch (e) {}

      final history = await getHistory();
      return {
        'articles_read': history.length,
        'posts': 0,
        'likes': 0,
        'comments': 0,
      };
    } catch (e) {
      return {'articles_read': 0, 'posts': 0, 'likes': 0, 'comments': 0};
    }
  }

  /// Update profile (PUT /user/profile)
  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');
      final response = await ApiService.authenticatedRequest(
        '/user/profile',
        method: 'PUT',
        token: token,
        data: data,
      );
      return response['message'] == 'Profile updated successfully' ||
          response['status'] == 'success' ||
          response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> refreshUserProfile() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) return;

      final response = await ApiService.authenticatedRequest(
        '/user/profile',
        method: 'GET',
        token: token,
      );

      if (response['status'] == 'success') {
        final displayName = response['display_name'];
        final email = response['email'];
        final userId = response['id'];

        if (displayName != null && email != null && userId != null) {
          final currentToken = await PreferencesService.getToken();
          if (currentToken != null) {
            await PreferencesService.saveUserData(
              token: currentToken,
              userId: userId,
              name: displayName,
              email: email,
            );
          }
        }
      }
    } catch (e) {}
  }

  // ==================== READING HISTORY ====================

  /// Add article to reading history (POST /user/history)
  static Future<bool> addToHistory(int articleId) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');
      final response = await ApiService.authenticatedRequest(
        '/user/history',
        method: 'POST',
        token: token,
        data: {'article_id': articleId},
      );
      return response['message'] == 'Added to history successfully' ||
          response['status'] == 'success';
    } catch (e) {
      return false;
    }
  }

  /// Add article to reading history with NEW entry (for "Read Again")
  static Future<int?> addToHistoryWithNewEntry(int articleId) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      final response = await ApiService.authenticatedRequest(
        '/user/history',
        method: 'POST',
        token: token,
        data: {'article_id': articleId},
      );

      if (response is Map) {
        final newEntryId = response['history_id'] ??
            response['id'] ??
            response['entry_id'] ??
            response['data']?['id'];
        if (newEntryId != null && newEntryId is int) return newEntryId;
      }

      if (response['message']?.contains('success') == true ||
          response['status'] == 'success' ||
          response['success'] == true) {
        return -1;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get reading history (GET /user/history)
  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      final response = await ApiService.authenticatedRequest(
        '/user/history',
        method: 'GET',
        token: token,
      );

      List<dynamic> historyList = [];

      if (response is List) {
        historyList = response as List;
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) historyList = data;
      } else if (response is Map && response.containsKey('history')) {
        final history = response['history'];
        if (history is List) historyList = history;
      }

      // ✅ FIXED: सगळे fields properly map होतात
      return historyList.map((item) {
        final a = Map<String, dynamic>.from(item as Map);

        // --- Content fallback chain ---
        final content = a['rewritten_summary'] ??
            a['summary'] ??
            a['content'] ??
            a['description'] ??
            a['rewritten_content'] ??
            '';

        // --- Title fallback ---
        final title = a['rewritten_headline'] ?? a['title'] ?? 'News Article';

        // --- Image URL: valid असेल तरच घेतो ---
        String? imageUrl;
        for (final key in [
          'image_url', 'image', 'thumbnail_url', 'thumbnail',
          'featured_image', 'photo_url', 'cover_image'
        ]) {
          final val = a[key]?.toString().trim();
          if (val != null &&
              val.isNotEmpty &&
              val != 'null' &&
              val != 'NULL' &&
              val != 'undefined' &&
              (val.startsWith('http://') || val.startsWith('https://'))) {
            imageUrl = val;
            break;
          }
        }

        // --- Source URL: valid असेल तरच घेतो ---
        String? sourceUrl;
        for (final key in [
          'source_url', 'url', 'link', 'article_url',
          'original_url', 'web_url', 'canonical_url'
        ]) {
          final val = a[key]?.toString().trim();
          if (val != null &&
              val.isNotEmpty &&
              val != 'null' &&
              val != 'NULL' &&
              val != 'undefined' &&
              (val.startsWith('http://') || val.startsWith('https://'))) {
            sourceUrl = val;
            break;
          }
        }

        return {
          // Core
          'id': a['id'] ?? a['article_id'],
          'title': title,

          // Content — ArticleDetailScreen ला सगळे keys लागतात
          'content': content,
          'summary': a['summary'] ?? content,
          'rewritten_summary': a['rewritten_summary'] ?? content,
          'rewritten_headline': a['rewritten_headline'],
          'description': a['description'],

          // Image & Source — validated URLs only
          'image_url': imageUrl,
          'source_url': sourceUrl,

          // Meta
          'category': a['category_name'] ?? a['category'] ?? 'General',
          'category_id': a['category_id'],
          'author': a['author'] ?? a['author_name'] ?? a['source'],
          'created_at': a['created_at'] ?? a['published_at'],
          'read_at': a['read_at'] ??
              a['created_at'] ??
              DateTime.now().toIso8601String(),
          'sentiment': a['sentiment'] ?? 'POSITIVE',
          'is_ai_rewritten': a['is_ai_rewritten'] ?? false,
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Logout user
  static Future<void> logout() async {
    await PreferencesService.clearToken();
    await PreferencesService.clearUserData();
  }
}