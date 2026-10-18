import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

const Color _violet = Color(0xFF7C3AED);
const double _wideBreakpoint = 820;

// ───────────────────────────── Helpers de estilo ─────────────────────────────

Color _primary(BuildContext c) => Theme.of(c).colorScheme.primary;
Color _muted(BuildContext c) => AppColors.txtSecondary(c);
Color _soft(BuildContext c) =>
    AppColors.isDark(c) ? AppColors.darkSurfaceElevated : AppColors.surfaceDark;

String _money(double? v) => v == null ? '-' : v.toStringAsFixed(2);
String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ───────────────────────────── Pantalla ─────────────────────────────

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BulkImportCubit>().loadContext();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BulkImportCubit, BulkImportState>(
      listenWhen:
          (p, c) => p.status != c.status || p.errorMessage != c.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null) {
          AppSnackbar.show(
            context,
            message: state.errorMessage!,
            type: SnackbarType.error,
          );
        }
        if (state.status == BulkImportStatus.success) {
          context.read<AdminCatalogCubit>().refreshProducts(forceRefresh: true);
        }
      },
      child: BlocBuilder<BulkImportCubit, BulkImportState>(
        builder: (context, state) {
          final importing = state.status == BulkImportStatus.importing;
          void warnBusy() => AppSnackbar.show(
            context,
            message: 'La importación está en curso, por favor espere.',
            type: SnackbarType.warning,
          );

          return PopScope(
            canPop: !importing,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && importing) warnBusy();
            },
            child: AdminLayout(
              title: 'Importación Masiva (Excel / CSV)',
              showBackButton: true,
              onBack: importing ? warnBusy : null,
              body: Container(
                color: AppColors.bg(context),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final compact = c.maxWidth < _wideBreakpoint;

                    if (state.status == BulkImportStatus.review) {
                      final pad = compact ? 16.0 : 24.0;
                      return Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1200,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: _StepHeader(
                                    status: state.status,
                                    compact: compact,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 16 : 24),
                          Expanded(child: _content(state, compact)),
                        ],
                      );
                    }

                    return Padding(
                      padding: EdgeInsets.all(compact ? 16 : 24),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1200),
                          child: Column(
                            children: [
                              _StepHeader(
                                status: state.status,
                                compact: compact,
                              ),
                              SizedBox(height: compact ? 16 : 24),
                              Expanded(child: _content(state, compact)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content(BulkImportState state, bool compact) {
    switch (state.status) {
      case BulkImportStatus.loadingContext:
      case BulkImportStatus.parsing:
        return _Busy(
          label:
              state.status == BulkImportStatus.parsing
                  ? 'Leyendo y validando el archivo...'
                  : 'Cargando configuración...',
        );
      case BulkImportStatus.initial:
        return _ConfigView(state: state, compact: compact);
      case BulkImportStatus.review:
        return _ReviewView(state: state, compact: compact);
      case BulkImportStatus.importing:
        return _ImportingView(state: state);
      case BulkImportStatus.success:
        return _SuccessView(state: state, compact: compact);
    }
  }
}

// ───────────────────────────── Piezas reutilizables ─────────────────────────────

class _Busy extends StatelessWidget {
  final String label;
  const _Busy({required this.label});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        Text(label, style: TextStyle(color: _muted(context))),
      ],
    ),
  );
}

