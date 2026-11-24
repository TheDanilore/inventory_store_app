import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/app_notification.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_state.dart';

/// Panel desplegable de notificaciones optimizado con [BlocSelector] granulares,
/// cero animaciones por tile y renderizado Zero-Shimmer desde caché L1/L2.
class NotificationPanel extends StatelessWidget {
  const NotificationPanel({super.key});

  static Future<void> show(BuildContext context) {
    final cubit = context.read<NotificationsCubit>();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notificaciones',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder:
          (_, _, _) => BlocProvider.value(
            value: cubit,
            child: const NotificationPanel(),
          ),
      transitionBuilder: (_, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SafeArea(
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 68, right: 16),
          child: Material(
            color: bg,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: (MediaQuery.sizeOf(context).width - 32).clamp(
                280.0,
                400.0,
              ),
              constraints: const BoxConstraints(maxHeight: 560),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanelHeader(isDark: isDark),
                  Divider(height: 1, color: border),
                  const _PanelErrorBanner(),
                  Flexible(child: _PanelBody(borderColor: border)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final bool isDark;

  const _PanelHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Notificaciones',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          BlocSelector<NotificationsCubit, NotificationsState, int>(
            selector: (s) => s.unreadCount,
            builder: (context, unread) {
              if (unread == 0) return const SizedBox.shrink();
              return Flexible(
                child: TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed:
                      () => context.read<NotificationsCubit>().markAllRead(),
                  child: const Text(
                    'Marcar todo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              );
            },
          ),
          BlocSelector<NotificationsCubit, NotificationsState, bool>(
            selector: (s) => s.loading,
            builder: (context, loading) {
              return IconButton(
                tooltip: 'Actualizar',
                icon:
                    loading
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.refresh_rounded, size: 18),
                onPressed:
                    loading
                        ? null
                        : () => context.read<NotificationsCubit>().refresh(
                          force: true,
                        ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PanelErrorBanner extends StatelessWidget {
  const _PanelErrorBanner();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<NotificationsCubit, NotificationsState, String?>(
      selector: (s) => s.errorMessage,
      builder: (context, errorMessage) {
        if (errorMessage == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: const Color(0xFFFEF3C7),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: Color(0xFFB45309),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                onPressed:
                    () =>
                        context.read<NotificationsCubit>().refresh(force: true),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PanelBody extends StatelessWidget {
  final Color borderColor;

  const _PanelBody({required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      NotificationsCubit,
      NotificationsState,
      ({
        List<AppNotification> items,
        Set<String> readIds,
        bool loading,
        bool hasError,
      })
    >(
      selector:
          (s) => (
            items: s.items,
            readIds: s.readIds,
            loading: s.loading,
            hasError: s.errorMessage != null,
          ),
      builder: (context, data) {
        if (data.items.isEmpty) {
          if (data.loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            );
          }
          if (data.hasError) {
            return const _UnavailableState();
          }
          return const _EmptyState();
        }

        return ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: data.items.length,
          separatorBuilder: (_, _) => Divider(height: 1, color: borderColor),
          itemBuilder: (context, i) {
            final n = data.items[i];
            return _NotificationTile(
              notification: n,
              unread: !data.readIds.contains(n.id),
            );
          },
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 40,
            color: Color(0xFF22C55E),
          ),
          SizedBox(height: 10),
          Text(
            'Todo en orden',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'No hay lotes por vencer ni stock bajo.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _UnavailableState extends StatelessWidget {
  const _UnavailableState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 38, color: Color(0xFFF59E0B)),
          SizedBox(height: 10),
          Text(
            'Sin conexión con el servidor',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text(
            'No se pudieron cargar las alertas de inventario.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool unread;

  const _NotificationTile({required this.notification, required this.unread});

  Color get _color => switch (notification.severity) {
    NotificationSeverity.critical => const Color(0xFFEF4444),
    NotificationSeverity.warning => const Color(0xFFF59E0B),
    NotificationSeverity.info => const Color(0xFF3B82F6),
  };

  IconData get _icon => switch (notification.kind) {
    NotificationKind.outOfStock => Icons.remove_shopping_cart_outlined,
    NotificationKind.lowStock => Icons.inventory_2_outlined,
    NotificationKind.lotExpiringSoon => Icons.schedule_rounded,
    NotificationKind.lotExpired => Icons.event_busy_rounded,
    NotificationKind.discontinueSuggestion => Icons.block_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cubit = context.read<NotificationsCubit>();

    return InkWell(
      onTap: () => cubit.markRead(notification.id),
      child: Container(
        color: unread ? _color.withValues(alpha: isDark ? 0.08 : 0.04) : null,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, size: 18, color: _color),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                unread ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6, right: 4),
                          decoration: BoxDecoration(
                            color: _color,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  if (notification.action != null) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _color,
                        side: BorderSide(color: _color.withValues(alpha: 0.5)),
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () {
                        cubit.markRead(notification.id);
                        Navigator.of(context).pop();
                        context.go(notification.routePath);
                      },
                      child: Text(notification.action!.label),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Descartar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded, size: 16),
              onPressed: () => cubit.dismiss(notification.id),
            ),
          ],
        ),
      ),
    );
  }
}
