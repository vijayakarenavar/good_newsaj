import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:good_news/core/constants/api_constants.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:dio/io.dart';

class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: Duration(milliseconds: ApiConstants.timeout),
      receiveTimeout: Duration(milliseconds: ApiConstants.timeout),
      sendTimeout: Duration(milliseconds: ApiConstants.timeout),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'GoodNewsApp/1.0 (Mobile App)',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
      },
      validateStatus: (status) => status != null && status < 500,
    ),
  )
    ..httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          if (host == "goodnewsapp.lemmecode.com") {
            return true;
          }
          return false;
        };
        return client;
      },
    )
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await PreferencesService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) => handler.next(error),
      ),
    )
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.next(options),
        onResponse: (response, handler) => handler.next(response),
        onError: (error, handler) => handler.next(error),
      ),
    );

  static void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static Future<T> _retryRequest<T>(Future<T> Function() request,
      {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        return await request();
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 1000 * attempts));
      }
    }
    throw Exception('Max retries exceeded');
  }

  static Future<Map<String, dynamic>> getUnifiedFeed({
    String? cursor,
    int limit = 20,
    String? type,
    int? categoryId,
  }) async {
    try {
      final token = await PreferencesService.getToken();
      final queryParams = <String, dynamic>{'limit': limit};
      if (cursor != null) queryParams['cursor'] = cursor;
      if (type != null) queryParams['type'] = type;
      if (categoryId != null) queryParams['category_id'] = categoryId;

      final response = await _dio.get('/feed',
          queryParameters: queryParams,
          options: Options(headers: {
            'Accept': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          }));

      if (response.statusCode == 200 &&
          response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final items = (data['items'] as List?)
            ?.map((item) =>
            _formatFeedItem(item as Map<String, dynamic>))
            .toList() ??
            [];
        return {
          'status': 'success',
          'items': items,
          'next_cursor': data['next_cursor'],
          'has_more': data['has_more'] ?? false,
        };
      }
      return {
        'status': 'error',
        'items': [],
        'next_cursor': null,
        'has_more': false
      };
    } catch (e) {
      _log('getUnifiedFeed error: $e');
      return {
        'status': 'error',
        'error': e.toString(),
        'items': [],
        'next_cursor': null,
        'has_more': false
      };
    }
  }

  static Map<String, dynamic> _formatFeedItem(Map<String, dynamic> item) {
    final String type = item['type'] ?? 'article';
    if (type == 'article') return _formatArticleFromFeed(item);
    if (type == 'post' || type == 'social_post') {
      return _formatSocialPostFromFeed(item);
    }
    if (type == 'video' || type == 'video_post') {
      return _formatVideoPostFromFeed(item);
    }
    return {
      'type': 'article',
      'id': item['id'] ?? 0,
      'title': 'Unknown Item',
      'content': 'Content not available.',
      'created_at': DateTime.now().toIso8601String(),
      'category': 'Misc',
      'category_id': null,
      'image_url': null,
      'source_url': '',
      'is_ai_rewritten': false,
    };
  }

  static Map<String, dynamic> _formatArticleFromFeed(
      Map<String, dynamic> item) {
    String content = item['content'] ??
        item['rewritten_summary'] ??
        item['summary'] ??
        'No content available';
    if (content.trim().isEmpty || content.trim().length < 30) {
      content =
      'Read the latest update about this story. Tap "Read Full Article" to view complete details from the original source.';
    }
    return {
      'type': 'article',
      'id': item['id'],
      'title': item['rewritten_headline'] ?? item['title'] ?? 'Untitled',
      'content': content,
      'sentiment': item['sentiment'] ?? 'POSITIVE',
      'source_url': item['source_url'] ?? '',
      'created_at': item['created_at'],
      'category': item['category'] ?? item['author'] ?? 'News',
      'category_id': item['category_id'],
      'image_url': item['image_url'],
      'is_ai_rewritten': (item['is_ai_rewritten'] == 1 ||
          item['is_ai_rewritten'] == true),
    };
  }

  static Map<String, dynamic> _formatSocialPostFromFeed(
      Map<String, dynamic> item) {
    final authorName = item['author'] ?? item['display_name'] ?? 'Unknown';
    return {
      'type': 'social_post',
      'id': item['id'].toString(),
      'user_id': item['user_id'] ?? item['author_id'] ?? item['created_by'],
      'author': authorName,
      'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U',
      'title': item['title'] ?? '',
      'content': item['content'] ?? '',
      'created_at': item['created_at'],
      'likes': item['likes_count'] ?? item['likes'] ?? 0,
      'comments': item['comments_count'] ?? item['comments'] ?? 0,
      'isLiked':
      item['user_has_liked'] == 1 || item['user_has_liked'] == true,
      'category_id': -1,
      'category': 'Social Posts',
      'image_url': item['image_url'],
    };
  }

  static Map<String, dynamic> _formatVideoPostFromFeed(
      Map<String, dynamic> item) {
    final authorName = item['author'] ?? item['display_name'] ?? 'Unknown';
    return {
      'type': 'video_post',
      'id': item['id'].toString(),
      'author': authorName,
      'avatar': authorName.isNotEmpty ? authorName[0].toUpperCase() : 'V',
      'title': item['title'] ?? '',
      'content': item['content'] ?? '',
      'created_at': item['created_at'],
      'likes': item['likes_count'] ?? item['likes'] ?? 0,
      'isLiked':
      item['user_has_liked'] == 1 || item['user_has_liked'] == true,
      'category_id': -2,
      'category': 'Video',
      'image_url': item['image_url'],
      'video_url': item['video_url'],
    };
  }

  static Future<Map<String, dynamic>> getCategories() async {
    try {
      final response =
      await _retryRequest(() async => await _dio.get('/categories'));
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      if (response.data is List) {
        return {
          'status': 'success',
          'categories': response.data,
          'count': (response.data as List).length
        };
      }
      return {'status': 'success', 'categories': [], 'count': 0};
    } catch (e) {
      _log('getCategories error: $e');
      return {
        'status': 'error',
        'error': 'Failed to load categories',
        'categories': []
      };
    }
  }

  static Future<Map<String, dynamic>> saveUserPreferencesAuth(
      List<int> categoryIds, String token) async {
    try {
      final response = await _retryRequest(() async => await _dio.post(
          '/user/preferences',
          data: {'category_ids': categoryIds},
          options:
          Options(headers: {'Authorization': 'Bearer $token'})));
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'status': 'success'};
    } catch (e) {
      _log('saveUserPreferencesAuth error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> saveUserPreferences(
      List<int> categoryIds) async {
    try {
      final response = await _retryRequest(() async => await _dio
          .post('/user/preferences', data: {'categories': categoryIds}));
      return response.data ?? {'status': 'success'};
    } catch (e) {
      _log('saveUserPreferences error: $e');
      return {'status': 'error', 'error': 'Failed to save preferences: $e'};
    }
  }

  static Future<Map<String, dynamic>> searchFriends(String query) async {
    try {
      final token = await PreferencesService.getToken();
      final response = await _dio.get('/users/search',
          queryParameters: {'q': query},
          options: Options(headers: {
            if (token != null) 'Authorization': 'Bearer $token'
          }));
      if (response.statusCode == 200 && response.data is List) {
        return {'status': 'success', 'data': response.data};
      }
      return {
        'status': 'error',
        'error': 'Invalid response format',
        'data': []
      };
    } catch (e) {
      _log('searchFriends error: $e');
      return {'status': 'error', 'error': e.toString(), 'data': []};
    }
  }

  static Future<Map<String, dynamic>> postContactsSuggest(
      List<String> hashedContacts) async {
    try {
      final response = await _retryRequest(() async => await _dio.post(
          '/contacts/suggest',
          data: {'hashed_contacts': hashedContacts}));
      return response.data ?? {'status': 'error'};
    } catch (e) {
      _log('postContactsSuggest error: $e');
      return {
        'status': 'error',
        'error': 'Failed to get contact suggestions: $e',
        'suggestions': []
      };
    }
  }

  static Future<Map<String, dynamic>> sendFriendRequest(int userId) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final response = await _dio.post('/friends/$userId/request',
          data: {'user_id': userId},
          options: Options(headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }));
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'status': 'success',
          'message': 'Friend request sent successfully'
        };
      }
      return {'status': 'error', 'error': 'Failed to send friend request'};
    } catch (e) {
      _log('sendFriendRequest error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> cancelFriendRequest(
      int userId) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('Not authenticated');
      final response = await _dio.delete('/friends/$userId/request',
          options: Options(headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'status': 'success',
          'message': 'Friend request cancelled'
        };
      }
      if (response.statusCode == 404 || response.statusCode == 405) {
        final fallback = await _dio.post('/friends/$userId/cancel',
            options: Options(headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            }));
        if (fallback.statusCode == 200 || fallback.statusCode == 204) {
          return {
            'status': 'success',
            'message': 'Friend request cancelled'
          };
        }
      }
      return {
        'status': 'error',
        'error': 'Failed to cancel friend request'
      };
    } catch (e) {
      _log('cancelFriendRequest error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addFriend(String userId) async {
    try {
      final response = await _retryRequest(() async =>
      await _dio.post('/friends/add', data: {'user_id': userId}));
      return response.data ?? {'status': 'success'};
    } catch (e) {
      _log('addFriend error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  // ✅ FIXED: DioException rethrow for proper error messages
  static Future<Map<String, dynamic>> login(
      String email, String password) async {
    try {
      final response = await _retryRequest(() async => await _dio.post(
          '/login',
          data: {
            'email': email.trim(),
            'password': password.trim()
          }));
      final data = response.data;
      if (data != null &&
          data['token'] != null &&
          data['user_id'] != null) {
        await PreferencesService.saveUserData(
            token: data['token'],
            userId: data['user_id'],
            name: data['display_name'] ?? data['name'] ?? '',
            email: email);
        await PreferencesService.setOnboardingCompleted(true);
      }
      return data ?? {'status': 'error'};
    } on DioException catch (e) {
      _log('login error: $e');
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw SocketException('Failed host lookup');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('TimeoutException');
      }
      return {'status': 'error', 'error': e.message ?? 'Login failed'};
    } catch (e) {
      _log('login error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  // ✅ FIXED: DioException rethrow for proper error messages
  static Future<Map<String, dynamic>> register(String displayName,
      String email, String password, String phoneNumber) async {
    try {
      final response =
      await _retryRequest(() async => await _dio.post('/register',
          data: {
            'email': email.trim(),
            'password': password.trim(),
            'display_name': displayName.trim(),
            'phone_number': phoneNumber.trim(),
          }));
      return response.data ?? {'status': 'error'};
    } on DioException catch (e) {
      _log('register error: $e');
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw SocketException('Failed host lookup');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('TimeoutException');
      }
      return {'status': 'error', 'error': e.message ?? 'Registration failed'};
    } catch (e) {
      _log('register error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> authenticatedRequest(
      String endpoint,
      {required String method,
        required String token,
        Map<String, dynamic>? data,
        Map<String, dynamic>? queryParameters}) async {
    try {
      final options = Options(
          method: method.toUpperCase(),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          });
      Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _dio.get(endpoint,
              queryParameters: queryParameters, options: options);
          break;
        case 'POST':
          response = await _dio.post(endpoint,
              data: data,
              queryParameters: queryParameters,
              options: options);
          break;
        case 'PUT':
          response = await _dio.put(endpoint,
              data: data,
              queryParameters: queryParameters,
              options: options);
          break;
        case 'DELETE':
          response = await _dio.delete(endpoint,
              queryParameters: queryParameters, options: options);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map<String, dynamic>) {
          final responseData = response.data as Map<String, dynamic>;
          if (!responseData.containsKey('status')) {
            responseData['status'] = 'success';
          }
          return responseData;
        }
        return {'status': 'success', 'data': response.data};
      }
      if (response.statusCode == 401) {
        return {
          'status': 'error',
          'error': 'Authentication failed',
          'statusCode': 401
        };
      }
      return {
        'status': 'error',
        'error': 'Server error: ${response.statusCode}',
        'statusCode': response.statusCode
      };
    } catch (e) {
      if (e is DioException &&
          e.type == DioExceptionType.connectionTimeout) {
        return {'status': 'error', 'error': 'Connection timeout'};
      }
      _log('authenticatedRequest error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> saveFCMToken(
      String fcmToken) async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) throw Exception('Not authenticated');
      return await authenticatedRequest('/user/fcm-token',
          method: 'POST',
          token: token,
          data: {
            'fcm_token': fcmToken,
            'platform': Platform.isAndroid ? 'android' : 'ios'
          });
    } catch (e) {
      _log('saveFCMToken error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getVideoFeed({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final token = await PreferencesService.getToken();
      final response = await _dio.get('/videos/feed',
          queryParameters: {'limit': limit, 'offset': offset},
          options: Options(headers: {
            if (token != null) 'Authorization': 'Bearer $token'
          }));

      if (response.statusCode == 200 &&
          response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        final rawVideos = data['videos'] as List? ?? [];
        final total = data['total'] as int? ?? 0;

        final serverSaysHasMore =
            data['has_more'] == true || data['hasMore'] == true;
        final totalSaysMore =
            total > 0 && (offset + rawVideos.length) < total;
        final hasMore = serverSaysHasMore || totalSaysMore;

        return {
          'status': 'success',
          'videos': rawVideos,
          'has_more': hasMore,
          'total': total
        };
      }
      return {'status': 'error', 'videos': [], 'has_more': false};
    } catch (e) {
      _log('getVideoFeed error: $e');
      return {'status': 'error', 'videos': [], 'has_more': false};
    }
  }

  static Future<void> trackVideoWatch(
      int videoId, int watchDuration, bool completed) async {
    try {
      final token = await PreferencesService.getToken();
      await _dio.post('/videos/$videoId/watch',
          data: {
            'watch_duration': watchDuration,
            'completed': completed
          },
          options: Options(headers: {
            if (token != null) 'Authorization': 'Bearer $token'
          }));
    } catch (e) {
      _log('trackVideoWatch error: $e');
    }
  }

  static Future<void> saveVideo(int videoId) async {
    try {
      final token = await PreferencesService.getToken();
      await _dio.post('/videos/$videoId/save',
          options: Options(headers: {
            if (token != null) 'Authorization': 'Bearer $token'
          }));
    } catch (e) {
      _log('saveVideo error: $e');
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final token = await PreferencesService.getToken();
      if (token == null) {
        return {'status': 'error', 'error': 'Not authenticated'};
      }
      final response = await _dio.delete('/user/account',
          options: Options(headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json'
          }));
      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'status': 'success',
          'message': 'Account deleted successfully'
        };
      }
      if (response.statusCode == 401) {
        return {'status': 'error', 'error': 'Authentication failed'};
      }
      return {
        'status': 'error',
        'error': 'Failed to delete account. Please try again.'
      };
    } catch (e) {
      if (e is DioException &&
          e.type == DioExceptionType.connectionTimeout) {
        return {
          'status': 'error',
          'error': 'Connection timeout. Please check your internet.'
        };
      }
      _log('deleteAccount error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }

  // ✅ FIXED: DioException rethrow for proper error messages
  static Future<Map<String, dynamic>> googleMobileLogin(
      String idToken) async {
    try {
      final response = await _retryRequest(() async => await _dio
          .post('/auth/google/mobile', data: {'id_token': idToken}));
      final data = response.data;
      if (data != null && data['token'] != null) {
        await PreferencesService.saveUserData(
          token: data['token'],
          userId: data['user_id'] ?? 0,
          name: data['user']?['display_name'] ?? 'User',
          email: data['user']?['email'] ?? '',
        );
        await PreferencesService.setOnboardingCompleted(true);
      }
      return data ?? {'status': 'error'};
    } on DioException catch (e) {
      _log('googleMobileLogin error: $e');
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        throw SocketException('Failed host lookup');
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw Exception('TimeoutException');
      }
      return {'status': 'error', 'error': e.message ?? 'Google login failed'};
    } catch (e) {
      _log('googleMobileLogin error: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }
}