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

  /// ✅ Unique articles count — getHistory() वरूनच
  static Future<Map<String, dynamic>> getUserStats() async {
    try {
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

  /// ✅ Valid URL शोधतो
  static String? _findValidUrl(Map<String, dynamic> a, List<String> keys) {
    for (final key in keys) {
      final val = a[key]?.toString().trim();
      if (val != null &&
          val.isNotEmpty &&
          val != 'null' &&
          val != 'NULL' &&
          val != 'undefined' &&
          (val.startsWith('http://') || val.startsWith('https://'))) {
        return val;
      }
    }
    return null;
  }

  /// ✅ Valid date string शोधतो
  static String? _findValidDate(Map<String, dynamic> a, List<String> keys) {
    for (final key in keys) {
      final val = a[key]?.toString().trim();
      if (val != null &&
          val.isNotEmpty &&
          val != 'null' &&
          val != 'NULL' &&
          val != 'undefined' &&
          val != '0' &&
          val.length >= 8) {
        return val;
      }
    }
    return null;
  }

  /// ✅ Nested article object flatten करतो
  static Map<String, dynamic> _flattenHistoryItem(Map<String, dynamic> raw) {
    final flat = Map<String, dynamic>.from(raw);
    for (final nestedKey in ['article', 'news', 'post']) {
      if (flat.containsKey(nestedKey) && flat[nestedKey] is Map) {
        final nested = Map<String, dynamic>.from(flat[nestedKey] as Map);
        nested.forEach((key, value) {
          if (!flat.containsKey(key) || flat[key] == null) {
            flat[key] = value;
          }
        });
      }
    }
    return flat;
  }

  /// ✅ FIXED: Feed वरून image_url + source_url enrich करतो
  /// कारण: /user/history API मध्ये image_url + source_url येत नाही
  /// Solution: /feed API वरून article ID match करून missing fields fill करतो
  static Future<List<Map<String, dynamic>>> _enrichWithFeedData(
      List<Map<String, dynamic>> historyItems) async {
    try {
      // Feed वरून सगळे articles एकत्र आणतो
      final feedResponse = await ApiService.getUnifiedFeed(limit: 9999);
      if (feedResponse['status'] != 'success') return historyItems;

      final feedItems = feedResponse['items'] as List? ?? [];

      // Feed articles ला ID वरून map बनवतो — O(1) lookup
      final feedMap = <dynamic, Map<String, dynamic>>{};
      for (final item in feedItems) {
        if (item is Map<String, dynamic> && item['type'] == 'article') {
          feedMap[item['id']] = item;
        }
      }

      // History items मध्ये missing image_url + source_url fill करतो
      return historyItems.map((article) {
        final id = article['id'];
        final feedArticle = feedMap[id];
        if (feedArticle == null) return article;

        // ✅ फक्त missing fields feed वरून घेतो
        final enriched = Map<String, dynamic>.from(article);

        if (_findValidUrl(enriched, ['image_url']) == null) {
          final feedImage = _findValidUrl(feedArticle, [
            'image_url', 'image', 'thumbnail_url', 'thumbnail', 'featured_image',
          ]);
          if (feedImage != null) enriched['image_url'] = feedImage;
        }

        if (_findValidUrl(enriched, ['source_url']) == null) {
          final feedSource = _findValidUrl(feedArticle, [
            'source_url', 'url', 'link', 'article_url', 'original_url',
          ]);
          if (feedSource != null) enriched['source_url'] = feedSource;
        }

        return enriched;
      }).toList();
    } catch (e) {
      // Feed enrich fail झाला तरी original history return करतो
      return historyItems;
    }
  }

  /// ✅ FIXED: Get reading history
  /// - Nested object flatten
  /// - Unique articles only
  /// - Feed वरून image_url + source_url enrich
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

      // ✅ Unique articles only
      final seenIds = <dynamic>{};
      final uniqueList = historyList.where((item) {
        final raw = item as Map;
        final id = raw['id'] ??
            raw['article_id'] ??
            (raw['article'] is Map ? (raw['article'] as Map)['id'] : null);
        return seenIds.add(id);
      }).toList();

      // ✅ Map करतो
      final mappedList = uniqueList.map((item) {
        final a = _flattenHistoryItem(Map<String, dynamic>.from(item as Map));

        final content = a['rewritten_summary'] ??
            a['summary'] ??
            a['content'] ??
            a['description'] ??
            a['rewritten_content'] ??
            '';

        final title = a['rewritten_headline'] ?? a['title'] ?? 'News Article';

        final imageUrl = _findValidUrl(a, [
          'image_url', 'image', 'thumbnail_url', 'thumbnail',
          'featured_image', 'photo_url', 'cover_image',
          'article_image', 'news_image', 'img_url',
        ]);

        final sourceUrl = _findValidUrl(a, [
          'source_url', 'url', 'link', 'article_url',
          'original_url', 'web_url', 'canonical_url',
          'source_link', 'article_link', 'news_url',
          'external_url', 'read_url', 'full_url',
        ]);

        final publishedAt = _findValidDate(a, [
          'created_at', 'published_at', 'publish_date',
          'date', 'article_date', 'news_date', 'post_date', 'timestamp',
        ]);

        final readAt = _findValidDate(a, [
          'read_at', 'viewed_at', 'accessed_at', 'history_created_at',
        ]) ?? publishedAt ?? DateTime.now().toIso8601String();

        return {
          'id': a['id'] ?? a['article_id'],
          'title': title,
          'content': content,
          'summary': a['summary'] ?? content,
          'rewritten_summary': a['rewritten_summary'] ?? content,
          'rewritten_headline': a['rewritten_headline'],
          'description': a['description'],
          'image_url': imageUrl,   // history API मधून येतो (नसेल तर null)
          'source_url': sourceUrl, // history API मधून येतो (नसेल तर null)
          'category': a['category_name'] ?? a['category'] ?? 'General',
          'category_id': a['category_id'],
          'author': a['author'] ?? a['author_name'] ?? a['source'],
          'created_at': publishedAt,
          'read_at': readAt,
          'sentiment': a['sentiment'] ?? 'POSITIVE',
          'is_ai_rewritten': a['is_ai_rewritten'] ?? false,
        };
      }).toList();

      // ✅ Feed वरून missing image_url + source_url enrich करतो
      final enriched = await _enrichWithFeedData(mappedList);
      return enriched;
    } catch (e) {
      return [];
    }
  }

  static Future<void> logout() async {
    await PreferencesService.clearToken();
    await PreferencesService.clearUserData();
  }
}