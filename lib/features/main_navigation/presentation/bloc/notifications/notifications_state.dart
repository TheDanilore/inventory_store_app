import 'package:inventory_store_app/features/main_navigation/domain/entities/app_notification.dart';

class NotificationsState {
  final List<AppNotification> items;
  final Set<String> readIds;
  final bool loading;

  const NotificationsState({
    this.items = const [],
    this.readIds = const {},
    this.loading = false,
  });

  int get unreadCount => items.where((n) => !readIds.contains(n.id)).length;

  int get criticalUnreadCount =>
      items
          .where(
            (n) =>
                n.severity == NotificationSeverity.critical &&
                !readIds.contains(n.id),
          )
          .length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    Set<String>? readIds,
    bool? loading,
  }) => NotificationsState(
    items: items ?? this.items,
    readIds: readIds ?? this.readIds,
    loading: loading ?? this.loading,
  );
}
