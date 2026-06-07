import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';

class PointsMiniGameCard extends StatelessWidget {
  final List<int> prizePreview;
  final bool showPreviewValues;
  final bool isPreparingBoxes;
  final bool boxesRoundReady;
  final int shuffleSeed;
  final int playsToday;
  final int dailyLimit;
  final bool canPlay;
  final bool isPlayingMiniGame;
  final int? lastBoxesReward;
  final VoidCallback onPlayRandom;
  final void Function(int index) onPlayBox;

  const PointsMiniGameCard({
    super.key,
    required this.prizePreview,
    required this.showPreviewValues,
    required this.isPreparingBoxes,
    required this.boxesRoundReady,
    required this.shuffleSeed,
    required this.playsToday,
    required this.dailyLimit,
    required this.canPlay,
    required this.isPlayingMiniGame,
    required this.lastBoxesReward,
    required this.onPlayRandom,
    required this.onPlayBox,
  });

  @override
  Widget build(BuildContext context) {
    final attemptsLeft = (dailyLimit - playsToday).clamp(0, dailyLimit);
    final statusText = !canPlay
        ? 'Intentos: $playsToday/$dailyLimit. Hoy ya completaste este juego.'
        : isPreparingBoxes
            ? 'Intentos: $playsToday/$dailyLimit. Mira los premios y espera la mezcla.'
            : boxesRoundReady
                ? 'Intentos: $playsToday/$dailyLimit. Ahora elige una caja.'
                : 'Intentos: $playsToday/$dailyLimit. Toca “Mezclar cajas” para empezar.';

    final statusColor =
      !canPlay
        ? const Color(0xFF8A8A8A)
        : attemptsLeft == dailyLimit
          ? const Color(0xFF16794C)
          : const Color(0xFF8A5200);
    final statusBackground =
      !canPlay
        ? const Color(0xFFE5E5E5)
        : attemptsLeft == dailyLimit
          ? const Color(0xFFE8F7EF)
          : const Color(0xFFFFF4C7);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7F5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: Color(0xFF0F9D8F),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Jueguito de cajas',
                  style: TextStyle(
                    color: Color(0xFF2A2A2A),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Intentos: $playsToday/$dailyLimit',
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 12),
          Text(
            isPreparingBoxes
                ? 'Primero verás el premio de cada caja. Luego se mezclarán para esconderlo.'
                : 'Las cajas se mezclan al azar en cada jugada. El premio no se muestra hasta elegir una.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(prizePreview.length, (index) {
              final reward = prizePreview[index];
              final locked = !canPlay || isPlayingMiniGame || !boxesRoundReady;
              final shouldShowValue = showPreviewValues;
              final wobble = isPreparingBoxes ? ((shuffleSeed + index) % 3 - 1) * 0.03 : 0.0;
              final verticalShift = isPreparingBoxes ? ((shuffleSeed + index * 2) % 3 - 1) * 4.0 : 0.0;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: index == 0 ? 0 : 8),
                  child: GestureDetector(
                    onTap: locked ? null : () => onPlayBox(index),
                    child: Transform.translate(
                      offset: Offset(0, verticalShift),
                      child: Transform.rotate(
                        angle: wobble,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFE7B3), Color(0xFFFFC85C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                shouldShowValue
                                    ? Icons.casino_rounded
                                    : locked
                                        ? Icons.lock_rounded
                                        : Icons.card_giftcard_rounded,
                                color: const Color(0xFF7A4500),
                                size: 30,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                shouldShowValue ? 'Premio visible' : locked ? 'Caja' : 'Caja ${index + 1}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF7A4500),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                shouldShowValue
                                    ? '+$reward'
                                    : locked
                                        ? 'Toca para ver'
                                        : 'Toca para jugar',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF7A4500),
                                  fontSize: 12,
                                ),
                              ),
                              if (!canPlay && lastBoxesReward == reward) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '+$reward',
                                  style: const TextStyle(
                                    color: Color(0xFF5B3400),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          AppPrimaryButton(
            label: canPlay ? 'Mezclar cajas' : 'Completado por hoy',
            onPressed: canPlay ? onPlayRandom : null,
            loading: isPlayingMiniGame,
            icon: const Icon(Icons.casino_rounded, color: Colors.white),
            backgroundColor: const Color(0xFF0F9D8F),
            foregroundColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
