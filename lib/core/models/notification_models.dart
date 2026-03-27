// lib/core/models/notification_models.dart

enum NotificationType {
  newArticle,
  newVideo,
  general,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      type: _parseNotificationType(json['type']),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] ?? {},
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      isRead: json['is_read'] ?? false,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    switch (type) {
      case 'new_article':
        return NotificationType.newArticle;
      case 'new_video':
        return NotificationType.newVideo;
      default:
        return NotificationType.general;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'body': body,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'is_read': isRead,
    };
  }
}

class ArticleNotificationData {
  final int postId;
  final String title;
  final String? category;

  ArticleNotificationData({
    required this.postId,
    required this.title,
    this.category,
  });

  factory ArticleNotificationData.fromJson(Map<String, dynamic> json) {
    return ArticleNotificationData(
      postId: int.parse(json['post_id']?.toString() ?? '0'),
      title: json['title'] ?? '',
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId.toString(),
      'title': title,
      'category': category,
    };
  }
}

class VideoNotificationData {
  final int postId;
  final String title;
  final String? thumbnailUrl;

  VideoNotificationData({
    required this.postId,
    required this.title,
    this.thumbnailUrl,
  });

  factory VideoNotificationData.fromJson(Map<String, dynamic> json) {
    return VideoNotificationData(
      postId: int.parse(json['post_id']?.toString() ?? '0'),
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'post_id': postId.toString(),
      'title': title,
      'thumbnail_url': thumbnailUrl,
    };
  }
}