import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_widgets.dart';
import 'controllers/notification_controller.dart';
import 'models/app_notification_model.dart';
import 'models/notification_preferences_model.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late Future<_NotificationViewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_NotificationViewData> _load() async {
    final notificationsFuture = NotificationController.loadMyNotifications();
    final preferencesFuture = NotificationController.loadPreferences();

    return _NotificationViewData(
      notifications: await notificationsFuture,
      preferences: await preferencesFuture,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _createLocalNotification() async {
    try {
      await NotificationController.createLocalNotification(
        title: 'Local OfficeRoute reminder',
        body: 'This in-app notification was generated on this device.',
        type: 'local',
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification creation failed: $error')),
      );
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationController.markAllAsRead();
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification update failed: $error')),
      );
    }
  }

  Future<void> _updatePreferences(
    NotificationPreferencesModel preferences,
  ) async {
    try {
      await NotificationController.updatePreferences(preferences);
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preference update failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Notifications', style: AppTextStyles.headingSmall),
      ),
      body: FutureBuilder<_NotificationViewData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const PremiumLoadingState(label: 'Loading notifications');
          }

          if (snapshot.hasError) {
            return PremiumErrorState(
              title: 'Notifications failed to load.',
              error: snapshot.error,
              onRetry: _refresh,
            );
          }

          final data = snapshot.data ??
              _NotificationViewData(
                notifications: const <AppNotificationModel>[],
                preferences: NotificationPreferencesModel.defaults(),
              );
          final unreadCount =
              data.notifications.where((item) => !item.isRead).length;

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 860;
                final center = _NotificationHistoryCard(
                  notifications: data.notifications,
                  unreadCount: unreadCount,
                  onCreateLocal: _createLocalNotification,
                  onMarkAllRead: _markAllRead,
                  onMarkRead: (notification) async {
                    await NotificationController.markAsRead(notification);
                    await _refresh();
                  },
                );
                final settings = Column(
                  children: [
                    _NotificationSummaryCard(
                      unreadCount: unreadCount,
                      totalCount: data.notifications.length,
                    ),
                    const SizedBox(height: 16),
                    _FcmPlaceholderCard(
                      enabled: data.preferences.fcmPlaceholdersEnabled,
                    ),
                    const SizedBox(height: 16),
                    _PreferencesCard(
                      preferences: data.preferences,
                      onChanged: _updatePreferences,
                    ),
                  ],
                );

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 6, child: center),
                                const SizedBox(width: 16),
                                Expanded(flex: 5, child: settings),
                              ],
                            )
                          : Column(
                              children: [
                                settings,
                                const SizedBox(height: 16),
                                center,
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationSummaryCard extends StatelessWidget {
  final int unreadCount;
  final int totalCount;

  const _NotificationSummaryCard({
    required this.unreadCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const PremiumIconChip(
                icon: Icons.notifications_outlined,
                color: AppColors.info,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -5,
                  top: -5,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unreadCount unread',
                  style: AppTextStyles.headingSmall.copyWith(letterSpacing: 0),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalCount notifications in history',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationHistoryCard extends StatelessWidget {
  final List<AppNotificationModel> notifications;
  final int unreadCount;
  final VoidCallback onCreateLocal;
  final VoidCallback onMarkAllRead;
  final Future<void> Function(AppNotificationModel notification) onMarkRead;

  const _NotificationHistoryCard({
    required this.notifications,
    required this.unreadCount,
    required this.onCreateLocal,
    required this.onMarkAllRead,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(
            icon: Icons.inbox_outlined,
            title: 'Notification Center',
            actionLabel: unreadCount > 0 ? 'Mark all read' : null,
            onAction: unreadCount > 0 ? onMarkAllRead : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCreateLocal,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Create Local In-App Notification'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: Colors.white.withAlpha(54)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            const PremiumEmptyState(
              icon: Icons.notifications_none_outlined,
              title: 'No notifications yet',
              message: 'Local app notifications and Firestore history will appear here.',
            )
          else
            Column(
              children: notifications.map((notification) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _NotificationTile(
                    notification: notification,
                    onMarkRead: () => onMarkRead(notification),
                  ),
                );
              }).toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotificationModel notification;
  final VoidCallback onMarkRead;

  const _NotificationTile({
    required this.notification,
    required this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor =
        notification.isRead ? AppColors.textSecondary : AppColors.info;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(notification.isRead ? 8 : 16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withAlpha(48)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            PremiumIconChip(
              icon: _notificationIcon(notification.type),
              color: statusColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyLarge.copyWith(letterSpacing: 0),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${notification.source} - ${_formatDate(notification.createdAt)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              IconButton(
                onPressed: onMarkRead,
                icon: const Icon(Icons.done),
                tooltip: 'Mark read',
              ),
          ],
        ),
      ),
    );
  }
}

class _FcmPlaceholderCard extends StatelessWidget {
  final bool enabled;

  const _FcmPlaceholderCard({required this.enabled});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.cloud_queue_outlined,
            title: 'Firebase Messaging',
          ),
          const SizedBox(height: 14),
          PremiumStatusChip(
            label: enabled ? 'Placeholder Enabled' : 'Awaiting Setup',
            color: enabled ? AppColors.info : AppColors.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'FCM hooks are represented here until Firebase Cloud Messaging credentials, platform setup, and app notification permissions are configured.',
            style: AppTextStyles.caption.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends StatelessWidget {
  final NotificationPreferencesModel preferences;
  final ValueChanged<NotificationPreferencesModel> onChanged;

  const _PreferencesCard({
    required this.preferences,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PremiumSectionHeader(
            icon: Icons.tune_outlined,
            title: 'Preferences',
          ),
          const SizedBox(height: 10),
          _PreferenceSwitch(
            label: 'Attendance reminders',
            value: preferences.attendanceReminders,
            onChanged: (value) => onChanged(
              preferences.copyWith(attendanceReminders: value),
            ),
          ),
          _PreferenceSwitch(
            label: 'Visit alerts',
            value: preferences.visitAlerts,
            onChanged: (value) => onChanged(preferences.copyWith(visitAlerts: value)),
          ),
          _PreferenceSwitch(
            label: 'Manager alerts',
            value: preferences.managerAlerts,
            onChanged: (value) =>
                onChanged(preferences.copyWith(managerAlerts: value)),
          ),
          _PreferenceSwitch(
            label: 'Local in-app notifications',
            value: preferences.localInAppNotifications,
            onChanged: (value) => onChanged(
              preferences.copyWith(localInAppNotifications: value),
            ),
          ),
          _PreferenceSwitch(
            label: 'FCM placeholders',
            value: preferences.fcmPlaceholdersEnabled,
            onChanged: (value) => onChanged(
              preferences.copyWith(fcmPlaceholdersEnabled: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: AppTextStyles.bodyMedium),
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppColors.textPrimary,
    );
  }
}

class _NotificationViewData {
  final List<AppNotificationModel> notifications;
  final NotificationPreferencesModel preferences;

  const _NotificationViewData({
    required this.notifications,
    required this.preferences,
  });
}

IconData _notificationIcon(String type) {
  switch (type.toLowerCase()) {
    case 'attendance':
      return Icons.fact_check_outlined;
    case 'visit':
      return Icons.business_center_outlined;
    case 'manager':
      return Icons.supervisor_account_outlined;
    case 'local':
      return Icons.add_alert_outlined;
    default:
      return Icons.notifications_outlined;
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}
