// lib/core/services/fcm_notification_service.dart

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:good_news/core/services/preferences_service.dart';
import 'package:good_news/core/services/api_service.dart';

import 'notification_badge_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('Background message: ${message.messageId}');
  }
}

class FCMNotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  static bool _isInitialized = false;
  static String? _fcmToken;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Permission
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        if (kDebugMode) debugPrint('Notification permission denied');
        return;
      }

      // 2. Local notifications setup
      await _initializeLocalNotifications();

      // 3. FCM Token get
      _fcmToken = await _fcm.getToken();
      if (kDebugMode) debugPrint('FCM Token: $_fcmToken');

      if (_fcmToken != null) {
        await _saveFCMTokenToBackend(_fcmToken!);
      }

      // 4. Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 5. Background tap
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 6. Terminated state tap
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }

      // 7. Token refresh
      _fcm.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
        _saveFCMTokenToBackend(newToken);
      });

      _isInitialized = true;
      if (kDebugMode) debugPrint('FCM initialized successfully');
    } catch (e) {
      if (kDebugMode) debugPrint('FCM initialization failed: $e');
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Good News',
        body: message.notification!.body ?? '',
        data: message.data,
      );

      // हे नवीन line add करा ↓
      NotificationBadgeService().increment();
    }
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'good_news_channel',
        'Good News Notifications',
        channelDescription: 'New articles and videos',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: jsonEncode(data),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to show notification: $e');
    }
  }

  static void _handleNotificationTap(RemoteMessage message) {
    _navigateBasedOnNotification(message.data);
  }

  static void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!);
        _navigateBasedOnNotification(data);
      } catch (e) {
        if (kDebugMode) debugPrint('Failed to parse payload: $e');
      }
    }
  }

  static void _navigateBasedOnNotification(Map<String, dynamic> data) {
    if (navigatorKey.currentContext == null) return;

    final type = data['type'] as String?;

    switch (type) {
      case 'new_article':
        _navigateToArticle(data);
        break;
      case 'new_video':
        _navigateToVideo(data);
        break;
      default:
        if (kDebugMode) debugPrint('Unknown notification type: $type');
    }
  }

  static void _navigateToArticle(Map<String, dynamic> data) {
    final postId = data['post_id'];
    if (postId != null) {
      navigatorKey.currentState?.pushNamed(
        '/article-details',
        arguments: {'postId': postId},
      );
    }
  }

  static void _navigateToVideo(Map<String, dynamic> data) {
    final postId = data['post_id'];
    if (postId != null) {
      navigatorKey.currentState?.pushNamed(
        '/video-details',
        arguments: {'postId': postId},
      );
    }
  }

  static Future<void> _saveFCMTokenToBackend(String token) async {
    try {
      final userToken = await PreferencesService.getToken();
      if (userToken == null) return;

      final response = await ApiService.authenticatedRequest(
        '/user/fcm-token/',
        method: 'POST',
        token: userToken,
        data: {'fcm_token': token},
      );

      if (kDebugMode) debugPrint('FCM token save response: $response');
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving FCM token: $e');
    }
  }

  static String? get fcmToken => _fcmToken;

  static Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      _fcmToken = null;
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to delete FCM token: $e');
    }
  }
}