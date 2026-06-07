import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class PointsGameActionsSection extends StatelessWidget {
  final int playsToday;
  final int dailyLimit;
  final bool canPlay;
  final Future<void> Function() onPlayMemorama;
  final int catcherPlaysToday;
  final int catcherDailyLimit;
  final bool canPlayCatcher;
  final Future<void> Function() onPlayCoinCatcher;
  final int pinataPlaysToday;
  final int pinataDailyLimit;
  final bool canPlayPinata;
  final Future<void> Function() onPlayPinata;
  final int clawPlaysToday;
  final int clawDailyLimit;
  final bool canPlayClaw;
  final Future<void> Function() onPlayClaw;
  final int stackPlaysToday;
  final int stackDailyLimit;
  final bool canPlayStack;
  final Future<void> Function() onPlayStack;
  final int dodgePlaysToday;
  final int dodgeDailyLimit;
  final bool canPlayDodge;
  final Future<void> Function() onPlayDodge;
  final int superSaltoPlaysToday;
  final int superSaltoDailyLimit;
  final bool canPlaySuperSalto;
  final Future<void> Function() onPlaySuperSalto;

  const PointsGameActionsSection({
    super.key,
    required this.playsToday,
    required this.dailyLimit,
    required this.canPlay,
    required this.onPlayMemorama,
    required this.catcherPlaysToday,
    required this.catcherDailyLimit,
    required this.canPlayCatcher,
    required this.onPlayCoinCatcher,
    required this.pinataPlaysToday,
    required this.pinataDailyLimit,
    required this.canPlayPinata,
    required this.onPlayPinata,
    required this.clawPlaysToday,
    required this.clawDailyLimit,
    required this.canPlayClaw,
    required this.onPlayClaw,
    required this.stackPlaysToday,
    required this.stackDailyLimit,
    required this.canPlayStack,
    required this.onPlayStack,
    required this.dodgePlaysToday,
    required this.dodgeDailyLimit,
    required this.canPlayDodge,
    required this.onPlayDodge,
    required this.superSaltoPlaysToday,
    required this.superSaltoDailyLimit,
    required this.canPlaySuperSalto,
    required this.onPlaySuperSalto,
  });

  Widget _buildGameTile({
    required String title,
    required int plays,
    required int limit,
    required IconData icon,
    required Color color,
    required VoidCallback? onPlay,
  }) {
    final canPlay = plays < limit;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: canPlay ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: canPlay ? color.withValues(alpha: 0.25) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Icono del juego
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  canPlay
                      ? color.withValues(alpha: 0.12)
                      : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: canPlay ? color : Colors.grey.shade400,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Información y contador
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color:
                        canPlay
                            ? const Color(0xFF1A1A1A)
                            : Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Intentos: $plays / $limit',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        canPlay ? Colors.grey.shade600 : Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Botón integrado
          ElevatedButton(
            onPressed: onPlay,
            style: ElevatedButton.styleFrom(
              backgroundColor: canPlay ? color : Colors.grey.shade200,
              foregroundColor: canPlay ? Colors.white : Colors.grey.shade400,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(0, 36),
            ),
            child: Text(
              canPlay ? 'Jugar' : 'Listo',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la sección
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Juegos Diarios',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Diviértete y gana monedas extra',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Listado de juegos
          _buildGameTile(
            title: 'Memorama',
            plays: playsToday,
            limit: dailyLimit,
            icon: Icons.grid_view_rounded,
            color: const Color(0xFF0F9D8F),
            onPlay: canPlay ? onPlayMemorama : null,
          ),
          _buildGameTile(
            title: 'Lluvia de Monedas',
            plays: catcherPlaysToday,
            limit: catcherDailyLimit,
            icon: Icons.catching_pokemon_rounded,
            color: const Color(0xFFE5A93C), // Tono dorado para diferenciar
            onPlay: canPlayCatcher ? onPlayCoinCatcher : null,
          ),
          _buildGameTile(
            title: 'Piñata',
            plays: pinataPlaysToday,
            limit: pinataDailyLimit,
            icon: Icons.celebration_rounded,
            color: const Color(0xFFE05C41),
            onPlay: canPlayPinata ? onPlayPinata : null,
          ),
          _buildGameTile(
            title: 'Máquina de Garra',
            plays: clawPlaysToday,
            limit: clawDailyLimit,
            icon: Icons.pan_tool_alt_rounded, // Icono mejorado
            color: const Color(0xFFB26CFF),
            onPlay: canPlayClaw ? onPlayClaw : null,
          ),
          _buildGameTile(
            title: 'Torre de Cajas',
            plays: stackPlaysToday,
            limit: stackDailyLimit,
            icon: Icons.layers_rounded,
            color: const Color(0xFF4E79FF),
            onPlay: canPlayStack ? onPlayStack : null,
          ),
          _buildGameTile(
            title: 'Esquiva y Atrapa',
            plays: dodgePlaysToday,
            limit: dodgeDailyLimit,
            icon: Icons.swipe_rounded,
            color: const Color(0xFF3E7DD1),
            onPlay: canPlayDodge ? onPlayDodge : null,
          ),
          _buildGameTile(
            title: 'Super Salto',
            plays: superSaltoPlaysToday,
            limit: superSaltoDailyLimit,
            icon: Icons.flight_takeoff,
            color: const Color(0xFF6A5AE0),
            onPlay: canPlaySuperSalto ? onPlaySuperSalto : null,
          ),
        ],
      ),
    );
  }
}
