import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/main_navigation/domain/entities/app_notification.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_cubit.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/bloc/notifications/notifications_state.dart';

/// Campana del top bar. El indicador es REAL: solo aparece cuando hay
/// notificaciones sin leer, muestra el conteo y pulsa únicamente si alguna
/// no leída es crítica.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final unread = state.unreadCount;
        final hasCritical = state.criticalUnreadCount > 0;

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
                  onTap: () => _NotificationPanel.show(context),
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
                  child: _CountBadge(count: unread, pulse: hasCritical),
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
  final bool pulse;
  const _CountBadge({required this.count, required this.pulse});

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      key: ValueKey(count),
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
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
    ).animate().scale(
      begin: const Offset(0.5, 0.5),
      duration: 220.ms,
      curve: Curves.elasticOut,
    );

    if (pulse) {
      badge = badge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.12, 1.12),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }
    return badge;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Panel anclado arriba a la derecha
// ─────────────────────────────────────────────────────────────────────────

class _NotificationPanel extends StatelessWidget {
  const _NotificationPanel();

  static Future<void> show(BuildContext context) {
    // Capturamos el cubit del contexto actual: el diálogo vive en otro árbol.
    final cubit = context.read<NotificationsCubit>();
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notificaciones',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder:
          (_, _, _) => BlocProvider.value(
            value: cubit,
            child: const _NotificationPanel(),
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
              width: 400,
              constraints: const BoxConstraints(maxHeight: 560),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: BlocBuilder<NotificationsCubit, NotificationsState>(
                builder: (context, state) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
                        child: Row(
                          children: [
                            Text(
                              'Notificaciones',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color:
                                    isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                              ),
                            ),
                            const Spacer(),
                            if (state.unreadCount > 0)
                              TextButton(
                                onPressed:
                                    () =>
                                        context
                                            .read<NotificationsCubit>()
                                            .markAllRead(),
                                child: const Text(
                                  'Marcar todo como leído',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Actualizar',
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              onPressed:
                                  () =>
                                      context
                                          .read<NotificationsCubit>()
                                          .refresh(),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: border),
                      if (state.items.isEmpty)
                        const _EmptyState()
                      else
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: state.items.length,
                            separatorBuilder:
                                (_, _) => Divider(height: 1, color: border),
                            itemBuilder: (context, i) {
                              final n = state.items[i];
                              return _NotificationTile(
                                    notification: n,
                                    unread: !state.readIds.contains(n.id),
                                  )
                                  .animate()
                                  .fadeIn(
                                    duration: 180.ms,
                                    delay: (25 * (i > 8 ? 8 : i)).ms,
                                  )
                                  .slideY(begin: 0.08, end: 0);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
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
                        Navigator.of(context).pop(); // cierra el panel
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
