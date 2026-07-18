import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/points_state.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/points/points_design_tokens.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class PointsGameActionsSection extends StatelessWidget {
  const PointsGameActionsSection({super.key});

  Future<void> _playGame(
    BuildContext context,
    String path,
    PointsState state, {
    required bool forFun,
    required String movementType,
    required String description,
  }) async {
    final pId = forFun ? 'offline' : (state.profileId ?? 'offline');

    final r = await context.push<int>('$path/$pId');
    if (r != null && context.mounted) {
      if (!forFun && r > 0 && state.profileId != null) {
        await context.read<PointsCubit>().recordMiniGameResult(
          movementType,
          r,
          description,
        );
      }

      // Refresh points data after playing
      if (context.mounted && state.profileId != null) {
        await context.read<PointsCubit>().fetchPointsData(
          context.read<AppConfigCubit>(),
        );
      }
    }
  }

  Widget _buildGameTile({
    required BuildContext context,
    required PointsState state,
    required String title,
    required String emoji,
    required int plays,
    required int limit,
    required Color color,
    required String path,
    required String movementType,
    required String description,
  }) {
    final active = plays < limit;
    return _GameTile(
      title: title,
      emoji: emoji,
      plays: plays,
      limit: limit,
      color: color,
      active: active,
      onPlay:
          () => _playGame(
            context,
            path,
            state,
            forFun: !active,
            movementType: movementType,
            description: description,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PointsCubit, PointsState>(
      builder: (context, state) {
        final config = context.watch<AppConfigCubit>();

        final memoramaLimit =
            config.getDouble('memorama_daily_limit', 1).round();
        final catcherLimit = config.getDouble('catcher_daily_limit', 1).round();
        final pinataLimit = config.getDouble('pinata_daily_limit', 1).round();
        final clawLimit = config.getDouble('claw_daily_limit', 1).round();
        final stackLimit = config.getDouble('stack_daily_limit', 1).round();
        final dodgeLimit = config.getDouble('dodge_daily_limit', 1).round();
        final superSaltoLimit = config.getDouble('jump_daily_limit', 1).round();

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
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Más Mini Juegos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: PointsDS.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Grid de juegos
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _buildGameTile(
                    context: context,
                    state: state,
                    title: 'Memorama',
                    emoji: '🃏',
                    plays: state.memoramaPlaysToday,
                    limit: memoramaLimit,
                    color: const Color(0xFF0D9488),
                    path: '/loyalty/games/memorama',
                    movementType: 'MINI_GAME_MEMORY',
                    description: 'Memorama completado',
                  ),
                  _buildGameTile(
                    context: context,
                    state: state,
                    title: 'Súper Salto',
                    emoji: '🏃‍♂️',
                    plays: state.superSaltoPlaysToday,
                    limit: superSaltoLimit,
                    color: const Color(0xFF6366F1),
                    path: '/loyalty/games/super-salto',
                    movementType: 'MINI_GAME_JUMP',
                    description: 'Súper salto completado',
                  ),
                  _buildGameTile(
                    context: context,
                    state: state,
                    title: 'Atrapa Monedas',
                    emoji: '🌧️',
                    plays: state.catcherPlaysToday,
                    limit: catcherLimit,
                    color: const Color(0xFFE5A93C),
                    path: '/loyalty/games/catcher',
                    movementType: 'MINI_GAME_CATCHER',
                    description: 'Atrapa monedas jugado',
                  ),
                  _buildGameTile(
                    context: context,
                    state: state,
                    title: 'La Piñata',
                    emoji: '🪅',
                    plays: state.pinataPlaysToday,
                    limit: pinataLimit,
                    color: const Color(0xFFE05C41),
                    path: '/loyalty/games/pinata',
                    movementType: 'MINI_GAME_PINATA',
                    description: 'Piñata golpeada',
                  ),
                  _buildGameTile(
                    context: context,
                    state: state,
                    title: 'Máquina Garra',
                    emoji: '🕹️',
                    plays: state.clawPlaysToday,
                    limit: clawLimit,
                    color: const Color(0xFF8B5CF6),
                    path: '/loyalty/games/claw',
                    movementType: 'MINI_GAME_CLAW',
                    description: 'Máquina de garra',
                  ),
                  _buildGameTile(
                    context: context,
                    state: state,
                    title: 'Torre Perfecta',
                    emoji: '🏗️',
                    plays: state.stackPlaysToday,
                    limit: stackLimit,
                    color: const Color(0xFF3B82F6),
                    path: '/loyalty/games/stack',
                    movementType: 'MINI_GAME_STACK',
                    description: 'Torre perfecta jugada',
                  ),
                  _buildGameTile(
                    context: context,
                    state: state,
                    title: 'Esquiva Bloques',
                    emoji: '🚀',
                    plays: state.dodgePlaysToday,
                    limit: dodgeLimit,
                    color: const Color(0xFFEF4444),
                    path: '/loyalty/games/dodge',
                    movementType: 'MINI_GAME_DODGE',
                    description: 'Esquiva bloques jugado',
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
  final VoidCallback onPlay;

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
    final bgColor = color.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: onPlay,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PointsDS.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.3) : PointsDS.border,
            width: active ? 2 : 1,
          ),
          boxShadow:
              active
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: active ? bgColor : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  emoji,
                  style: TextStyle(
                    fontSize: 24,
                    color: active ? null : PointsDS.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? PointsDS.textPrimary : PointsDS.textMuted,
                height: 1.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? bgColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                active ? '$plays/$limit jugados' : 'Diversión',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: active ? color : PointsDS.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
