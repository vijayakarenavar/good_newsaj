import 'package:good_news/core/services/api_service.dart';
import 'package:good_news/core/services/preferences_service.dart';

class UserService {
  /// Get user profile from /user/profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      //'🔍 Fetching user profile...');
      final response = await ApiService.authenticatedRequest(
        '/user/profile',
        method: 'GET',
        token: token,
      );

      //'✅ Profile response: $response');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      //'❌ Error loading user profile: $e');
      throw Exception('Failed to load user profile: $e');
    }
  }

  /// Get user stats from /user/stats
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      //'📊 Fetching user stats from API...');

      try {
        final response = await ApiService.authenticatedRequest(
          '/user/stats',
          method: 'GET',
          token: token,
        );

        //'✅ Stats from API: $response');

        if (response is Map) {
          //'✅ Processing API stats with correct field mapping...');

          // Map API fields to expected keys (removed favorites_count)
          final stats = {
            'articles_read': response['read_articles'] ?? 0,
            'posts': response['posts_count'] ?? 0,
            'likes': response['likes_received'] ?? 0,
            'comments': response['comments_received'] ?? 0,
          };

          //'✅ Final stats: $stats');
          return stats;
        }
      } catch (e) {
        //'⚠️ /user/stats endpoint failed: $e');
      }

      // Full fallback: calculate everything manually
      //'📊 Calculating all stats manually...');
      final history = await getHistory();

      final stats = {
        'articles_read': history.length,
        'posts': 0,
        'likes': 0,
        'comments': 0,
      };

      //'✅ Manual stats: $stats');
      return stats;
    } catch (e) {
      //'❌ Error loading user stats: $e');
      return {
        'articles_read': 0,
        'posts': 0,
        'likes': 0,
        'comments': 0,
      };
    }
  }

  /// Update profile (PUT /user/profile)
  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      //'📝 Updating profile with data: $data');

      final response = await ApiService.authenticatedRequest(
        '/user/profile',
        method: 'PUT',
        token: token,
        data: data,
      );

      //'✅ Update profile response: $response');

      return response['message'] == 'Profile updated successfully' ||
          response['status'] == 'success' ||
          response['success'] == true;
    } catch (e) {
      //'❌ Error updating profile: $e');
      return false;
    }
  }

  static Future<void> refreshUserProfile() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) {
        //'❌ No token found, cannot refresh profile');
        return;
      }

      //'🔄 Refreshing user profile data...');

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
          //'✅ Got profile data:');
          //'   Display Name: $displayName');
          //'   Email: $email');
          //'   User ID: $userId');

          // ✅ Update stored user data with correct display_name
          final currentToken = await PreferencesService.getToken();
          if (currentToken != null) {
            await PreferencesService.saveUserData(
              token: currentToken,
              userId: userId,
              name: displayName, // ✅ Save display_name
              email: email,
            );

            //'💾 Updated display name in preferences: $displayName');

            // ✅ Verify it was saved
            final savedName = await PreferencesService.getUserDisplayName();
            //'✅ Verified: Display name is now "$savedName"');
          }
        }
      }
    } catch (e) {
      //'❌ Failed to refresh user profile: $e');
    }
  }

  // ==================== READING HISTORY ====================

  /// Add article to reading history (POST /user/history)
  static Future<bool> addToHistory(int articleId) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      //'📝 Adding article $articleId to history...');

      final response = await ApiService.authenticatedRequest(
        '/user/history',
        method: 'POST',
        token: token,
        data: {'article_id': articleId},
      );

      //'✅ Add to history response: $response');

      return response['message'] == 'Added to history successfully' ||
          response['status'] == 'success';
    } catch (e) {
      //'❌ Error adding to history: $e');
      return false;
    }
  }

  /// ✅ NEW: Add article to reading history with NEW entry (for "Read Again" functionality)
  /// Returns the new history entry ID if successful
  static Future<int?> addToHistoryWithNewEntry(int articleId) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      //'📝 Adding article $articleId to history with NEW entry...');

      // ✅ CRITICAL: Use POST to /user/history to create NEW entry (not update existing)
      final response = await ApiService.authenticatedRequest(
        '/user/history',
        method: 'POST',
        token: token,
        data: {'article_id': articleId},
      );

      //'✅ New history entry response: $response');

      // Extract new entry ID from response (backend should return it)
      if (response is Map) {
        // Try common response patterns
        final newEntryId = response['history_id'] ??
            response['id'] ??
            response['entry_id'] ??
            response['data']?['id'];

        if (newEntryId != null && newEntryId is int) {
          //'✅ Created new history entry with ID: $newEntryId');
          return newEntryId;
        }
      }

      // Fallback: Assume success if status is good
      if (response['message']?.contains('success') == true ||
          response['status'] == 'success' ||
          response['success'] == true) {
        //'✅ History entry created (ID not returned by backend)');
        return -1; // Success indicator
      }

      return null;
    } catch (e) {
      //'❌ Error adding new history entry: $e');
      return null;
    }
  }

  /// Get reading history (GET /user/history)
  /// ✅ FIXED: Now properly extracts and includes summaries
  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('No auth token');

      //'📖 Fetching reading history...');

      final response = await ApiService.authenticatedRequest(
        '/user/history',
        method: 'GET',
        token: token,
      );

      //'📦 History response type: ${response.runtimeType}');
      //'📦 History response: $response');

      List<dynamic> historyList = [];

      if (response is List) {
        historyList = response as List;
        //'✅ History is List: ${historyList.length} items');
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          historyList = data;
          //'✅ History from data field: ${historyList.length} items');
        }
      } else if (response is Map && response.containsKey('history')) {
        final history = response['history'];
        if (history is List) {
          historyList = history;
          //'✅ History from history field: ${historyList.length} items');
        }
      }

      // ✅ ENHANCED: Process each history item to ensure all fields are present
      final result = historyList.map((item) {
        final article = Map<String, dynamic>.from(item as Map);

        // ✅ Extract summary fields with priority
        final summary = article['rewritten_summary'] ??
            article['summary'] ??
            'Tap to read this article and discover positive news.';

        // ✅ Extract title fields with priority
        final title = article['rewritten_headline'] ??
            article['title'] ??
            'News Article';

        // ✅ Create normalized article object with all necessary fields
        final processedArticle = {
          'id': article['id'] ?? article['article_id'],
          'title': title,
          'summary': summary,
          'rewritten_summary': article['rewritten_summary'],
          'rewritten_headline': article['rewritten_headline'],
          'category': article['category_name'] ?? article['category'] ?? 'General',
          'category_id': article['category_id'],
          'read_at': article['read_at'] ?? article['created_at'] ?? DateTime.now().toIso8601String(),
          'source_url': article['source_url'] ?? '',
          'sentiment': article['sentiment'] ?? 'POSITIVE',
          'image_url': article['image_url'],
        };

        //'📖 History article ${processedArticle['id']}: "${processedArticle['title']}"');
        //'   Summary: ${summary.substring(0, summary.length > 50 ? 50 : summary.length)}...');
        //'   Category: ${processedArticle['category']}');

        return processedArticle;
      }).toList();

      //'✅ Returning ${result.length} processed history items with summaries');

      // Print summary stats
      final withSummary = result.where((a) =>
      a['summary'] != null &&
          a['summary'].toString().isNotEmpty &&
          a['summary'] != 'Tap to read this article and discover positive news.'
      ).length;

      //'📊 Articles with valid summaries: $withSummary/${result.length}');

      return result;
    } catch (e) {
      //'❌ Error fetching history: $e');
      return [];
    }
  }

  /// Logout user
  static Future<void> logout() async {
    await PreferencesService.clearToken();
    await PreferencesService.clearUserData();
  }
}