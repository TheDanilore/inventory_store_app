import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/providers/wallet_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_primary_button.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

enum _CardMatchState { hidden, revealed, matched }

class _MemoryCard {
  final String id;
  final String symbol;
  _CardMatchState state;

  _MemoryCard({required this.id, required this.symbol})
    : state = _CardMatchState.hidden;

  String get value => id;
}

class MemoramaGameScreen extends StatefulWidget {
  final String profileId;

  const MemoramaGameScreen({super.key, required this.profileId});

  @override
  State<MemoramaGameScreen> createState() => _MemoramaGameScreenState();
}

class _MemoramaGameScreenState extends State<MemoramaGameScreen> {
  final _random = Random();
  late AppConfigProvider _config;

  final List<_MemoryCard> _cards = [];
  Timer? _clockTimer;

  bool _isPlaying = false;
  bool _isGameOver = false;
  bool _isSaving = false;
  bool _isResolving = false;
  int _score = 0;
  int _timeLeft = 30;
  int? _firstIndex;

  static const String _matchRewardKey = 'memorama_match_reward';
  static const double _defaultMatchReward = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _config = context.read<AppConfigProvider>();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _buildBoard() {
    const pairs = <MapEntry<String, String>>[
      MapEntry('Michi', '🐱'),
      MapEntry('Patita', '🐾'),
      MapEntry('Pescado', '🐟'),
      MapEntry('Lana', '🧶'),
      MapEntry('Nube', '☁️'),
      MapEntry('Estrella', '⭐'),
      MapEntry('Regalo', '🎁'),
      MapEntry('Dulce', '🍬'),
    ];

    _cards
      ..clear()
      ..addAll([
        for (final pair in pairs) _MemoryCard(id: pair.key, symbol: pair.value),
        for (final pair in pairs) _MemoryCard(id: pair.key, symbol: pair.value),
      ])
      ..shuffle(_random);
  }

  void _startGame() {
    _clockTimer?.cancel();
    _buildBoard();

    setState(() {
      _isPlaying = true;
      _isGameOver = false;
      _isSaving = false;
      _isResolving = false;
      _score = 0;
      _timeLeft = 30;
      _firstIndex = null;
    });

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isPlaying) {
        timer.cancel();
        return;
      }

      if (_timeLeft <= 1) {
        timer.cancel();
        _endGame();
        return;
      }

