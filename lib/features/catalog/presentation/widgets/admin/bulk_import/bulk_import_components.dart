import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';

const Color bulkImportViolet = Color(0xFF7C3AED);
const double bulkImportWideBreakpoint = 820;

// ───────────────────────────── Helpers de estilo ─────────────────────────────

Color bulkImportPrimary(BuildContext c) => Theme.of(c).colorScheme.primary;
Color bulkImportMuted(BuildContext c) => AppColors.txtSecondary(c);
Color bulkImportSoft(BuildContext c) =>
    AppColors.isDark(c) ? AppColors.darkSurfaceElevated : AppColors.surfaceDark;

String bulkImportMoney(double? v) => v == null ? '-' : v.toStringAsFixed(2);
String bulkImportDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ───────────────────────────── Componentes Reutilizables ─────────────────────────────

class BulkImportBusy extends StatelessWidget {
  final String label;
  const BulkImportBusy({super.key, required this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(color: bulkImportMuted(context))),
      ],
    ),
  );
}

class BulkImportStepHeader extends StatelessWidget {
  final BulkImportStatus status;
  final bool compact;
  const BulkImportStepHeader({
    super.key,
    required this.status,
    required this.compact,
  });

  int get _current {
    switch (status) {
      case BulkImportStatus.initial:
      case BulkImportStatus.loadingContext:
      case BulkImportStatus.parsing:
        return 0;
      case BulkImportStatus.review:
        return 1;
      case BulkImportStatus.importing:
      case BulkImportStatus.success:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = ['Configuración', 'Revisión', 'Resultado'];
    final done = status == BulkImportStatus.success;
    final primary = bulkImportPrimary(context);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _dot(context, i, labels[i], done, primary),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color:
                      (i < _current || done) ? primary : AppColors.brd(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _dot(
    BuildContext context,
    int i,
    String label,
    bool allDone,
    Color primary,
  ) {
    final active = i == _current && !allDone;
    final completed = i < _current || (allDone && i == 2);
    final reached = active || completed;
    final showLabel = !compact || active;
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? primary : Colors.transparent,
            border: Border.all(
              color: reached ? primary : AppColors.brdSubtle(context),
              width: 1.5,
            ),
          ),
          child:
              completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: reached ? Colors.white : bulkImportMuted(context),
                    ),
                  ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
              color:
                  reached
                      ? AppColors.txtPrimary(context)
                      : bulkImportMuted(context),
            ),
          ),
        ],
      ],
    );
  }
}

class BulkImportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  const BulkImportCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = bulkImportPrimary(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: AppColors.cardAdaptive(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: bulkImportMuted(context),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Opción seleccionable tipo "tarjeta" (reemplaza SegmentedButton/ChoiceChip).
class BulkImportSelectTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const BulkImportSelectTile({
    super.key,
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = bulkImportPrimary(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                selected ? primary.withValues(alpha: 0.07) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? primary : AppColors.brdSubtle(context),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      selected
                          ? primary.withValues(alpha: 0.14)
                          : bulkImportSoft(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? primary : bulkImportMuted(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: bulkImportMuted(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? primary : Colors.transparent,
                  border: Border.all(
                    color: selected ? primary : AppColors.brdSubtle(context),
                    width: 1.5,
                  ),
                ),
                child:
                    selected
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BulkImportSwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const BulkImportSwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = bulkImportPrimary(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: bulkImportMuted(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SwitchTheme(
              data: SwitchThemeData(
                thumbColor: const WidgetStatePropertyAll(Colors.white),
                trackColor: WidgetStateProperty.resolveWith(
                  (s) =>
                      s.contains(WidgetState.selected)
                          ? primary
                          : AppColors.brdSubtle(context),
                ),
                trackOutlineColor: const WidgetStatePropertyAll(
                  Colors.transparent,
                ),
              ),
              child: Switch(value: value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

class BulkImportInfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const BulkImportInfoBox({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.35))),
      ],
    ),
  );
}

class BulkImportBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const BulkImportBanner({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w500, height: 1.35),
          ),
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: color,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(actionLabel!),
          ),
      ],
    ),
  );
}

class BulkImportBadge extends StatelessWidget {
  final String text;
  final Color color;
  const BulkImportBadge(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.13),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

class BulkImportMiniChip extends StatelessWidget {
  final IconData? icon;
  final String text;
  const BulkImportMiniChip(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bulkImportSoft(context),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: bulkImportMuted(context)),
          const SizedBox(width: 5),
        ],
        Text(
          text,
          style: TextStyle(fontSize: 12, color: bulkImportMuted(context)),
        ),
      ],
    ),
  );
}

class BulkImportStatItem {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const BulkImportStatItem(this.icon, this.label, this.value, this.color);
}

/// Cuadrícula responsive: 2 columnas en móvil, 3 en tablet, hasta 6 en escritorio.
class BulkImportStatsGrid extends StatelessWidget {
  final List<BulkImportStatItem> items;
  const BulkImportStatsGrid({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        const minTile = 150.0;
        var cols = ((c.maxWidth + gap) / (minTile + gap)).floor();
        if (cols < 2) cols = 2;
        if (cols > items.length) cols = items.length;
        // Equilibra las filas (7 → 4+3 en vez de 6+1).
        final rowsCount = (items.length / cols).ceil();
        cols = (items.length / rowsCount).ceil();
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final i in items) BulkImportStatTile(item: i, width: w),
          ],
        );
      },
    );
  }
}

class BulkImportStatTile extends StatelessWidget {
  final BulkImportStatItem item;
  final double width;
  const BulkImportStatTile({
    super.key,
    required this.item,
    required this.width,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    constraints: const BoxConstraints(minHeight: 66),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: AppColors.cardAdaptive(context, elevated: false),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(item.icon, size: 19, color: item.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.value}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: bulkImportMuted(context)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class BulkImportDashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  BulkImportDashedRRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;
    final path =
        Path()..addRRect(
          RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
        );
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant BulkImportDashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