class _StepHeader extends StatelessWidget {
  final BulkImportStatus status;
  final bool compact;
  const _StepHeader({required this.status, required this.compact});

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
    final primary = _primary(context);
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
                      color: reached ? Colors.white : _muted(context),
                    ),
                  ),
        ),
        if (showLabel) ...[
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
              color: reached ? AppColors.txtPrimary(context) : _muted(context),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  const _Card({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = _primary(context);
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
                          color: _muted(context),
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
class _SelectTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _SelectTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = _primary(context);
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
                          : _soft(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected ? primary : _muted(context),
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
                          color: _muted(context),
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

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = _primary(context);
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
                      color: _muted(context),
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

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _InfoBox({required this.icon, required this.color, required this.text});

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

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _Banner({
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

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, this.color);

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

class _MiniChip extends StatelessWidget {
  final IconData? icon;
  final String text;
  const _MiniChip(this.text, {this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _soft(context),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: _muted(context)),
          const SizedBox(width: 5),
        ],
        Text(text, style: TextStyle(fontSize: 12, color: _muted(context))),
      ],
    ),
  );
}

class _StatItem {
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  const _StatItem(this.icon, this.label, this.value, this.color);
}

/// Cuadrícula responsive: 2 columnas en móvil, 3 en tablet, hasta 6 en escritorio.
class _StatsGrid extends StatelessWidget {
  final List<_StatItem> items;
  const _StatsGrid({required this.items});

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
          children: [for (final i in items) _StatTile(item: i, width: w)],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final _StatItem item;
  final double width;
  const _StatTile({required this.item, required this.width});

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
                style: TextStyle(fontSize: 12, color: _muted(context)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedRRectPainter({required this.color, required this.radius});

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
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

// ───────────────────────────── Paso 1: Configuración ─────────────────────────────

class _ConfigView extends StatelessWidget {
  final BulkImportState state;
  final bool compact;
  const _ConfigView({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BulkImportCubit>();
    final left = Column(
      children: [
        _warehouseCard(context, cubit),
        const SizedBox(height: 16),
        _modeCard(context, cubit),
      ],
    );
    final right = Column(
      children: [
        _dropZone(context, cubit),
        const SizedBox(height: 16),
        _ColumnsGuide(compact: compact),
      ],
    );

    return SingleChildScrollView(
      child:
          compact
              ? Column(children: [left, const SizedBox(height: 16), right])
              : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: left),
                  const SizedBox(width: 20),
                  Expanded(flex: 6, child: right),
                ],
              ),
    );
  }

  Widget _warehouseCard(BuildContext context, BulkImportCubit cubit) {
    final ws = state.warehouses;
    Widget body;
    if (ws.isEmpty) {
      body = const _InfoBox(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        text:
            'No hay almacenes creados. Puedes importar el catálogo, pero las filas con stock serán rechazadas hasta que crees un almacén.',
      );
    } else if (ws.length == 1) {
      body = _InfoBox(
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        text: 'El stock se cargará en el almacén «${ws.first.name}».',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in ws) ...[
            _SelectTile(
              icon: Icons.warehouse_outlined,
              title: w.name,
              selected: state.selectedWarehouseId == w.id,
              onTap: () => cubit.setWarehouseId(w.id),
            ),
            const SizedBox(height: 10),
          ],
          if (state.needsWarehouseChoice)
            const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.error),
                SizedBox(width: 6),
                Text(
                  'Elige un almacén para continuar.',
                  style: TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ),
        ],
      );
    }
    return _Card(
      icon: Icons.warehouse_outlined,
      title: 'Almacén destino',
      subtitle: 'Los productos son globales; solo el stock entra al almacén.',
      child: body,
    );
  }

  Widget _modeCard(BuildContext context, BulkImportCubit cubit) {
    final add = state.stockMode == ImportStockMode.add;
    return _Card(
      icon: Icons.tune_rounded,
      title: 'Si el producto ya existe',
      subtitle: 'Los productos nuevos siempre entran con la cantidad del CSV.',
      child: Column(
        children: [
          _SelectTile(
            icon: Icons.add_circle_outline_rounded,
            title: 'Sumar al stock',
            subtitle:
                'Registra una entrada. Ej: stock 50 + CSV 30 → queda 80. Ideal para recibir mercadería.',
            selected: add,
            onTap: () => cubit.setStockMode(ImportStockMode.add),
          ),
          const SizedBox(height: 10),
          _SelectTile(
            icon: Icons.sync_alt_rounded,
            title: 'Reemplazar stock',
            subtitle:
                'Registra un ajuste. Ej: stock 50, CSV 30 → queda 30. Ideal para conteos; es seguro repetir.',
            selected: !add,
            onTap: () => cubit.setStockMode(ImportStockMode.replace),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: AppColors.brd(context)),
          ),
          _SwitchRow(
            title: 'Actualizar precios de productos existentes',
            subtitle:
                'Apagado: solo se toca el stock y los precios actuales se conservan.',
            value: state.updatePrices,
            onChanged: cubit.setUpdatePrices,
          ),
        ],
      ),
    );
  }

  Widget _dropZone(BuildContext context, BulkImportCubit cubit) {
    final primary = _primary(context);
    final blocked = state.needsWarehouseChoice;
    return DropTarget(
      onDragDone: (detail) async {
        if (blocked || detail.files.isEmpty) return;
        final xFile = detail.files.first;
        final bytes = await xFile.readAsBytes();
        await cubit.parseBytes(fileName: xFile.name, bytes: bytes);
      },
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color:
              blocked
                  ? AppColors.brdSubtle(context)
                  : primary.withValues(alpha: 0.45),
          radius: 18,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 24,
            vertical: compact ? 28 : 40,
          ),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: blocked ? 0.015 : 0.035),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: blocked ? 0.06 : 0.12),
                ),
                child: Icon(
                  Icons.upload_file_rounded,
                  size: 34,
                  color: blocked ? _muted(context) : primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sube tu archivo Excel o CSV',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Arrastra tu archivo o selecciónalo para revisarlo antes de importar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted(context)),
              ),
              const SizedBox(height: 14),
              const Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _MiniChip(
                    '.xlsx, .xls, .csv',
                    icon: Icons.table_chart_outlined,
                  ),
                  _MiniChip('Hasta 5 000 filas'),
                  _MiniChip('Auto-detección de columnas'),
                ],
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: blocked ? null : cubit.pickAndParseFile,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Seleccionar archivo'),
              ),
              if (blocked) ...[
                const SizedBox(height: 10),
                Text(
                  'Elige primero el almacén destino.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        AppColors.isDark(context)
                            ? AppColors.warning
                            : AppColors.warningDark,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () => cubit.downloadTemplate(asExcel: true),
                    icon: const Icon(
                      Icons.table_chart_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                    label: const Text('Plantilla Excel (.xlsx)'),
                  ),
                  TextButton.icon(
                    onPressed: () => cubit.downloadTemplate(asExcel: false),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Plantilla CSV (.csv)'),
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

class _ColumnsGuide extends StatelessWidget {
  final bool compact;
  const _ColumnsGuide({required this.compact});

  static const _cols = <(String, bool, String)>[
    (
      'nombre',
      true,
      'Nombre del producto. Varias filas con el mismo nombre + marca = un producto con varias variantes.',
    ),
    (
      'precio_compra',
      true,
      'Costo de compra por unidad. También acepta "costo".',
    ),
    ('precio_venta', true, 'Precio de venta al público.'),
    ('marca', false, 'Marca o laboratorio. Si no existe, se crea.'),
    ('categoria', false, 'Categoría. Si no existe, se crea.'),
    (
      'variante',
      false,
      'Ej. "400mg", "Talla M". Se guarda como atributo "Variante". Vacío = variante única.',
    ),
    (
      'sku',
      false,
      'Código único. Si falta, se identifica por nombre + marca + variante.',
    ),
    ('precio_mayor', false, 'Precio por mayor.'),
    (
      'cantidad_mayor',
      false,
      'Cantidad mínima para aplicar el precio por mayor.',
    ),
    ('stock', false, 'Cantidad entera. Vacío = 0 (solo catálogo).'),
    (
      'usa_lotes',
      false,
      '"si" o "no". Si hay lote o vencimiento se asume "si".',
    ),
    (
      'lote',
      false,
      'Obligatorio si el producto usa lotes y hay stock. Una fila por lote.',
    ),
    (
      'vencimiento',
      false,
      'AAAA-MM-DD o DD/MM/AAAA. Obligatorio con lotes y stock.',
    ),
    (
      'componentes',
      false,
      'Principios activos de todo el producto. Varios: sepáralos con ;',
    ),
    ('descripcion', false, 'Descripción del producto.'),
    ('imagen_url', false, 'URL de la imagen.'),
  ];

  @override
  Widget build(BuildContext context) {
    final primary = _primary(context);
    return Container(
      decoration: AppColors.cardAdaptive(context),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.view_column_outlined, size: 18, color: primary),
          ),
          title: const Text(
            'Columnas del archivo',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
          ),
          subtitle: Text(
            'Una fila = una variante (y un lote, si aplica)',
            style: TextStyle(fontSize: 12.5, color: _muted(context)),
          ),
          children: [
            _section(context, 'Obligatorias', true),
            const SizedBox(height: 12),
            _section(context, 'Opcionales', false),
            const SizedBox(height: 12),
            _InfoBox(
              icon: Icons.info_outline,
              color: AppColors.info,
              text:
                  'Si el producto ya existe, su categoría, componentes y descripción no se modifican; solo se agregan variantes, lotes y stock.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, bool required) {
    final items = _cols.where((c) => c.$2 == required).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: required ? AppColors.error : _muted(context),
          ),
        ),
        const SizedBox(height: 6),
        for (final c in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child:
                compact
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _name(context, c.$1),
                        const SizedBox(height: 4),
                        Text(
                          c.$3,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: _muted(context),
                          ),
                        ),
                      ],
                    )
                    : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 160, child: _name(context, c.$1)),
                        Expanded(
                          child: Text(
                            c.$3,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: _muted(context),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
      ],
    );
  }

  Widget _name(BuildContext context, String n) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _soft(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        n,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

// ───────────────────────────── Paso 2: Revisión ─────────────────────────────

enum _Filter { all, created, existing, warnings, errors }

/// Barra que queda fija arriba al hacer scroll (filtros de la revisión).
class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color background;
  final double height;
  const _PinnedBarDelegate({
    required this.child,
    required this.background,
    required this.height,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: background,
        border:
            overlapsContent
                ? Border(
                  bottom: BorderSide(color: AppColors.brdSubtle(context)),
                )
                : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedBarDelegate old) => true;
}

class _ReviewView extends StatefulWidget {
  final BulkImportState state;
  final bool compact;
  const _ReviewView({required this.state, required this.compact});

  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  _Filter _filter = _Filter.all;
  static const int _maxShown = 300;

  final ScrollController _scroll = ScrollController();
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    _hScroll.dispose();
    super.dispose();
  }

  bool _isCreated(ImportRow r) =>
      !r.hasError && r.action != ImportRowAction.updateVariant;
  bool _isExisting(ImportRow r) =>
      !r.hasError && r.action == ImportRowAction.updateVariant;

  List<ImportRow> _filtered(List<ImportRow> all) {
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.created:
        return all.where(_isCreated).toList();
      case _Filter.existing:
        return all.where(_isExisting).toList();
      case _Filter.warnings:
        return all.where((r) => r.hasWarning).toList();
      case _Filter.errors:
        return all.where((r) => r.hasError).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final compact = widget.compact;
    final cubit = context.read<BulkImportCubit>();
    final pad = compact ? 16.0 : 24.0;

    return LayoutBuilder(
      builder: (context, c) {
        // Contenido centrado (máx. 1200) con margen lateral propio: el scroll
        // ocupa todo el ancho y su barra queda en el borde derecho.
        final contentW = (c.maxWidth - 2 * pad).clamp(0.0, 1200.0).toDouble();
        final side = (c.maxWidth - contentW) / 2;
        final hPad = EdgeInsets.symmetric(horizontal: side);

        if (state.fileErrors.isNotEmpty) {
          return Padding(
            padding: EdgeInsets.fromLTRB(side, 0, side, pad),
            child: _fileErrors(context, state, cubit),
          );
        }

        final rows = _filtered(state.rows);
        final intro = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fileHeader(context, state, cubit),
            if (state.importError != null) ...[
              const SizedBox(height: 12),
              _Banner(
                icon: Icons.error_outline,
                color: AppColors.error,
                text: state.importError!,
              ),
            ],
            const SizedBox(height: 14),
            _StatsGrid(items: _stats(state.summary)),
            const SizedBox(height: 14),
            _statusBanner(state.summary),
            const SizedBox(height: 6),
          ],
        );

        final Widget rowsSliver =
            rows.isEmpty
                ? SliverToBoxAdapter(child: _empty(context))
                : compact
                ? SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i >= _maxShown) {
                        return _moreNote(context, rows.length);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RowCard(row: rows[i], mode: state.stockMode),
                      );
                    },
                    childCount:
                        rows.length > _maxShown ? _maxShown + 1 : rows.length,
                  ),
                )
                : SliverToBoxAdapter(
                  child: _table(context, rows, state.stockMode),
                );

        // Toda la revisión hace scroll junta (resumen + tabla); los filtros
        // quedan fijos arriba y la barra de importar fija abajo.
        final Widget body = Scrollbar(
          controller: _scroll,
          thumbVisibility: !compact,
          child: CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: hPad,
                sliver: SliverToBoxAdapter(child: intro),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _PinnedBarDelegate(
                  height: 56,
                  background: AppColors.bg(context),
                  child: Padding(padding: hPad, child: _filters(state)),
                ),
              ),
              SliverPadding(padding: hPad, sliver: rowsSliver),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        );

        return Column(
          children: [
            Expanded(child: body),
            Padding(
              padding: EdgeInsets.fromLTRB(side, 12, side, pad),
              child: _actionBar(context, state, cubit),
            ),
          ],
        );
      },
    );
  }

  List<_StatItem> _stats(ImportSummary s) => [
    _StatItem(
      Icons.inventory_2_outlined,
      'Productos nuevos',
      s.newProducts,
      AppColors.success,
    ),
    _StatItem(
      Icons.style_outlined,
      'Variantes nuevas',
      s.newVariants,
      AppColors.info,
    ),
    _StatItem(
      Icons.sync_alt_rounded,
      'Variantes existentes',
      s.updatedVariants,
      _violet,
    ),
    _StatItem(
      Icons.layers_outlined,
      'Unidades de stock',
      s.units,
      AppColors.amber,
    ),
    if (s.lots > 0)
      _StatItem(Icons.inventory_outlined, 'Lotes de stock', s.lots, _violet),
    if (s.newBrands > 0)
      _StatItem(
        Icons.local_offer_outlined,
        'Marcas a crear',
        s.newBrands,
        AppColors.teal,
      ),
    if (s.newCategories > 0)
      _StatItem(
        Icons.category_outlined,
        'Categorías a crear',
        s.newCategories,
        AppColors.teal,
      ),
  ];

  Widget _fileErrors(
    BuildContext context,
    BulkImportState state,
    BulkImportCubit cubit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Banner(
          icon: Icons.error_outline,
          color: AppColors.error,
          text: 'No se puede procesar "${state.fileName ?? 'el archivo'}".',
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: AppColors.cardAdaptive(context, elevated: false),
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: state.fileErrors.length,
              separatorBuilder:
                  (_, _) => Divider(height: 1, color: AppColors.brd(context)),
              itemBuilder:
                  (_, i) => ListTile(
                    leading: const Icon(
                      Icons.close_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(state.fileErrors[i]),
                  ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: cubit.reset,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Elegir otro archivo'),
          ),
        ),
      ],
    );
  }

  Widget _fileHeader(
    BuildContext context,
    BulkImportState state,
    BulkImportCubit cubit,
  ) {
    final primary = _primary(context);
    final wh = state.selectedWarehouse?.name ?? 'Sin almacén';
    final mode =
        state.stockMode == ImportStockMode.add
            ? 'Sumar al stock'
            : 'Reemplazar stock';
    final hasIssues = state.rows.any((r) => r.issues.isNotEmpty);

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (hasIssues)
          PopupMenuButton<bool>(
            tooltip: 'Descargar reporte de incidencias',
            onSelected:
                (asExcel) => cubit.downloadIssuesReport(asExcel: asExcel),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: true,
                    child: Row(
                      children: [
                        Icon(
                          Icons.table_chart_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 8),
                        Text('Reporte Excel (.xlsx)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: false,
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Reporte CSV (.csv)'),
                      ],
                    ),
                  ),
                ],
            child: OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Reporte'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: cubit.reset,
          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
          label: const Text('Cambiar archivo'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
      ],
    );

    final info = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.description_outlined, color: primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.fileName ?? 'archivo.csv',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${state.summary.totalRows} filas leídas',
                style: TextStyle(fontSize: 12.5, color: _muted(context)),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppColors.cardAdaptive(context, elevated: false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [info, const SizedBox(height: 12), actions],
              )
              : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  actions,
                ],
              ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniChip(wh, icon: Icons.warehouse_outlined),
              _MiniChip(mode, icon: Icons.sync_alt_rounded),
              _MiniChip(
                state.updatePrices ? 'Actualiza precios' : 'Conserva precios',
                icon: Icons.sell_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBanner(ImportSummary s) {
    if (s.errorRows > 0) {
      return _Banner(
        icon: Icons.error_outline_rounded,
        color: AppColors.error,
        text:
            '${s.errorRows} ${s.errorRows == 1 ? 'fila tiene' : 'filas tienen'} errores y no se importarán. Corrige el CSV y vuelve a subirlo si quieres incluirlas.',
        actionLabel: 'Ver errores',
        onAction: () => setState(() => _filter = _Filter.errors),
      );
    }
    if (s.warningRows > 0) {
      return _Banner(
        icon: Icons.warning_amber_rounded,
        color: AppColors.warning,
        text:
            '${s.warningRows} ${s.warningRows == 1 ? 'fila tiene' : 'filas tienen'} advertencias; se importarán igualmente.',
        actionLabel: 'Revisar',
        onAction: () => setState(() => _filter = _Filter.warnings),
      );
    }
    return _Banner(
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.success,
      text: 'Todo en orden: ${s.validRows} filas listas para importar.',
    );
  }

  Widget _filters(BulkImportState state) {
    final s = state.summary;
    final items = <(_Filter, String, int)>[
      (_Filter.all, 'Todas', s.totalRows),
      (_Filter.created, 'Se crean', state.rows.where(_isCreated).length),
      (_Filter.existing, 'Ya existen', state.rows.where(_isExisting).length),
      (_Filter.warnings, 'Advertencias', s.warningRows),
      (_Filter.errors, 'Errores', s.errorRows),
    ];
    final primary = _primary(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() => _filter = it.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _filter == it.$1 ? primary : AppColors.surf(context),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          _filter == it.$1
                              ? primary
                              : AppColors.brdSubtle(context),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        it.$2,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              _filter == it.$1
                                  ? Colors.white
                                  : AppColors.txtPrimary(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _filter == it.$1
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : _soft(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${it.$3}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color:
                                _filter == it.$1
                                    ? Colors.white
                                    : _muted(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: Text(
        'No hay filas en este filtro.',
        style: TextStyle(color: _muted(context)),
      ),
    ),
  );

  Widget _moreNote(BuildContext context, int total) => Padding(
    padding: const EdgeInsets.all(14),
    child: Text(
      'Mostrando $_maxShown de $total filas. Todas se procesan; usa los filtros o el reporte para revisar el resto.',
      style: TextStyle(color: _muted(context), fontSize: 12.5),
    ),
  );

  // Tabla de escritorio. Columnas: (título, ancho)
  static const _cols = <(String, double)>[
    ('Fila', 52),
    ('Estado', 140),
    ('Producto', 210),
    ('Marca', 120),
    ('Variante', 100),
    ('SKU', 100),
    ('Compra', 72),
    ('Venta', 72),
    ('Mayor', 72),
    ('Stock', 64),
    ('Lote', 96),
    ('Vence', 92),
    ('Detalle', 340),
  ];
  static final double _totalWidth = _cols.fold(0.0, (a, c) => a + c.$2);

  Widget _table(
    BuildContext context,
    List<ImportRow> rows,
    ImportStockMode mode,
  ) {
    if (rows.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: AppColors.cardAdaptive(context, elevated: false),
        child: _empty(context),
      );
    }
    final shown = rows.take(_maxShown).toList();
    return Container(
      decoration: AppColors.cardAdaptive(context, elevated: false),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = c.maxWidth > _totalWidth ? c.maxWidth : _totalWidth;
          return Scrollbar(
            controller: _hScroll,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _hScroll,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      color: _soft(context),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          for (final col in _cols)
                            SizedBox(
                              width:
                                  col.$1 == 'Detalle'
                                      ? col.$2 + (width - _totalWidth)
                                      : col.$2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Text(
                                  col.$1.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                    color: _muted(context),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, color: AppColors.brd(context)),
                      _TableRow(
                        row: shown[i],
                        mode: mode,
                        extraDetailWidth: width - _totalWidth,
                      ),
                    ],
                    if (rows.length > _maxShown)
                      _moreNote(context, rows.length),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _actionBar(
    BuildContext context,
    BulkImportState state,
    BulkImportCubit cubit,
  ) {
    final s = state.summary;
    final canImport = s.validRows > 0;
    final label =
        state.canResume
            ? 'Reanudar importación'
            : 'Importar ${s.validRows} ${s.validRows == 1 ? 'fila' : 'filas'}';

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${s.validRows} de ${s.totalRows} filas listas',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        if (s.errorRows > 0)
          Text(
            '${s.errorRows} con error se omitirán',
            style: const TextStyle(fontSize: 12.5, color: AppColors.error),
          ),
      ],
    );

    final button = ElevatedButton.icon(
      onPressed:
          canImport
              ? () async {
                if (state.canResume) {
                  cubit.resumeImport();
                  return;
                }
                final ok = await _confirm(context, state);
                if (ok == true) cubit.startImport();
              }
              : null,
      icon: Icon(
        state.canResume ? Icons.play_arrow_rounded : Icons.cloud_upload_rounded,
      ),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _soft(context),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppColors.cardAdaptive(context),
      child:
          widget.compact
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [text, const SizedBox(height: 10), button],
              )
              : Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 12),
                  button,
                ],
              ),
    );
  }

  Future<bool?> _confirm(BuildContext context, BulkImportState state) {
    final s = state.summary;
    final replace = state.stockMode == ImportStockMode.replace;
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: TextStyle(color: _muted(context))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Confirmar importación'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  line('Almacén', state.selectedWarehouse?.name ?? '—'),
                  line('Stock existente', replace ? 'Se reemplaza' : 'Se suma'),
                  line(
                    'Precios existentes',
                    state.updatePrices ? 'Se actualizan' : 'Se conservan',
                  ),
                  Divider(color: AppColors.brd(ctx)),
                  line('Productos nuevos', '${s.newProducts}'),
                  line('Variantes nuevas', '${s.newVariants}'),
                  line('Variantes existentes', '${s.updatedVariants}'),
                  line('Unidades de stock', '${s.units}'),
                  if (s.lots > 0) line('Lotes de stock', '${s.lots}'),
                  if (s.newBrands > 0) line('Marcas nuevas', '${s.newBrands}'),
                  if (s.newCategories > 0)
                    line('Categorías nuevas', '${s.newCategories}'),
                  if (s.errorRows > 0) ...[
                    Divider(color: AppColors.brd(ctx)),
                    line('Filas omitidas por error', '${s.errorRows}'),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirmar e importar'),
              ),
            ],
          ),
    );
  }
}

