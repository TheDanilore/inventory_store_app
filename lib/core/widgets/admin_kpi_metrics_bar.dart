import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Modelo de datos para una métrica KPI de administración.
class AdminKpiItem {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  /// Color acento para auto-calcular gradientes, bordes y tonalidades.
  final Color? accentColor;

  /// Gradiente del fondo de la tarjeta (por defecto, sutil tint del acento o blanco).
  final List<Color>? gradientColors;

  /// Gradiente del contenedor del ícono.
  final List<Color>? iconGradient;

  /// Fondo plano alternativo para el ícono si no se usa gradiente.
  final Color? iconBgColor;

  /// Color del ícono (por defecto blanco si hay gradiente, o accentColor).
  final Color? iconColor;

  /// Color del borde de la tarjeta.
  final Color? borderColor;

  /// Color de brillo y sombra en estado hover.
  final Color? glowColor;

  /// Color personalizado para el valor numérico.
  final Color? valueColor;

  /// Color personalizado para el subtítulo.
  final Color? subtitleColor;

  /// Si es una métrica en estado de alerta (resalta en rojo/peligro si aplica).
  final bool isAlert;

  /// Callback opcional si la tarjeta es clickeable/filtrable.
  final VoidCallback? onTap;

  /// Widget opcional en la esquina derecha (ej. badge, indicador porcentual).
  final Widget? trailing;

  const AdminKpiItem({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accentColor,
    this.gradientColors,
    this.iconGradient,
    this.iconBgColor,
    this.iconColor,
    this.borderColor,
    this.glowColor,
    this.valueColor,
    this.subtitleColor,
    this.isAlert = false,
    this.onTap,
    this.trailing,
  });

  // ── PRESETS SEMÁNTICOS DE DISEÑO ──────────────────────────────────────────