      setState(() => _timeLeft -= 1);
    });
  }

  Future<void> _handleTap(int index) async {
    if (!_isPlaying || _isGameOver || _isResolving) return;
    if (_cards[index].state == _CardMatchState.matched ||
        _cards[index].state == _CardMatchState.revealed) {
      return;
    }

    setState(() {
      _cards[index].state = _CardMatchState.revealed;
    });

    if (!kIsWeb) {
      Vibration.vibrate(duration: 30, amplitude: 64);
    }

    if (_firstIndex == null) {
      _firstIndex = index;
      return;
    }

    final firstIndex = _firstIndex!;
    if (firstIndex == index) return;

    _isResolving = true;
    final firstCard = _cards[firstIndex];
    final secondCard = _cards[index];

    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted || !_isPlaying) return;

    if (firstCard.value == secondCard.value) {
      if (!kIsWeb) {
        Vibration.vibrate(duration: 80, amplitude: 128);
      }
      final matchReward =
          _config.getDouble(_matchRewardKey, _defaultMatchReward).round();
      setState(() {
        firstCard.state = _CardMatchState.matched;
        secondCard.state = _CardMatchState.matched;
        _score += matchReward;
        _firstIndex = null;
        _isResolving = false;
      });
    } else {
      setState(() {
        firstCard.state = _CardMatchState.hidden;
        secondCard.state = _CardMatchState.hidden;
        _firstIndex = null;
        _isResolving = false;
      });
    }

    final completed = _cards.every(
      (card) => card.state == _CardMatchState.matched,
    );
    if (completed) {
      await _endGame(completed: true);
    }
  }

  Future<void> _endGame({bool completed = false}) async {
    _clockTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _isPlaying = false;
      _isGameOver = true;
      _isSaving = true;
      _isResolving = false;
      _firstIndex = null;
    });

    if (_score > 0) {
      if (completed && !kIsWeb) {
        Vibration.vibrate(duration: 300, amplitude: 255);
      }
      if (widget.profileId == 'offline') {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Modo sin conexión. Juegas por diversión.',
            type: SnackbarType.info,
          );
          setState(() => _isSaving = false);
        }
        return;
      }
      try {
        await context.read<WalletProvider>().processGameReward(
          points: _score,
          movementType: 'MINI_GAME_MEMORY',
          description: 'Recompensa por Memorama: Ganó $_score monedas',
        );
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al procesar tu premio. Intenta de nuevo.',
            type: SnackbarType.error,
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      if (completed && _score <= 0) {
        // Mantiene el flujo consistente incluso si la recompensa queda en 0.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTapBoard = _isPlaying && !_isResolving;
    final matchReward =
        _config.getDouble(_matchRewardKey, _defaultMatchReward).round();
    final matchedPairs = matchReward <= 0 ? 0 : (_score ~/ matchReward);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isPlaying || _isGameOver)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildHudCard(
                          Icons.grid_view_rounded,
                          'Parejas',
                          Colors.amber,
                          value: '$matchedPairs/8',
                        ),
                        _buildHudCard(
                          Icons.timer_rounded,
                          'Tiempo',
                          Colors.white,
                          value: '00:${_timeLeft.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _cards.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                        itemBuilder: (context, index) {
                          final card = _cards[index];
                          final isVisible =
                              card.state != _CardMatchState.hidden;

                          return GestureDetector(
                            onTap: canTapBoard ? () => _handleTap(index) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              decoration: BoxDecoration(
                                gradient:
                                    isVisible
                                        ? const LinearGradient(
                                          colors: [
                                            Color(0xFFFFE7B3),
                                            Color(0xFFFFC85C),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                        : const LinearGradient(
                                          colors: [
                                            Color(0xFFEAF7F5),
                                            Color(0xFFD8F1EE),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color:
                                      card.state == _CardMatchState.matched
                                          ? const Color(0xFF0F9D8F)
                                          : Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child:
                                    isVisible
                                        ? Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              card.symbol,
                                              style: const TextStyle(
                                                fontSize: 24,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              card.id,
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF5B3400),
                                              ),
                                            ),
                                          ],
                                        )
                                        : const Icon(
                                          Icons.question_mark_rounded,
                                          color: Color(0xFF0F9D8F),
                                          size: 22,
                                        ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            if (!_isPlaying && !_isGameOver)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        size: 86,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Memorama contra reloj',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Encuentra las 8 parejas en 30 segundos. Cada pareja correcta suma monedas.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 40),
                      AppPrimaryButton(
                        label: 'Comenzar juego',
                        backgroundColor: Colors.amber,
                        foregroundColor: AppColors.primaryDark,
                        onPressed: _startGame,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Volver',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_isGameOver)
              Container(
                color: AppColors.primaryDark.withValues(alpha: 0.92),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¡Partida terminada!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '$_score monedas',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          completedMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 40),
                        if (_isSaving)
                          const CircularProgressIndicator(color: Colors.amber)
                        else
                          AppPrimaryButton(
                            label: 'Reclamar y salir',
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                            onPressed: () => Navigator.pop(context, _score),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String get completedMessage {
    if (_score > 0) {
      return 'Se guardó tu recompensa por Memorama en tu saldo.';
    }
    return 'No ganaste monedas esta vez, pero puedes intentarlo otra vez.';
  }

  Widget _buildHudCard(
    IconData icon,
    String label,
    Color color, {
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
