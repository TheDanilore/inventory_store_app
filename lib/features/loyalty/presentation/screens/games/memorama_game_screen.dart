import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/config/presentation/providers/app_config_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/points_provider.dart';
import 'package:inventory_store_app/features/loyalty/presentation/providers/wallet_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_primary_button.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_loading.dart';
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
      _firstIndex = null;
    });

    if (completed && !kIsWeb) {
      Vibration.vibrate(duration: 300, amplitude: 255);
    }
  }

  Future<void> _claimRewardAndExit() async {
    setState(() => _isSaving = true);
    if (_score > 0) {
      if (widget.profileId == 'offline') {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Modo sin conexión. Juegas por diversión.',
            type: SnackbarType.info,
          );
          Navigator.pop(context, _score);
        }
        return;
      }
      try {
        await context.read<WalletProvider>().processGameReward(
          points: _score,
          movementType: 'MINI_GAME_MEMORY',
          description: 'Recompensa por Memorama: Ganó $_score monedas',
        );
        if (mounted) Navigator.pop(context, _score);
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Error al procesar tu premio. Intenta de nuevo.',
            type: SnackbarType.error,
          );
          setState(() => _isSaving = false);
        }
      }
    } else {
      if (mounted) Navigator.pop(context, 0);
    }
  }

  Future<void> _claimAndRestart() async {
    setState(() => _isSaving = true);
    if (_score > 0) {
      if (widget.profileId == 'offline') {
        _startGame();
        return;
      }
      try {
        await context.read<WalletProvider>().processGameReward(
          points: _score,
          movementType: 'MINI_GAME_MEMORY',
          description: 'Recompensa por Memorama: Ganó $_score monedas',
        );
        if (mounted) _startGame();
      } catch (e) {
        if (mounted) {
          AppSnackbar.show(context, message: 'Error al procesar tu premio.', type: SnackbarType.error);
          setState(() => _isSaving = false);
        }
      }
    } else {
      _startGame();
    }
  }


  @override
  Widget build(BuildContext context) {
    final canTapBoard = _isPlaying && !_isResolving;
    final matchReward = _config.getDouble(_matchRewardKey, _defaultMatchReward).round();
    final matchedPairs = matchReward <= 0 ? 0 : (_score ~/ matchReward);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Fondo inmersivo sutil
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: GridPaper(
                    color: Colors.white,
                    interval: 100,
                    divisions: 2,
                    subdivisions: 1,
                  ),
                ),
              ),

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
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                          itemBuilder: (context, index) {
                            final card = _cards[index];
                            final isRevealedOrMatched = card.state != _CardMatchState.hidden;
                            final isMatched = card.state == _CardMatchState.matched;

                            return GestureDetector(
                              onTap: canTapBoard ? () => _handleTap(index) : null,
                              child: TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0, end: isRevealedOrMatched ? pi : 0),
                                duration: const Duration(milliseconds: 300),
                                builder: (context, val, child) {
                                  final isFlippedUnder = val >= (pi / 2);
                                  
                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, 0.001)
                                      ..rotateY(val),
                                    child: isFlippedUnder 
                                        ? Transform( // Reverse so child isn't mirrored
                                            alignment: Alignment.center,
                                            transform: Matrix4.identity()..rotateY(pi),
                                            child: _buildCardFront(card, isMatched),
                                          )
                                        : _buildCardBack(),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              if (!_isPlaying && !_isGameOver) _buildIntroScreen(),

              if (_isGameOver) _buildGameOverScreen(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(_MemoryCard card, bool isMatched) {
    return AnimatedScale(
      scale: isMatched ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFE7B3), Color(0xFFFFC85C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMatched ? const Color(0xFF0F9D8F) : Colors.white,
            width: isMatched ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isMatched ? const Color(0xFF0F9D8F).withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.2),
              blurRadius: isMatched ? 15 : 8,
              spreadRadius: isMatched ? 2 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            card.symbol,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF334155), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.question_mark_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildIntroScreen() {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.grid_view_rounded, size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'Memorama',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Encuentra las 8 parejas en 30 segundos. ¡Sé veloz y gana monedas!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, height: 1.5, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 32),
                AppPrimaryButton(label: 'JUGAR AHORA', backgroundColor: Colors.amber, foregroundColor: AppColors.primaryDark, onPressed: _startGame),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  child: const Text('Volver', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    final completed = _cards.every((c) => c.state == _CardMatchState.matched);
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(completed ? '🏆' : '⏳', style: const TextStyle(fontSize: 80)),
                const SizedBox(height: 16),
                Text(
                  completed ? '¡Victoria!' : '¡Tiempo Agotado!',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                if (_score > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.amber.shade300)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 8),
                        Text(
                          '+$_score obtenidas',
                          style: const TextStyle(color: Colors.amber, fontSize: 20, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  )
                else
                  const Text('No ganaste monedas esta vez 😢', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                if (_isSaving)
                  const AppLoading()
                else
                  Builder(
                    builder: (context) {
                      final limit = context.read<AppConfigProvider>().getDouble('memorama_daily_limit', 1).round();
                      final played = context.read<PointsProvider>().memoramaPlaysToday;
                      final canPlayAgain = widget.profileId == 'offline' || (limit - (played + 1) > 0);

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_score > 0) ...[
                            if (canPlayAgain) ...[
                              AppPrimaryButton(
                                label: 'Reclamar y Jugar de Nuevo',
                                backgroundColor: Colors.amber,
                                foregroundColor: AppColors.primaryDark,
                                onPressed: _claimAndRestart,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: _claimRewardAndExit,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: const BorderSide(color: Colors.white, width: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  child: const Text('Reclamar y Salir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ] else ...[
                              AppPrimaryButton(
                                label: 'Reclamar y Salir',
                                backgroundColor: Colors.amber,
                                foregroundColor: AppColors.primaryDark,
                                onPressed: _claimRewardAndExit,
                              ),
                            ],
                          ] else ...[
                            if (canPlayAgain) ...[
                              AppPrimaryButton(
                                label: 'Volver a Intentar',
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                                onPressed: _startGame,
                              ),
                              const SizedBox(height: 12),
                            ],
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context, 0),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: Colors.white54, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Text('Salir', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ]
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHudCard(
    IconData icon,
    String label,
    Color color, {
    required String value,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
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
        ),
      ),
    );
  }
}
