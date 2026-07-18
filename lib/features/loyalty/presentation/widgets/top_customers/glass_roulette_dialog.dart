import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/loyalty/presentation/bloc/top_customers_cubit.dart';
import 'package:inventory_store_app/features/loyalty/presentation/widgets/top_customers/winner_dialog.dart';

class GlassRouletteDialog extends StatefulWidget {
  const GlassRouletteDialog({super.key});

  @override
  State<GlassRouletteDialog> createState() => _GlassRouletteDialogState();
}

class _GlassRouletteDialogState extends State<GlassRouletteDialog> {
  final StreamController<int> _selectedController =
      StreamController<int>.broadcast();
  final Random _random = Random();

  @override
  void dispose() {
    _selectedController.close();
    super.dispose();
  }

  void _spinWheel() {
    final cubit = context.read<TopCustomersCubit>();
    final state = cubit.state;
    if (state.participants.isEmpty || state.isSpinning) return;

    final winnerIndex = _random.nextInt(state.participants.length);
    final winner = state.participants[winnerIndex];

    cubit.startSpinning(winner);
    _selectedController.add(winnerIndex);
  }

  void _onAnimationEnd() async {
    final cubit = context.read<TopCustomersCubit>();
    cubit.stopSpinning();

    if (!kIsWeb) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 500);
      }
    }

    if (!mounted) return;

    final state = cubit.state;
    final winner = state.winner;
    if (winner != null) {
      Navigator.of(context).pop(); // Cerrar ruleta
      showDialog(
        context: context,
        builder: (ctx) => WinnerDialog(winner: winner),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TopCustomersCubit>().state;
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sorteo Top Clientes',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                    ),
                    onPressed:
                        state.isSpinning
                            ? null
                            : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Ruleta
              Expanded(
                child: FortuneWheel(
                  animateFirst: false,
                  selected: _selectedController.stream,
                  physics: CircularPanPhysics(
                    duration: const Duration(seconds: 5),
                    curve: Curves.decelerate,
                  ),
                  onFling: () {
                    _spinWheel();
                  },
                  items: [
                    for (var p in state.participants)
                      FortuneItem(
                        child: Text(
                          p.fullName.split(' ').first,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        style: FortuneItemStyle(
                          color: Colors
                              .primaries[p.fullName.length %
                                  Colors.primaries.length]
                              .withValues(alpha: 0.8),
                          borderColor: Colors.white,
                          borderWidth: 2,
                        ),
                      ),
                  ],
                  onAnimationEnd: () => _onAnimationEnd(),
                ),
              ),
              const SizedBox(height: 32),

              // Botón de Girar
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: state.isSpinning ? null : () => _spinWheel(),
                  icon: const Icon(Icons.play_arrow_rounded, size: 28),
                  label: const Text(
                    'GIRAR RULETA',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
