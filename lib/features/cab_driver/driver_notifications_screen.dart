import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_widgets.dart';
import '../notifications/models/app_notification_model.dart';
import '../notifications/services/notification_service.dart';
import 'cab_driver_operational_flow.dart';
import 'controllers/cab_driver_controller.dart';

typedef DriverNotificationLoader =
    Future<List<AppNotificationModel>> Function(String userId);
typedef DriverNotificationRead =
    Future<void> Function(AppNotificationModel notification);

class DriverNotificationsScreen extends StatefulWidget {
  final CabDriverOperations data;
  final ValueChanged<DriverOperationalPhase> onOpenWorkflow;
  final DriverNotificationLoader loader;
  final DriverNotificationRead markAsRead;
  final Stream<void> Function(String userId) watch;

  const DriverNotificationsScreen({
    super.key,
    required this.data,
    required this.onOpenWorkflow,
    this.loader = NotificationService.fetchNotificationsForUser,
    this.markAsRead = NotificationService.markAsRead,
    this.watch = NotificationService.watchNotificationsForUser,
  });

  @override
  State<DriverNotificationsScreen> createState() =>
      DriverNotificationsScreenState();
}

class DriverNotificationsScreenState extends State<DriverNotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  StreamSubscription<void>? _subscription;
  List<AppNotificationModel> _notifications = const [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = widget
        .watch(widget.data.driver.uid)
        .listen(
          (_) => _load(silent: true),
          onError: (_) => _setError(
            'Notifications could not refresh. Pull to retry securely.',
          ),
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => _loading = true);
    }
    try {
      final notifications = await widget.loader(widget.data.driver.uid);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _error = null;
          _loading = false;
        });
      }
    } catch (_) {
      _setError('Notifications are temporarily unavailable. Try again.');
    }
  }

  void _setError(String message) {
    if (mounted) {
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _notifications.isEmpty) {
      return const PremiumLoadingState(label: 'Loading Driver notifications');
    }
    if (_error != null && _notifications.isEmpty) {
      return Center(
        child: PremiumErrorState(title: _error!, error: _error, onRetry: _load),
      );
    }
    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Icon(Icons.notifications_none, size: 64),
            SizedBox(height: 16),
            Center(
              child: Text(
                'No Driver notifications',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(height: 8),
            Center(child: Text('Operational updates will appear here.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        key: const PageStorageKey('driver-notifications-list'),
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length + (_error == null ? 1 : 2),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0) return _header();
          if (_error != null && index == 1) {
            return _retryBanner();
          }
          final notificationIndex = index - (_error == null ? 1 : 2);
          return _notificationCard(_notifications[notificationIndex]);
        },
      ),
    );
  }

  Widget _header() {
    final unread = _notifications.where((item) => !item.isRead).length;
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Text('Driver operations and pickup updates'),
            ],
          ),
        ),
        PremiumStatusChip(
          label: '$unread UNREAD',
          color: unread == 0 ? AppColors.success : AppColors.info,
        ),
      ],
    );
  }

  Widget _retryBanner() => Material(
    color: AppColors.warning.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(12),
    child: ListTile(
      leading: const Icon(Icons.sync_problem, color: AppColors.warning),
      title: Text(_error!),
      trailing: TextButton(onPressed: _load, child: const Text('RETRY')),
    ),
  );

  Widget _notificationCard(AppNotificationModel notification) {
    final priority = _priorityFor(notification.type);
    return Material(
      color: notification.isRead
          ? Theme.of(context).colorScheme.surface
          : AppColors.info.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(notification),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: priority.color.withValues(alpha: 0.15),
                child: Icon(priority.icon, color: priority.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          const Icon(
                            Icons.circle,
                            size: 9,
                            color: AppColors.info,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          priority.label,
                          style: TextStyle(
                            color: priority.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _relativeTime(notification.createdAt),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDetail(AppNotificationModel notification) async {
    if (!notification.isRead) {
      try {
        await widget.markAsRead(notification);
        final index = _notifications.indexWhere(
          (item) => item.id == notification.id,
        );
        if (index >= 0 && mounted) {
          setState(() {
            final updated = [..._notifications];
            updated[index] = notification.copyWith(
              isRead: true,
              readAt: DateTime.now(),
            );
            _notifications = updated;
          });
        }
      } catch (_) {
        _setError('Read status will retry when the connection is available.');
      }
    }
    if (!mounted) return;
    final phase = _phaseFor(notification.type);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => DriverNotificationDetailScreen(
          notification: notification,
          phase: phase,
          onOpenWorkflow: phase == null
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onOpenWorkflow(phase);
                },
        ),
      ),
    );
  }

  static DriverOperationalPhase? _phaseFor(String type) {
    switch (type) {
      case 'cab_arriving':
      case 'pickup_request_available':
      case 'eta_changed':
        return DriverOperationalPhase.currentPickup;
      case 'employee_ready':
        return DriverOperationalPhase.employeeReady;
      case 'cab_pickup_skipped':
      case 'employee_unavailable':
        return DriverOperationalPhase.nextPickup;
      case 'claim_conflict':
        return DriverOperationalPhase.queryFailure;
      case 'trip_cancelled':
        return DriverOperationalPhase.assignmentCancelled;
      case 'offline_action_synchronized':
        return DriverOperationalPhase.offlinePendingSync;
      case 'urgent_operations_instruction':
        return DriverOperationalPhase.emergencySupport;
      case 'vehicle_update':
        return DriverOperationalPhase.newDayReset;
      default:
        return null;
    }
  }

  static _NotificationPriority _priorityFor(String type) {
    if (const {
      'urgent_operations_instruction',
      'trip_cancelled',
      'claim_conflict',
    }.contains(type)) {
      return const _NotificationPriority(
        'URGENT',
        AppColors.error,
        Icons.warning_amber,
      );
    }
    if (const {'employee_ready', 'pickup_request_available'}.contains(type)) {
      return const _NotificationPriority(
        'HIGH',
        AppColors.warning,
        Icons.notifications_active,
      );
    }
    return const _NotificationPriority(
      'STANDARD',
      AppColors.info,
      Icons.notifications,
    );
  }

  static String _relativeTime(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }
}

class DriverNotificationDetailScreen extends StatelessWidget {
  final AppNotificationModel notification;
  final DriverOperationalPhase? phase;
  final VoidCallback? onOpenWorkflow;

  const DriverNotificationDetailScreen({
    super.key,
    required this.notification,
    required this.phase,
    required this.onOpenWorkflow,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Detail')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.notifications_active,
            size: 58,
            color: AppColors.info,
          ),
          const SizedBox(height: 18),
          Text(
            notification.title,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(notification.body, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          Text(
            DriverNotificationsScreenState._relativeTime(
              notification.createdAt,
            ),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if (phase != null) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onOpenWorkflow,
              icon: const Icon(Icons.navigation),
              label: const Text('VIEW ACTIVE DRIVER FLOW'),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationPriority {
  final String label;
  final Color color;
  final IconData icon;

  const _NotificationPriority(this.label, this.color, this.icon);
}
