import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/app_notification.dart';

class NotificationsState extends Equatable {
  final List<AppNotification> items;
  final Set<String> readIds;
  final bool loading;
  final String? errorMessage;
  final DateTime? lastUpdatedAt;

  const NotificationsState({
    this.items = const [],
    this.readIds = const {},
    this.loading = false,
    this.errorMessage,
    this.lastUpdatedAt,
  });

  bool get hasCache => lastUpdatedAt != null || items.isNotEmpty;

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
    String? errorMessage,
    bool clearError = false,
    DateTime? lastUpdatedAt,
  }) => NotificationsState(
    items: items ?? this.items,
    readIds: readIds ?? this.readIds,
    loading: loading ?? this.loading,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
  );

  @override
  List<Object?> get props => [
    items,
    readIds,
    loading,
    errorMessage,
    lastUpdatedAt,
  ];
}
