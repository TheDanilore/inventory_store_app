import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:inventory_store_app/providers/admin/top_customers_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/providers/admin/customers_provider.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

class TopCustomersScreen extends StatelessWidget {
  const TopCustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TopCustomersProvider(),
      child: const _TopCustomersContent(),
    );
  }
}

class _TopCustomersContent extends StatefulWidget {
  const _TopCustomersContent();

  @override
  State<_TopCustomersContent> createState() => _TopCustomersContentState();
}

class _TopCustomersContentState extends State<_TopCustomersContent> {
  void _openRoulette() {
    final provider = context.read<TopCustomersProvider>();
    if (provider.participants.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se necesitan al menos 2 clientes para el sorteo.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar Ruleta',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ChangeNotifierProvider.value(
          value: provider,
          child: const _GlassRouletteDialog(),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TopCustomersProvider>();
    final theme = Theme.of(context);

    return AdminLayout(
      title: 'Top Clientes',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: provider.isLoading ? null : _openRoulette,
        icon: const Icon(Icons.casino_rounded, color: Colors.white),
        label: const Text(
          'Ruleta de Sorteo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primary,
        elevation: 4,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900), // Ampliado un poco para dar aire al grid
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Filtros Modernos
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Listado de Mejores Clientes',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Chips de Filtro
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [5, 10, 15, 20, 30, 50, 100].map((val) {
                          final isSelected = provider.limit == val;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(
                                'Top $val',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: provider.isLoading
                                  ? null
                                  : (selected) {
                                      if (selected) provider.setLimit(val);
                                    },
                              selectedColor: AppColors.primary,
                              backgroundColor: theme.colorScheme.surface,
                              side: BorderSide(
                                color: isSelected
                                    ? AppColors.primary
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Contenido Principal (Shimmer o Listado)
              Expanded(
                child: provider.isLoading
                    ? const _ShimmerList()
                    : provider.participants.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.group_off_rounded,
                                  size: 64,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay clientes con compras.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 700;

                              if (isWide) {
                                return GridView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(bottom: 100),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 450,
                                    mainAxisExtent: 96, // Ajustado para contener la altura de la tarjeta + margen
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 0,
                                  ),
                                  itemCount: provider.participants.length,
                                  itemBuilder: (context, index) {
                                    final c = provider.participants[index];
                                    return _AnimatedEntrance(
                                      index: index,
                                      child: _PremiumCustomerCard(
                                        customer: c,
                                        position: index + 1,
                                      ),
                                    );
                                  },
                                );
                              } else {
                                return ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8).copyWith(bottom: 100),
                                  itemCount: provider.participants.length,
                                  itemBuilder: (context, index) {
                                    final c = provider.participants[index];
                                    return _AnimatedEntrance(
                                      index: index,
                                      child: _PremiumCustomerCard(
                                        customer: c,
                                        position: index + 1,
                                      ),
                                    );
                                  },
                                );
                              }
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  const _AnimatedEntrance({required this.child, required this.index});
  @override
  State<_AnimatedEntrance> createState() => _AnimatedEntranceState();
}

class _AnimatedEntranceState extends State<_AnimatedEntrance> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Staggered delay (cap max delay to avoid too long waiting for large lists)
    final delay = (widget.index * 50).clamp(0, 500);
    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _PremiumCustomerCard extends StatefulWidget {
  final CustomerSummary customer;
  final int position;

  const _PremiumCustomerCard({required this.customer, required this.position});

  @override
  State<_PremiumCustomerCard> createState() => _PremiumCustomerCardState();
}

class _PremiumCustomerCardState extends State<_PremiumCustomerCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatCurrency = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

    final isTop3 = widget.position <= 3;
    Color? borderColor;
    List<Color>? gradientColors;
    Widget? medalIcon;

    if (widget.position == 1) {
      borderColor = const Color(0xFFFFD700); // Oro
      gradientColors = [const Color(0xFFFFD700).withValues(alpha: 0.15), const Color(0xFFFFD700).withValues(alpha: 0.02)];
      medalIcon = const Text('🥇', style: TextStyle(fontSize: 24));
    } else if (widget.position == 2) {
      borderColor = const Color(0xFFC0C0C0); // Plata
      gradientColors = [const Color(0xFFC0C0C0).withValues(alpha: 0.15), const Color(0xFFC0C0C0).withValues(alpha: 0.02)];
      medalIcon = const Text('🥈', style: TextStyle(fontSize: 24));
    } else if (widget.position == 3) {
      borderColor = const Color(0xFFCD7F32); // Bronce
      gradientColors = [const Color(0xFFCD7F32).withValues(alpha: 0.15), const Color(0xFFCD7F32).withValues(alpha: 0.02)];
      medalIcon = const Text('🥉', style: TextStyle(fontSize: 24));
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          gradient: isTop3
              ? LinearGradient(colors: gradientColors!, begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor ?? theme.colorScheme.outlineVariant.withValues(alpha: _isHovered ? 0.8 : 0.3),
            width: isTop3 ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: (borderColor ?? theme.colorScheme.shadow).withValues(alpha: _isHovered ? 0.15 : 0.03),
              blurRadius: _isHovered ? 20 : 12,
              offset: Offset(0, _isHovered ? 8 : 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              context.push('/admin/customer-detail/${widget.customer.id}', extra: widget.customer);
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Posición / Medalla
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: medalIcon ??
                          Text(
                            '#${widget.position}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: widget.customer.avatarUrl != null
                        ? CachedNetworkImageProvider(widget.customer.avatarUrl!)
                        : null,
                    child: widget.customer.avatarUrl == null
                        ? Text(
                            widget.customer.fullName[0].toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),

                  // Info del Cliente
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.customer.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cliente Destacado',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Monto Total
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        formatCurrency.format(widget.customer.totalSpent),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Comprado',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;

        Widget buildItem() {
          return Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(width: 32, height: 24, color: Colors.white),
                  const SizedBox(width: 12),
                  const CircleAvatar(radius: 24, backgroundColor: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(width: 100, height: 12, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 80, height: 16, color: Colors.white),
                      const SizedBox(height: 8),
                      Container(width: 60, height: 12, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        if (isWide) {
          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 450,
              mainAxisExtent: 96,
              crossAxisSpacing: 16,
              mainAxisSpacing: 0,
            ),
            itemCount: 8,
            itemBuilder: (context, index) => buildItem(),
          );
        } else {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: 8,
            itemBuilder: (context, index) => buildItem(),
          );
        }
      },
    );
  }
}

class _GlassRouletteDialog extends StatefulWidget {
  const _GlassRouletteDialog();

  @override
  State<_GlassRouletteDialog> createState() => _GlassRouletteDialogState();
}

class _GlassRouletteDialogState extends State<_GlassRouletteDialog> {
  final StreamController<int> _selectedController =
      StreamController<int>.broadcast();
  final Random _random = Random();

  @override
  void dispose() {
    _selectedController.close();
    super.dispose();
  }

  void _spinWheel(TopCustomersProvider provider) {
    if (provider.participants.isEmpty || provider.isSpinning) return;

    final winnerIndex = _random.nextInt(provider.participants.length);
    final winner = provider.participants[winnerIndex];

    provider.startSpinning(winner);
    _selectedController.add(winnerIndex);
  }

  void _onAnimationEnd(TopCustomersProvider provider) async {
    provider.stopSpinning();

    if (!kIsWeb) {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 500);
      }
    }

    if (!mounted) return;

    final winner = provider.winner;
    if (winner != null) {
      Navigator.of(context).pop(); // Cerrar ruleta
      showDialog(
        context: context,
        builder: (ctx) => _WinnerDialog(winner: winner),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TopCustomersProvider>();
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
                        provider.isSpinning
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
                    _spinWheel(provider);
                  },
                  items: [
                    for (var p in provider.participants)
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
                  onAnimationEnd: () => _onAnimationEnd(provider),
                ),
              ),
              const SizedBox(height: 32),

              // Botón de Girar
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed:
                      provider.isSpinning ? null : () => _spinWheel(provider),
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

class _WinnerDialog extends StatelessWidget {
  final CustomerSummary winner;

  const _WinnerDialog({required this.winner});

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de celebración
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎉', style: TextStyle(fontSize: 48)),
              ),
              const SizedBox(height: 24),
              Text(
                '¡TENEMOS UN GANADOR!',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 24),

              // Perfil del ganador
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage:
                    winner.avatarUrl != null
                        ? CachedNetworkImageProvider(winner.avatarUrl!)
                        : null,
                child:
                    winner.avatarUrl == null
                        ? Text(
                          winner.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                        : null,
              ),
              const SizedBox(height: 16),
              Text(
                winner.fullName,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cliente destacado con un total comprado de:',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  formatCurrency.format(winner.totalSpent),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.green[700],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Botón aceptar
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Celebrar y Continuar',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
