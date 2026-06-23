import 'package:flutter/material.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:lottie/lottie.dart';
import '../config/theme.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_onUpdate);
  }

  @override
  void dispose() {
    _service.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _service.notifications;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (notifications.isNotEmpty && _service.hasUnread)
            IconButton(
              icon: const Icon(Icons.done_all_rounded),
              tooltip: 'Mark all as read',
              onPressed: () async {
                await _service.markAllAsRead();
              },
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: AppColors.primary,
        onPressed: () async {
          await _service.addSampleNotifications();
        },
        child: const Icon(Icons.bug_report_rounded, color: Colors.white),
      ),
      body: notifications.isEmpty
          ? _buildEmptyState()
          : _buildNotificationList(notifications),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 500,
              height: 500,
              child: DotLottieLoader.fromAsset(
                'assets/animation/Empty Notifications.lottie',
                frameBuilder: (ctx, dotlottie) {
                  if (dotlottie != null) {
                    return Lottie.memory(
                      dotlottie.animations.values.single,
                      fit: BoxFit.contain,
                      repeat: true,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No notifications yet',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete workouts and build streaks\nto see updates here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(List<AppNotification> notifications) {
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final n = notifications[index];
        return _buildNotificationTile(n);
      },
    );
  }

  Widget _buildNotificationTile(AppNotification n) {
    final iconData = _iconForType(n.type);
    final iconColor = _colorForType(n.type);

    return GestureDetector(
      onTap: () {
        if (!n.isRead) {
          _service.markAsRead(n.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: n.isRead
              ? context.appCardColor
              : AppColors.primary.withAlpha(8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: n.isRead ? context.appDivider : AppColors.primary.withAlpha(30),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(iconData, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 15,
                      fontWeight:
                          n.isRead ? FontWeight.w600 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.message,
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(n.timestamp),
                    style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!n.isRead)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'streak_broken':
        return Icons.trending_down_rounded;
      case 'workout_complete':
        return Icons.check_circle_rounded;
      case 'streak_milestone':
        return Icons.local_fire_department_rounded;
      case 'phase_complete':
        return Icons.flag_rounded;
      case 'challenge_complete':
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'streak_broken':
        return const Color(0xFFE53935);
      case 'workout_complete':
        return const Color(0xFF4CAF50);
      case 'streak_milestone':
        return const Color(0xFFFF9800);
      case 'phase_complete':
        return const Color(0xFF2196F3);
      case 'challenge_complete':
        return const Color(0xFFFFC107);
      default:
        return AppColors.primary;
    }
  }

  String _timeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