  factory AdminKpiItem.teal({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) => AdminKpiItem(
    title: title,
    value: value,
    subtitle: subtitle,
    icon: icon,
    accentColor: const Color(0xFF0D9488),
    gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
    iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
    borderColor: const Color(0xFF99F6E4),
    glowColor: const Color(0x2E0D9488),
    onTap: onTap,
    trailing: trailing,
  );

  factory AdminKpiItem.green({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) => AdminKpiItem(
    title: title,
    value: value,
    subtitle: subtitle,
    icon: icon,
    accentColor: const Color(0xFF059669),
    gradientColors: const [Colors.white, Color(0xFFECFDF5)],
    iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
    borderColor: const Color(0xFFA7F3D0),
    glowColor: const Color(0x2E10B981),
    onTap: onTap,
    trailing: trailing,
  );

  factory AdminKpiItem.amber({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) => AdminKpiItem(
    title: title,
    value: value,
    subtitle: subtitle,
    icon: icon,
    accentColor: const Color(0xFFD97706),
    gradientColors: const [Colors.white, Color(0xFFFFFBEB)],
    iconGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
    borderColor: const Color(0xFFFDE68A),
    glowColor: const Color(0x2EF59E0B),
    onTap: onTap,
    trailing: trailing,
  );

  factory AdminKpiItem.red({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) => AdminKpiItem(
    title: title,
    value: value,
    subtitle: subtitle,
    icon: icon,
    accentColor: const Color(0xFFDC2626),
    gradientColors: const [Colors.white, Color(0xFFFEF2F2)],
    iconGradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
    borderColor: const Color(0xFFFECACA),
    glowColor: const Color(0x2EEF4444),
    isAlert: true,
    valueColor: const Color(0xFFDC2626),
    onTap: onTap,
    trailing: trailing,
  );

  factory AdminKpiItem.blue({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) => AdminKpiItem(
    title: title,
    value: value,
    subtitle: subtitle,
    icon: icon,
    accentColor: const Color(0xFF0284C7),
    gradientColors: const [Colors.white, Color(0xFFF0F9FF)],
    iconGradient: const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    borderColor: const Color(0xFFBAE6FD),
    glowColor: const Color(0x2E0EA5E9),
    onTap: onTap,
    trailing: trailing,
  );

  factory AdminKpiItem.primary({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) => AdminKpiItem(
    title: title,
    value: value,
    subtitle: subtitle,
    icon: icon,
    accentColor: const Color(0xFF1E293B),
    gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
    iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
    borderColor: const Color(0xFFE2E8F0),
    glowColor: const Color(0x1F0F172A),
    onTap: onTap,
    trailing: trailing,
  );

  factory AdminKpiItem.purple({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
    Widget? trailing,
  }) => AdminKpiItem(
    title: title,
    value: value,
    subtitle: subtitle,
    icon: icon,
    accentColor: const Color(0xFF7C3AED),
    gradientColors: const [Colors.white, Color(0xFFF5F3FF)],
    iconGradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    borderColor: const Color(0xFFDDD6FE),
    glowColor: const Color(0x2E8B5CF6),
    onTap: onTap,
    trailing: trailing,
  );
}

/// Tarjeta Bento KPI individual de alto nivel estético (Stripe / Apple HIG / Linear).
///
/// Soporta micro-interacciones hover en desktop (elevación -2px, glow suave y realce de borde),
/// tipografía tabular monoespaciada para cifras numéricas, y gradientes armoniosos.
class AdminKpiCard extends StatefulWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;
  final List<Color>? gradientColors;
  final List<Color>? iconGradient;
  final Color? iconBgColor;
  final Color? iconColor;
  final Color? borderColor;
  final Color? glowColor;
  final Color? valueColor;
  final Color? subtitleColor;
  final bool isAlert;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AdminKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.accentColor,
    this.gradientColors,
    this.iconGradient,
    this.iconBgColor,
    this.iconColor,
    this.borderColor,
    this.glowColor,
    this.valueColor,
    this.subtitleColor,
    this.isAlert = false,
    this.onTap,
    this.trailing,
  });

  factory AdminKpiCard.fromItem(AdminKpiItem item, {Key? key}) {
    return AdminKpiCard(
      key: key,
      title: item.title,
      value: item.value,
      subtitle: item.subtitle,
      icon: item.icon,
      accentColor: item.accentColor,
      gradientColors: item.gradientColors,
      iconGradient: item.iconGradient,
      iconBgColor: item.iconBgColor,
      iconColor: item.iconColor,
      borderColor: item.borderColor,
      glowColor: item.glowColor,
      valueColor: item.valueColor,
      subtitleColor: item.subtitleColor,
      isAlert: item.isAlert,
      onTap: item.onTap,
      trailing: item.trailing,
    );
  }

  @override
  State<AdminKpiCard> createState() => _AdminKpiCardState();
}

class _AdminKpiCardState extends State<AdminKpiCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent =
        widget.isAlert
            ? AppColors.danger
            : (widget.accentColor ??
                (isDark ? const Color(0xFF60A5FA) : AppColors.primary));

    final effectiveGradient =
        isDark
            ? [
              AppColors.darkSurfaceElevated,
              effectiveAccent.withValues(alpha: 0.12),
            ]
            : (widget.gradientColors ??
                [Colors.white, effectiveAccent.withValues(alpha: 0.04)]);

    final effectiveBorder =
        isDark
            ? (widget.isAlert
                ? AppColors.danger.withValues(alpha: 0.5)
                : AppColors.darkBorder)
            : (widget.isAlert
                ? AppColors.danger.withValues(alpha: 0.35)
                : (widget.borderColor ??
                    effectiveAccent.withValues(alpha: 0.22)));

    final effectiveGlow =
        widget.glowColor ??
        effectiveAccent.withValues(alpha: isDark ? 0.28 : 0.18);

    final effectiveValueColor =
        widget.isAlert
            ? AppColors.danger
            : (widget.valueColor ??
                (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary));

    final effectiveSubtitleColor =
        widget.isAlert
            ? AppColors.danger.withValues(alpha: 0.85)
            : (widget.subtitleColor ??
                (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary));

    final isInteractive = widget.onTap != null;

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 640;

    final cardContent = MouseRegion(
      cursor:
          isInteractive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0, 0),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 11 : 13,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: effectiveGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                _isHovered
                    ? effectiveAccent.withValues(alpha: 0.65)
                    : effectiveBorder,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? effectiveGlow : const Color(0x060F172A),
              blurRadius: _isHovered ? 14 : 6,
              offset: Offset(0, _isHovered ? 4 : 2),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildIconContainer(effectiveAccent, effectiveGlow, isMobile),
            SizedBox(width: isMobile ? 10 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: TextStyle(
                      fontSize: isMobile ? 10.0 : 10.5,
                      fontWeight: FontWeight.w800,
                      color: effectiveAccent,
                      letterSpacing: isMobile ? 0.3 : 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  _AnimatedKpiValue(
                    rawValue: widget.value,
                    style: TextStyle(
                      fontSize: isMobile ? 16.5 : 18.5,
                      fontWeight: FontWeight.w900,
                      color: effectiveValueColor,
                      letterSpacing: -0.4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: isMobile ? 10.5 : 11,
                      color: effectiveSubtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 8),
              widget.trailing!,
            ],
          ],
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _buildIconContainer(
    Color effectiveAccent,
    Color effectiveGlow,
    bool isMobile,
  ) {
    final size = isMobile ? 40.0 : 44.0;
    final iconSize = isMobile ? 20.0 : 22.0;
    final borderRadius = BorderRadius.circular(isMobile ? 10 : 12);

    if (widget.iconGradient != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.iconGradient!,
          ),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: effectiveGlow,
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          widget.icon,
          color: widget.iconColor ?? Colors.white,
          size: iconSize,
        ),
      );
    }

    if (widget.iconBgColor != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: widget.iconBgColor,
          borderRadius: borderRadius,
        ),
        child: Icon(
          widget.icon,
          color: widget.iconColor ?? effectiveAccent,
          size: iconSize,
        ),
      );
    }

    // Por defecto: Gradiente suave derivado del acento
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [effectiveAccent, effectiveAccent.withValues(alpha: 0.85)],
        ),
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: effectiveGlow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        widget.icon,
        color: widget.iconColor ?? Colors.white,
        size: iconSize,
      ),
    );
  }
}

