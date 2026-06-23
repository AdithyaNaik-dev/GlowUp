import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _storageKey = 'app_notifications';
  static const _streakBreakKey = 'last_streak_break_notified';
  static const _maxNotifications = 50;

  SharedPreferences? _prefs;
  List<AppNotification> _notifications = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
  }

  void _load() {
    final raw = _prefs?.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _notifications = AppNotification.listFromJson(raw);
        _notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (_) {
        _notifications = [];
      }
    }
  }

  Future<void> _save() async {
    await _prefs?.setString(
        _storageKey, AppNotification.listToJson(_notifications));
  }

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasUnread => _notifications.any((n) => !n.isRead);

  Future<void> add({
    required String title,
    required String message,
    required String type,
  }) async {
    _notifications.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        message: message,
        type: type,
        timestamp: DateTime.now(),
      ),
    );
    if (_notifications.length > _maxNotifications) {
      _notifications = _notifications.sublist(0, _maxNotifications);
    }
    await _save();
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx].isRead = true;
      await _save();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    bool changed = false;
    for (final n in _notifications) {
      if (!n.isRead) {
        n.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      await _save();
      notifyListeners();
    }
  }

  Future<void> checkStreakBroken({
    required int previousStreak,
    required String lastWorkoutDate,
  }) async {
    if (previousStreak <= 0 || lastWorkoutDate.isEmpty) return;

    try {
      final lastDate = DateTime.parse(lastWorkoutDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastDay =
          DateTime(lastDate.year, lastDate.month, lastDate.day);
      final diff = today.difference(lastDay).inDays;

      if (diff > 1) {
        final lastNotified = _prefs?.getString(_streakBreakKey) ?? '';
        final todayStr = today.toIso8601String().substring(0, 10);

        if (lastNotified != todayStr) {
          await add(
            title: 'Streak Lost',
            message:
                'Your $previousStreak-day streak was broken. Start a new one today!',
            type: 'streak_broken',
          );
          await _prefs?.setString(_streakBreakKey, todayStr);
        }
      }
    } catch (_) {}
  }

  Future<void> onWorkoutComplete({
    required int day,
    required int streak,
  }) async {
    await add(
      title: 'Workout Complete',
      message: 'Day $day done! Keep up the great work.',
      type: 'workout_complete',
    );

    const milestones = {
      3: '3-Day Streak! You\'re building momentum.',
      7: '7-Day Streak! One full week, you\'re earning 2x points now.',
      14: '14-Day Streak! Two weeks strong.',
      21: '21-Day Streak! They say it takes 21 days to form a habit.',
      30: '30-Day Streak! Perfect streak across the entire challenge.',
    };

    if (milestones.containsKey(streak)) {
      await add(
        title: '$streak-Day Streak',
        message: milestones[streak]!,
        type: 'streak_milestone',
      );
    }

    if (day == 10) {
      await add(
        title: 'Foundation Phase Complete',
        message:
            'You\'ve mastered the basics. Build phase starts now!',
        type: 'phase_complete',
      );
    } else if (day == 20) {
      await add(
        title: 'Build Phase Complete',
        message: 'Getting stronger! The Peak phase awaits.',
        type: 'phase_complete',
      );
    } else if (day == 30) {
      await add(
        title: '30-Day Challenge Complete',
        message:
            'You did it! 30 days of transformation. Your glow up is real.',
        type: 'challenge_complete',
      );
    }
  }

  Future<void> clearAll() async {
    _notifications.clear();
    await _prefs?.remove(_storageKey);
    notifyListeners();
  }

  Future<void> addSampleNotifications() async {
    await add(
      title: 'Streak Lost',
      message: 'Your 5-day streak was broken. Start a new one today!',
      type: 'streak_broken',
    );
    await add(
      title: 'Workout Complete',
      message: 'Day 12 done! Keep up the great work.',
      type: 'workout_complete',
    );
    await add(
      title: '7-Day Streak',
      message: "One full week! You're earning 2x points now.",
      type: 'streak_milestone',
    );
    await add(
      title: 'Foundation Phase Complete',
      message: "You've mastered the basics. Build phase starts now!",
      type: 'phase_complete',
    );
    await add(
      title: '30-Day Challenge Complete',
      message: 'You did it! 30 days of transformation. Your glow up is real.',
      type: 'challenge_complete',
    );
    // Add a couple read ones for variety
    if (_notifications.length >= 2) {
      _notifications[_notifications.length - 1].isRead = true;
      _notifications[_notifications.length - 2].isRead = true;
      await _save();
      notifyListeners();
    }
  }
}
