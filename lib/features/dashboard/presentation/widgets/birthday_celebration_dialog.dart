import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modal festivo de felicitación de cumpleaños personalizado.
/// Se muestra automáticamente una vez al día cuando es el cumpleaños del usuario.
class BirthdayCelebrationDialog extends StatelessWidget {
  final UserEntity user;

  const BirthdayCelebrationDialog({super.key, required this.user});

  static Future<void> checkAndShow(
    BuildContext context,
    UserEntity? user,
  ) async {
    if (user == null || !user.isBirthdayToday) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final key =
          'birthday_celebrated_${now.year}_${now.month}_${now.day}_${user.id}';
      final alreadyCelebrated = prefs.getBool(key) ?? false;

      if (!alreadyCelebrated && context.mounted) {
        await prefs.setBool(key, true);
        AppFeedbackService.heavyImpact();
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => BirthdayCelebrationDialog(user: user),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firstName = user.fullName.trim().split(' ').first;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1B4B) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  blurRadius: 36,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Fondo decorativo festivo
                Positioned(
                  top: -20,
                  right: -20,
                  child: Opacity(
                    opacity: 0.08,
                    child: const Icon(
                      Icons.celebration_rounded,
                      size: 150,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Corona / Pastel Animado
                      Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEC4899)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFEC4899,
                                  ).withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.cake_rounded,
                              size: 46,
                              color: Colors.white,
                            ),
                          )
                          .animate(
                            onPlay:
                                (controller) =>
                                    controller.repeat(reverse: true),
                          )
                          .scale(
                            begin: const Offset(0.95, 0.95),
                            end: const Offset(1.05, 1.05),
                            duration: 1200.ms,
                            curve: Curves.easeInOut,
                          ),

                      const SizedBox(height: 22),

                      // Badge festivo
                      Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF59E0B),
                                width: 1.2,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 15,
                                  color: Color(0xFFB45309),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  '¡FELIZ CUMPLEAÑOS!',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 14),

                      // Título con nombre
                      Text(
                            '¡Muchas felicidades, $firstName! 🎉',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color:
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 12),

                      // Mensaje cálido y motivador
                      Text(
                        'En este día tan especial, todo el equipo te agradece por tu esfuerzo y dedicación. Deseamos que este nuevo año de vida esté colmado de salud, prosperidad, bendiciones y mucho éxito.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.45,
                          color:
                              isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF475569),
                        ),
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 26),

                      // Botón de agradecimiento festivo
                      SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                AppFeedbackService.mediumImpact();
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shadowColor: const Color(
                                  0xFF2563EB,
                                ).withValues(alpha: 0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.celebration_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                '¡Muchas Gracias! 🎉',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 600.ms)
                          .scale(begin: const Offset(0.9, 0.9)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
