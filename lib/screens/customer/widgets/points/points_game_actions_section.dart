import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/customer/points_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/points/points_design_tokens.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PointsGameActionsSection extends StatelessWidget {
  const PointsGameActionsSection({super.key});

  Future<void> _playGame(BuildContext context, String path) async {
    final provider = context.read<PointsProvider>();
    final wallet = context.read<WalletProvider>();
    if (provider.profileId == null) return;

    final r = await context.push<int>('$path/${provider.profileId}');
    if (r != null && context.mounted) {
      if (r > 0) {
        final newBalance = (wallet.balance ?? 0) + r;
        try {
          await Supabase.instance.client.from('profiles').update({
            'wallet_balance': newBalance,
          }).eq('id', provider.profileId!);
          wallet.addLocalBalance(r);
        } catch (e) {
          debugPrint('Error actualizando balance tras juego: $e');
        }
      }

      // Refresh points data after playing
      if (context.mounted) {
        await context.read<PointsProvider>().fetchPointsData(
          context.read<AppConfigProvider>(),
        );
      }
    }
  }

  Widget _buildGameTile({
    required String title,
    required String emoji,
    required int plays,
    required int limit,
    required Color color,
    required VoidCallback? onPlay,
  }) {
    final active = plays < limit;
    return _GameTile(
      title: title,
      emoji: emoji,
      plays: plays,
      limit: limit,
      color: color,
      active: active,
      onPlay: onPlay,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PointsProvider>();
    final config = context.watch<AppConfigProvider>();

    final memoramaLimit = config.getDouble('memorama_daily_limit', 1).round();
    final catcherLimit = config.getDouble('catcher_daily_limit', 1).round();
    final pinataLimit = config.getDouble('pinata_daily_limit', 1).round();
    final clawLimit = config.getDouble('claw_daily_limit', 1).round();
    final stackLimit = config.getDouble('stack_daily_limit', 1).round();
    final dodgeLimit = config.getDouble('dodge_daily_limit', 1).round();
    final superSaltoLimit = config.getDouble('jump_daily_limit', 1).round();

    final canPlayMemorama = provider.memoramaPlaysToday < memoramaLimit;
    final canPlayCatcher = provider.catcherPlaysToday < catcherLimit;
    final canPlayPinata = provider.pinataPlaysToday < pinataLimit;
    final canPlayClaw = provider.clawPlaysToday < clawLimit;
    final canPlayStack = provider.stackPlaysToday < stackLimit;
    final canPlayDodge = provider.dodgePlaysToday < dodgeLimit;
    final canPlaySuperSalto = provider.superSaltoPlaysToday < superSaltoLimit;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: PointsDS.surface,
        borderRadius: BorderRadius.circular(PointsDS.radiusXl),
        boxShadow: PointsDS.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Juegos Diarios',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: PointsDS.textPrimary,
                      ),
                    ),
                    Text(
                      'Diviértete y gana monedas extra',
                      style: TextStyle(fontSize: 11, color: PointsDS.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Game tiles grid
          _buildGameTile(
            title: 'Memorama',
            emoji: '🃏',
            plays: provider.memoramaPlaysToday,
            limit: memoramaLimit,
            color: PointsDS.teal,
            onPlay:
                canPlayMemorama
                    ? () => _playGame(context, '/customer/games/memorama')
                    : null,
          ),
          _buildGameTile(
            title: 'Lluvia de Monedas',
            emoji: '🌧️',
            plays: provider.catcherPlaysToday,
            limit: catcherLimit,
            color: const Color(0xFFE5A93C),
            onPlay:
                canPlayCatcher
                    ? () => _playGame(context, '/customer/games/coin-catcher')
                    : null,
          ),
          _buildGameTile(
            title: 'Piñata',
            emoji: '🪅',
            plays: provider.pinataPlaysToday,
            limit: pinataLimit,
            color: const Color(0xFFE05C41),
            onPlay:
                canPlayPinata
                    ? () => _playGame(context, '/customer/games/pinata')
                    : null,
          ),
          _buildGameTile(
            title: 'Máquina de Garra',
            emoji: '🕹️',
            plays: provider.clawPlaysToday,
            limit: clawLimit,
            color: const Color(0xFFB26CFF),
            onPlay:
                canPlayClaw
                    ? () => _playGame(context, '/customer/games/claw-machine')
                    : null,
          ),
          _buildGameTile(
            title: 'Torre de Cajas',
            emoji: '📦',
            plays: provider.stackPlaysToday,
            limit: stackLimit,
            color: const Color(0xFF4E79FF),
            onPlay:
                canPlayStack
                    ? () => _playGame(context, '/customer/games/stack')
                    : null,
          ),
          _buildGameTile(
            title: 'Esquiva y Atrapa',
            emoji: '🏃',
            plays: provider.dodgePlaysToday,
            limit: dodgeLimit,
            color: const Color(0xFF3E7DD1),
            onPlay:
                canPlayDodge
                    ? () => _playGame(context, '/customer/games/dodge')
                    : null,
          ),
          _buildGameTile(
            title: 'Super Salto',
            emoji: '👟',
            plays: provider.superSaltoPlaysToday,
            limit: superSaltoLimit,
            color: const Color(0xFF6A5AE0),
            onPlay:
                canPlaySuperSalto
                    ? () => _playGame(context, '/customer/games/super-salto')
                    : null,
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  final String title;
  final String emoji;
  final int plays;
  final int limit;
  final Color color;
  final bool active;
  final VoidCallback? onPlay;

  const _GameTile({
    required this.title,
    required this.emoji,
    required this.plays,
    required this.limit,
    required this.color,
    required this.active,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(PointsDS.radius),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.2) : PointsDS.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? onPlay : null,
          borderRadius: BorderRadius.circular(PointsDS.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Emoji icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        active
                            ? color.withValues(alpha: 0.12)
                            : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),

                // Title + attempts
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              active
                                  ? PointsDS.textPrimary
                                  : PointsDS.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            active
                                ? Icons.play_arrow_rounded
                                : Icons.check_circle_rounded,
                            size: 14,
                            color: active ? color : PointsDS.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$plays / $limit jugadas hoy',
                            style: TextStyle(
                              color:
                                  active
                                      ? PointsDS.textSecondary
                                      : PointsDS.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Button / Status
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Jugar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  const Text(
                    'Mañana',
                    style: TextStyle(
                      color: PointsDS.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
