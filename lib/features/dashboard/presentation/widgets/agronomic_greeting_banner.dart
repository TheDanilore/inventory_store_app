import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:inventory_store_app/core/localization/app_localizations.dart';

/// Banner Ejecutivo de Bienvenida Agronómica con saludo horario inteligente,
/// avatar dinámico del usuario, fecha en tiempo real y contexto operativo de campo.
class AgronomicGreetingBanner extends StatelessWidget {
  final VoidCallback? onAvatarTap;

  const AgronomicGreetingBanner({
    super.key,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 850;
        final isMobile = constraints.maxWidth < 600;

        final hour = DateTime.now().hour;
        final ({String greeting, IconData icon, String timeLabel}) periodInfo =
            _getTimePeriodInfo(context, hour);

        final now = DateTime.now();
        String formattedDate;
        try {
          final localeCode = Localizations.localeOf(context).languageCode;
          final dateLocale = localeCode == 'qu' ? 'es' : localeCode;
          formattedDate = DateFormat('EEEE, d \'de\' MMMM · yyyy', dateLocale).format(now);
          if (formattedDate.isNotEmpty) {
            formattedDate = formattedDate[0].toUpperCase() + formattedDate.substring(1);
          }
        } catch (_) {
          formattedDate = '${now.day}/${now.month}/${now.year}';
        }

        return BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            final user = authState.currentUser;
            final fullName = user?.fullName.trim();
            final firstName = (fullName != null && fullName.isNotEmpty)
                ? fullName.split(' ').first
                : 'Administrador';
            final role = user?.role.isNotEmpty == true
                ? user!.role.toUpperCase()
                : 'GERENTE AGRÍCOLA';
            final avatarUrl = user?.avatarUrl;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A8A), // Azul corporativo profundo
                    Color(0xFF1E40AF), // Azul intermedio
                    Color(0xFF065F46), // Verde esmeralda agrícola
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // ── Patrones vectoriales agronómicos de fondo (hojas / sol) ──
                  Positioned(
                    right: isDesktop ? 140 : -20,
                    top: -30,
                    child: Opacity(
                      opacity: 0.08,
                      child: Icon(
                        Icons.eco_rounded,
                        size: isDesktop ? 220 : 160,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 40,
                    bottom: -40,
                    child: Opacity(
                      opacity: 0.06,
                      child: Icon(
                        Icons.agriculture_rounded,
                        size: isDesktop ? 180 : 120,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // ── Contenido Principal ──
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 18 : 26,
                      vertical: isMobile ? 18 : 22,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Información y Saludo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Cápsula de fecha y horario en vivo
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          formattedDate,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                            letterSpacing: -0.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isMobile)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 9,
                                        vertical: 4.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: const Color(0xFF34D399).withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            periodInfo.icon,
                                            size: 13,
                                            color: const Color(0xFF6EE7B7),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            periodInfo.timeLabel,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFD1FAE5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Saludo dinámico con nombre del usuario
                              Text(
                                '¡${periodInfo.greeting}, $firstName!',
                                style: TextStyle(
                                  fontSize: isMobile ? 20 : (isDesktop ? 26 : 22),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.6,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 5),

                              // Subtítulo con contexto agronómico
                              Text(
                                context.tr('greeting_agro_desc'),
                                style: TextStyle(
                                  fontSize: isMobile ? 12 : 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.white.withValues(alpha: 0.88),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Right: Avatar agronómico e ilustración ejecutiva
                        _buildAgronomicAvatar(
                          context,
                          avatarUrl: avatarUrl,
                          firstName: firstName,
                          role: role,
                          isDesktop: isDesktop,
                          isMobile: isMobile,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAgronomicAvatar(
    BuildContext context, {
    required String? avatarUrl,
    required String firstName,
    required String role,
    required bool isDesktop,
    required bool isMobile,
  }) {
    final double avatarSize = isMobile ? 54 : (isDesktop ? 78 : 66);

    return InkWell(
      onTap: onAvatarTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Anillo de resplandor exterior
              Container(
                width: avatarSize + 8,
                height: avatarSize + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: 0.6),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),

              // Imagen de avatar o fallback agronómico
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  image: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Center(
                        child: Text(
                          firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A',
                          style: TextStyle(
                            fontSize: avatarSize * 0.44,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      )
                    : null,
              ),

              // Micro-badge agronómico (hoja / brote)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (isDesktop) ...[
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Text(
                role,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFD1FAE5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({String greeting, IconData icon, String timeLabel}) _getTimePeriodInfo(
    BuildContext context,
    int hour,
  ) {
    if (hour >= 5 && hour < 12) {
      return (
        greeting: context.tr('greeting_morning'),
        icon: Icons.wb_sunny_rounded,
        timeLabel: context.tr('greeting_sub_morning'),
      );
    } else if (hour >= 12 && hour < 19) {
      return (
        greeting: context.tr('greeting_afternoon'),
        icon: Icons.wb_twilight_rounded,
        timeLabel: context.tr('greeting_sub_afternoon'),
      );
    } else {
      return (
        greeting: context.tr('greeting_evening'),
        icon: Icons.bedtime_rounded,
        timeLabel: context.tr('greeting_sub_evening'),
      );
    }
  }
}