// ───────────────────────────── Filas (tabla y tarjeta) ─────────────────────────────

Widget _statusBadge(ImportRow row) {
  late final String text;
  late final Color color;
  if (row.hasError) {
    text = 'Error';
    color = AppColors.error;
  } else if (row.isExtraLot) {
    text = 'Lote adicional';
    color = AppColors.teal;
  } else {
    switch (row.action) {
      case ImportRowAction.createProduct:
        text = 'Producto nuevo';
        color = AppColors.success;
      case ImportRowAction.addVariant:
        text = 'Variante nueva';
        color = AppColors.info;
      case ImportRowAction.updateVariant:
        text = 'Ya existe';
        color = _violet;
    }
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: _Badge(text, color)),
      if (row.hasWarning)
        const Padding(
          padding: EdgeInsets.only(left: 5),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: AppColors.warning,
          ),
        ),
    ],
  );
}

class _DetailBlock extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;
  const _DetailBlock({required this.row, required this.mode});

  @override
  Widget build(BuildContext context) {
    if (row.issues.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in row.issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i.severity == IssueSeverity.error
                        ? Icons.cancel_outlined
                        : Icons.warning_amber_rounded,
                    size: 14,
                    color:
                        i.severity == IssueSeverity.error
                            ? AppColors.error
                            : AppColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      '${i.column}: ${i.message}',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color:
                            i.severity == IssueSeverity.error
                                ? AppColors.error
                                : (AppColors.isDark(context)
                                    ? AppColors.warning
                                    : AppColors.warningDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    final ex = row.existing;
    if (ex != null && row.stock != null) {
      final cur = ex.currentStock;
      final next = mode == ImportStockMode.add ? cur + row.stock! : row.stock!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 14, color: _muted(context)),
          const SizedBox(width: 5),
          Text(
            'Stock: $cur → $next',
            style: TextStyle(fontSize: 12.5, color: _muted(context)),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _TableRow extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;
  final double extraDetailWidth;
  const _TableRow({
    required this.row,
    required this.mode,
    required this.extraDetailWidth,
  });

  @override
  Widget build(BuildContext context) {
    final cols = _ReviewViewState._cols;
    Text t(String s, {Color? color, FontWeight? w}) => Text(
      s,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: color, fontWeight: w),
    );

    final cells = <Widget>[
      t('${row.line}', color: _muted(context)),
      _statusBadge(row),
      t(row.productName.isEmpty ? '—' : row.productName, w: FontWeight.w600),
      t(row.brand.isEmpty ? '-' : row.brand),
      t(row.variantName.isEmpty ? 'Único' : row.variantName),
      t(row.sku.isEmpty ? '-' : row.sku),
      t(_money(row.cost)),
      t(_money(row.salePrice)),
      t(_money(row.wholesalePrice)),
      t(row.stock?.toString() ?? '-'),
      t(row.effectiveUsesLots && row.lotCode.isNotEmpty ? row.lotCode : '-'),
      t(row.effectiveUsesLots && row.expiry != null ? _date(row.expiry!) : '-'),
      _DetailBlock(row: row, mode: mode),
    ];

    return Container(
      color: row.hasError ? AppColors.error.withValues(alpha: 0.05) : null,
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(
              width:
                  i == cells.length - 1
                      ? cols[i].$2 + extraDetailWidth
                      : cols[i].$2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: cells[i],
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de fila para pantallas angostas.
class _RowCard extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;
  const _RowCard({required this.row, required this.mode});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (row.brand.isNotEmpty) row.brand,
      row.variantName.isEmpty ? 'Único' : row.variantName,
      if (row.sku.isNotEmpty) row.sku,
    ].join(' · ');

    Widget kv(String k, String v) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k, style: TextStyle(fontSize: 11, color: _muted(context))),
        const SizedBox(height: 1),
        Text(
          v,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ],
    );

    final hasDetail =
        row.issues.isNotEmpty || (row.existing != null && row.stock != null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            row.hasError
                ? AppColors.error.withValues(alpha: 0.05)
                : AppColors.surf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              row.hasError
                  ? AppColors.error.withValues(alpha: 0.4)
                  : AppColors.brd(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _statusBadge(row),
                ),
              ),
              Text(
                'Fila ${row.line}',
                style: TextStyle(fontSize: 12, color: _muted(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            row.productName.isEmpty ? '—' : row.productName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12.5, color: _muted(context)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 10,
            children: [
              kv('Compra', _money(row.cost)),
              kv('Venta', _money(row.salePrice)),
              if (row.wholesalePrice != null)
                kv('Mayor', _money(row.wholesalePrice)),
              kv('Stock', row.stock?.toString() ?? '-'),
              if (row.effectiveUsesLots && row.lotCode.isNotEmpty)
                kv('Lote', row.lotCode),
              if (row.effectiveUsesLots && row.expiry != null)
                kv('Vence', _date(row.expiry!)),
            ],
          ),
          if (hasDetail) ...[
            const SizedBox(height: 10),
            _DetailBlock(row: row, mode: mode),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Paso 3: Importando / Resultado ─────────────────────────────

class _ImportingView extends StatelessWidget {
  final BulkImportState state;
  const _ImportingView({required this.state});

  @override
  Widget build(BuildContext context) {
    final primary = _primary(context);
    final pct = (state.progress * 100).round();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: AppColors.cardAdaptive(context),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: state.progress == 0 ? null : state.progress,
                        strokeWidth: 6,
                        backgroundColor: primary.withValues(alpha: 0.12),
                      ),
                    ),
                    Text(
                      '$pct%',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Importando productos y stock',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'No cierres ni salgas de esta pantalla.',
                style: TextStyle(color: _muted(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final BulkImportState state;
  final bool compact;
  const _SuccessView({required this.state, required this.compact});

  @override
  Widget build(BuildContext context) {
    final r = state.result ?? const ImportBatchResult();
    final cubit = context.read<BulkImportCubit>();
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Container(
            padding: EdgeInsets.all(compact ? 20 : 32),
            decoration: AppColors.cardAdaptive(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡Importación completada!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                if (state.selectedWarehouse != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Stock cargado en «${state.selectedWarehouse!.name}»',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted(context)),
                  ),
                ],
                const SizedBox(height: 24),
                _StatsGrid(
                  items: [
                    _StatItem(
                      Icons.inventory_2_outlined,
                      'Productos creados',
                      r.createdProducts,
                      AppColors.success,
                    ),
                    _StatItem(
                      Icons.style_outlined,
                      'Variantes creadas',
                      r.createdVariants,
                      AppColors.info,
                    ),
                    _StatItem(
                      Icons.sync_alt_rounded,
                      'Variantes actualizadas',
                      r.updatedVariants,
                      _violet,
                    ),
                    _StatItem(
                      Icons.swap_vert_rounded,
                      'Movimientos de stock',
                      r.stockMovements,
                      AppColors.amber,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: cubit.reset,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text('Importar otro archivo'),
                    ),
                    ElevatedButton.icon(
                      // Se llega aquí con context.go (sin historial), por eso
                      // pop() no hacía nada: se navega directo al catálogo.
                      onPressed: () => context.go('/products'),
                      icon: const Icon(Icons.inventory_2_outlined),
                      label: const Text('Ver productos'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