/// Contenedor adaptativo de Métricas KPI Bento Ribbon.
///
/// Distribución:
/// - **Desktop / Tablet (>= 640px)**: Fila expansiva uniforme con separación estética.
/// - **Mobile (< 640px)**: Carrusel horizontal con física elástica (o grid 2x2 opcional).
class AdminKpiMetricsBar extends StatelessWidget {
  final List<AdminKpiItem> items;

  /// Forzar modo desktop/tablet o móvil. Si es null, se autodetecta por ancho (>= 640px).
  final bool? isDesktop;

  /// Padding exterior de la barra.
  final EdgeInsetsGeometry? padding;

  /// Separación entre tarjetas.
  final double spacing;

  /// Altura de la tarjeta en modo móvil con scroll horizontal.
  final double mobileHeight;

  /// Ancho de cada tarjeta en modo móvil con scroll horizontal.
  final double mobileItemWidth;

  /// Si es true en móvil, muestra un grid 2x2 en lugar de scroll horizontal.
  final bool isMobileGrid;

  /// Estado de carga (muestra esqueletos Shimmer idénticos).
  final bool isLoading;

  /// Número de tarjetas shimmer a renderizar si [isLoading] es true.
  final int shimmerCount;

  const AdminKpiMetricsBar({
    super.key,
    required this.items,
    this.isDesktop,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
    this.spacing = 12.0,
    this.mobileHeight = 88.0,
    this.mobileItemWidth = 230.0,
    this.isMobileGrid = true,
    this.isLoading = false,
    this.shimmerCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = isDesktop ?? (width >= 640);

    Widget content;

    if (isLoading) {
      content = _buildShimmer(desktop);
    } else if (desktop) {
      content = _buildDesktopLayout();
    } else if (isMobileGrid) {
      content = _buildMobileGridLayout();
    } else {
      content = _buildMobileScrollLayout();
    }

    if (padding != null && padding != EdgeInsets.zero) {
      return Padding(padding: padding!, child: content);
    }

    return content;
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: AdminKpiCard.fromItem(items[i])),
        ],
      ],
    );
  }

  Widget _buildMobileScrollLayout() {
    return SizedBox(
      height: mobileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder:
            (_, index) => SizedBox(
              width: mobileItemWidth,
              child: AdminKpiCard.fromItem(items[index]),
            ),
      ),
    );
  }

  Widget _buildMobileGridLayout() {
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final first = items[i];
      final second = (i + 1 < items.length) ? items[i + 1] : null;

      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: spacing));
      }

      rows.add(
        Row(
          children: [
            Expanded(child: AdminKpiCard.fromItem(first)),
            if (second != null) ...[
              SizedBox(width: spacing),
              Expanded(child: AdminKpiCard.fromItem(second)),
            ],
          ],
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildShimmer(bool desktop) {
    final count = items.isNotEmpty ? items.length : shimmerCount;

    if (desktop) {
      return Row(
        children: [
          for (int i = 0; i < count; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            const Expanded(
              child: AppShimmer(
                width: double.infinity,
                height: 84,
                borderRadius: 16,
              ),
            ),
          ],
        ],
      );
    }

    return SizedBox(
      height: mobileHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder:
            (context, index) => SizedBox(
              width: mobileItemWidth,
              child: const AppShimmer(
                width: double.infinity,
                height: double.infinity,
                borderRadius: 16,
              ),
            ),
      ),
    );
  }
}

/// Muestra cifras numéricas con animación fluida de conteo (de valor anterior a nuevo)
/// y respeta la accesibilidad desactivando la animación si el sistema lo requiere.
class _AnimatedKpiValue extends StatelessWidget {
  final String rawValue;
  final TextStyle style;

  const _AnimatedKpiValue({required this.rawValue, required this.style});

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text(
        rawValue,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // Intentar extraer prefijo, número y sufijo (ej: "S/ 3117.00", "68", "12 uds.")
    final regex = RegExp(r'^([^0-9\-\.]*)([\-0-9\.]+)(.*)$');
    final match = regex.firstMatch(rawValue.trim());

    if (match == null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          rawValue,
          key: ValueKey(rawValue),
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    final prefix = match.group(1) ?? '';
    final numStr = match.group(2) ?? '';
    final suffix = match.group(3) ?? '';
    final targetNum = double.tryParse(numStr);

    if (targetNum == null) {
      return Text(
        rawValue,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final hasDecimals = numStr.contains('.');
    final decimalPlaces = hasDecimals ? numStr.split('.')[1].length : 0;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetNum),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, val, _) {
        final formatted =
            decimalPlaces > 0
                ? val.toStringAsFixed(decimalPlaces)
                : val.round().toString();
        return Text(
          '$prefix$formatted$suffix',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
