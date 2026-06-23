import 'dart:convert';

class AppNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isRead: (json['isRead'] as bool?) ?? false,
      );

  static List<AppNotification> listFromJson(String jsonStr) {
    final list = json.decode(jsonStr) as List;
    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<AppNotification> notifications) {
    return json.encode(notifications.map((n) => n.toJson()).toList());
  }
}
