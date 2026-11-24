import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/notifications/notification_panel.dart';

/// Campana del top bar con [BlocSelector] granular y badge estático (0% GPU/CPU en idle).
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocSelector<
      NotificationsCubit,
      NotificationsState,
      ({int unread, bool hasCritical})
    >(
      selector:
          (state) => (
            unread: state.unreadCount,
            hasCritical: state.criticalUnreadCount > 0,
          ),
      builder: (context, data) {
        final unread = data.unread;
        return Tooltip(
          message:
              unread == 0
                  ? 'Notificaciones'
                  : '$unread notificación(es) sin leer',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => NotificationPanel.show(context),
                  hoverColor:
                      isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color:
                            isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      unread == 0
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_outlined,
                      size: 19,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
              if (unread > 0)
                Positioned(
                  top: -4,
                  right: -4,
                  child: _CountBadge(count: unread, critical: data.hasCritical),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool critical;

  const _CountBadge({required this.count, required this.critical});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: critical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}
