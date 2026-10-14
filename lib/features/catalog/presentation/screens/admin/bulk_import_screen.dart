import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/bulk_import_models.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/bulk_import/bulk_import_state.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

final Color _warnColor = Colors.orange.shade700;

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
              title: 'Importación Masiva (CSV)',
              showBackButton: true,
              onBack: importing ? warnBusy : null,
              body: Container(
                color: AppColors.background,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      children: [
                        _StepHeader(status: state.status),
                        const SizedBox(height: 24),
                        Expanded(child: _content(state)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _content(BulkImportState state) {
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
        return _ConfigView(state: state);
      case BulkImportStatus.review:
        return _ReviewView(state: state);
      case BulkImportStatus.importing:
        return _ImportingView(state: state);
      case BulkImportStatus.success:
        return _SuccessView(state: state);
    }
  }
}

// ───────────────────────────── Piezas comunes ─────────────────────────────

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
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    ),
  );
}

class _StepHeader extends StatelessWidget {
  final BulkImportStatus status;
  const _StepHeader({required this.status});

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
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _dot(i, labels[i], done),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color:
                    i < _current || done ? AppColors.primary : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }

  Widget _dot(int i, String label, bool allDone) {
    final reached = i <= _current;
    final completed = i < _current || (allDone && i == 2);
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: reached ? AppColors.primary : AppColors.border,
          child:
              completed
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: reached ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: reached ? FontWeight.w600 : FontWeight.normal,
            color: reached ? null : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

// ───────────────────────────── Paso 1: Configuración ─────────────────────────────

class _ConfigView extends StatelessWidget {
  final BulkImportState state;
  const _ConfigView({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<BulkImportCubit>();
    final left = Column(
      children: [
        _warehouseCard(cubit),
        const SizedBox(height: 16),
        _modeCard(cubit),
      ],
    );
    final right = Column(
      children: [
        _dropZone(cubit),
        const SizedBox(height: 16),
        const _ColumnsGuide(),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 900;
        return SingleChildScrollView(
          child:
              wide
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: left),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: right),
                    ],
                  )
                  : Column(children: [left, const SizedBox(height: 16), right]),
        );
      },
    );
  }

  Widget _warehouseCard(BulkImportCubit cubit) {
    final ws = state.warehouses;
    Widget body;
    if (ws.isEmpty) {
      body = _note(
        Icons.warning_amber_rounded,
        _warnColor,
        'No hay almacenes creados. Puedes importar el catálogo, pero las filas con stock serán rechazadas hasta que crees un almacén.',
      );
    } else if (ws.length == 1) {
      body = _note(
        Icons.check_circle_rounded,
        AppColors.success,
        'El stock se cargará en el almacén «${ws.first.name}».',
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tienes varios almacenes. Elige a cuál ingresará el stock:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final w in ws)
                ChoiceChip(
                  avatar: const Icon(Icons.warehouse_outlined, size: 18),
                  label: Text(w.name),
                  selected: state.selectedWarehouseId == w.id,
                  onSelected: (_) => cubit.setWarehouseId(w.id),
                ),
            ],
          ),
          if (state.needsWarehouseChoice) ...[
            const SizedBox(height: 10),
            const Text(
              'Selecciona un almacén para continuar.',
              style: TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      );
    }
    return _Card(
      icon: Icons.warehouse_outlined,
      title: 'Almacén destino del stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          body,
          const SizedBox(height: 12),
          const Text(
            'Los productos y variantes son globales; solo la cantidad entra al almacén elegido.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _modeCard(BulkImportCubit cubit) {
    final add = state.stockMode == ImportStockMode.add;
    return _Card(
      icon: Icons.tune_rounded,
      title: 'Si el producto ya existe',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<ImportStockMode>(
            segments: const [
              ButtonSegment(
                value: ImportStockMode.add,
                icon: Icon(Icons.add_circle_outline),
                label: Text('Sumar al stock'),
              ),
              ButtonSegment(
                value: ImportStockMode.replace,
                icon: Icon(Icons.sync_alt_rounded),
                label: Text('Reemplazar stock'),
              ),
            ],
            selected: {state.stockMode},
            onSelectionChanged: (s) => cubit.setStockMode(s.first),
          ),
          const SizedBox(height: 10),
          Text(
            add
                ? 'La cantidad del CSV se registra como una ENTRADA y se suma al stock actual. Ideal para recibir mercadería. Re-importar el mismo archivo la volvería a sumar.'
                : 'El stock queda exactamente en la cantidad del CSV (se registra un AJUSTE por la diferencia). Ideal para conteos de inventario; es seguro repetir.',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Actualizar precios de productos existentes'),
            subtitle: const Text(
              'Si está apagado, solo se toca el stock; los precios actuales se conservan.',
              style: TextStyle(fontSize: 12.5),
            ),
            value: state.updatePrices,
            onChanged: cubit.setUpdatePrices,
          ),
        ],
      ),
    );
  }

  Widget _dropZone(BulkImportCubit cubit) {
    final blocked = state.needsWarehouseChoice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.upload_file_rounded,
            size: 56,
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sube tu archivo CSV',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          const Text(
            'Revisarás todo antes de que se guarde algo.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: cubit.downloadTemplate,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Descargar plantilla'),
              ),
              ElevatedButton.icon(
                onPressed: blocked ? null : cubit.pickAndParseFile,
                icon: const Icon(Icons.file_upload),
                label: const Text('Seleccionar archivo CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _note(IconData icon, Color color, String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _ColumnsGuide extends StatelessWidget {
  const _ColumnsGuide();

  static const _cols = <(String, bool, String)>[
    (
      'nombre',
      true,
      'Nombre del producto. Varias filas con el mismo nombre + marca = un solo producto con varias variantes.',
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.info_outline, color: AppColors.primary),
          title: const Text(
            'Columnas del archivo',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          subtitle: const Text(
            'Una fila = una variante (y un lote, si aplica). Acepta separador , ; o tabulación.',
            style: TextStyle(fontSize: 12.5),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          children: [
            for (final c in _cols)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        c.$1,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 10, top: 1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (c.$2
                                ? AppColors.error
                                : AppColors.textSecondary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        c.$2 ? 'Obligatoria' : 'Opcional',
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              c.$2 ? AppColors.error : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(c.$3, style: const TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Productos que ya existen: su categoría, componentes y descripción NO se modifican; solo se agregan variantes, lotes y stock.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Paso 2: Revisión ─────────────────────────────

enum _Filter { all, created, existing, warnings, errors }

class _ReviewView extends StatefulWidget {
  final BulkImportState state;
  const _ReviewView({required this.state});

  @override
  State<_ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends State<_ReviewView> {
  _Filter _filter = _Filter.all;
  static const int _maxShown = 300;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cubit = context.read<BulkImportCubit>();

    if (state.fileErrors.isNotEmpty) return _fileErrors(state, cubit);

    final s = state.summary;
    final rows = _filtered(state.rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(state, cubit),
        if (state.importError != null) ...[
          const SizedBox(height: 12),
          _banner(state.importError!, AppColors.error, Icons.error_outline),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Stat('Productos nuevos', s.newProducts, AppColors.success),
            _Stat('Variantes nuevas', s.newVariants, Colors.blue),
            _Stat('Variantes existentes', s.updatedVariants, Colors.deepPurple),
            _Stat('Unidades de stock', s.units, AppColors.primary),
            if (s.newBrands > 0)
              _Stat('Marcas a crear', s.newBrands, Colors.teal),
            if (s.newCategories > 0)
              _Stat('Categorías a crear', s.newCategories, Colors.teal),
          ],
        ),
        const SizedBox(height: 16),
        _filters(state),
        const SizedBox(height: 12),
        Expanded(child: _table(rows)),
        const SizedBox(height: 12),
        _actionBar(state, cubit),
      ],
    );
  }

  List<ImportRow> _filtered(List<ImportRow> all) {
    switch (_filter) {
      case _Filter.all:
        return all;
      case _Filter.created:
        return all
            .where(
              (r) => !r.hasError && r.action != ImportRowAction.updateVariant,
            )
            .toList();
      case _Filter.existing:
        return all
            .where(
              (r) => !r.hasError && r.action == ImportRowAction.updateVariant,
            )
            .toList();
      case _Filter.warnings:
        return all.where((r) => r.hasWarning).toList();
      case _Filter.errors:
        return all.where((r) => r.hasError).toList();
    }
  }

  Widget _fileErrors(BulkImportState state, BulkImportCubit cubit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _banner(
          'No se puede procesar el archivo "${state.fileName ?? ''}"',
          AppColors.error,
          Icons.error_outline,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final e in state.fileErrors)
                ListTile(
                  leading: const Icon(Icons.close, color: AppColors.error),
                  title: Text(e),
                ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: cubit.reset,
          icon: const Icon(Icons.arrow_back),
          label: const Text('Elegir otro archivo'),
        ),
      ],
    );
  }

  Widget _header(BulkImportState state, BulkImportCubit cubit) {
    final wh = state.selectedWarehouse?.name ?? 'Sin almacén';
    final mode =
        state.stockMode == ImportStockMode.add
            ? 'Sumar al stock'
            : 'Reemplazar stock';
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.description_outlined, color: AppColors.primary),
        Text(
          state.fileName ?? 'archivo.csv',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        _chip(Icons.warehouse_outlined, wh),
        _chip(Icons.sync_alt_rounded, mode),
        _chip(
          Icons.sell_outlined,
          state.updatePrices ? 'Actualiza precios' : 'Conserva precios',
        ),
        TextButton.icon(
          onPressed: cubit.reset,
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('Cambiar archivo o configuración'),
        ),
        if (state.rows.any((r) => r.issues.isNotEmpty))
          TextButton.icon(
            onPressed: cubit.downloadIssuesReport,
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Descargar reporte'),
          ),
      ],
    );
  }

  Widget _chip(IconData i, String t) => Chip(
    avatar: Icon(i, size: 16),
    label: Text(t, style: const TextStyle(fontSize: 12.5)),
    visualDensity: VisualDensity.compact,
    backgroundColor: AppColors.surface,
    side: const BorderSide(color: AppColors.border),
  );

  Widget _banner(String msg, Color color, IconData icon) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: TextStyle(color: color))),
      ],
    ),
  );

  Widget _filters(BulkImportState state) {
    final s = state.summary;
    final created =
        state.rows
            .where(
              (r) => !r.hasError && r.action != ImportRowAction.updateVariant,
            )
            .length;
    final existing =
        state.rows
            .where(
              (r) => !r.hasError && r.action == ImportRowAction.updateVariant,
            )
            .length;
    final items = <(_Filter, String)>[
      (_Filter.all, 'Todas (${s.totalRows})'),
      (_Filter.created, 'Se crean ($created)'),
      (_Filter.existing, 'Ya existen ($existing)'),
      (_Filter.warnings, 'Advertencias (${s.warningRows})'),
      (_Filter.errors, 'Con errores (${s.errorRows})'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          ChoiceChip(
            label: Text(it.$2),
            selected: _filter == it.$1,
            onSelected: (_) => setState(() => _filter = it.$1),
          ),
      ],
    );
  }

  // Columnas: (título, ancho)
  static const _cols = <(String, double)>[
    ('Fila', 52),
    ('Estado', 130),
    ('Producto', 220),
    ('Marca', 130),
    ('Variante', 110),
    ('Compra', 72),
    ('Venta', 72),
    ('Mayor', 72),
    ('Stock', 64),
    ('Lote', 100),
    ('Vence', 96),
    ('Detalle', 360),
  ];
  static final double _totalWidth = _cols.fold(0.0, (a, c) => a + c.$2);

  Widget _table(List<ImportRow> rows) {
    final shown = rows.take(_maxShown).toList();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child:
          rows.isEmpty
              ? const Center(
                child: Text(
                  'No hay filas en este filtro.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _totalWidth,
                  child: Column(
                    children: [
                      Container(
                        color: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            for (final c in _cols)
                              SizedBox(
                                width: c.$2,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    c.$1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          itemCount:
                              shown.length + (rows.length > _maxShown ? 1 : 0),
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            if (i >= shown.length) {
                              return Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text(
                                  'Mostrando $_maxShown de ${rows.length} filas. Todas se procesan; usa los filtros o el reporte para revisar el resto.',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                              );
                            }
                            return _RowTile(
                              row: shown[i],
                              mode: widget.state.stockMode,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _actionBar(BulkImportState state, BulkImportCubit cubit) {
    final s = state.summary;
    final canImport = s.validRows > 0;
    final label =
        state.canResume
            ? 'Reanudar importación'
            : 'Importar ${s.validRows} ${s.validRows == 1 ? 'fila' : 'filas'}';
    return Row(
      children: [
        Expanded(
          child: Text(
            s.errorRows > 0
                ? '${s.errorRows} fila(s) con error se omitirán. Corrige el CSV y vuelve a subirlo si quieres incluirlas.'
                : (s.warningRows > 0
                    ? '${s.warningRows} fila(s) con advertencias; se importarán igualmente.'
                    : 'Todo en orden.'),
            style: TextStyle(
              color:
                  s.errorRows > 0 ? AppColors.error : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
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
          icon: const Icon(Icons.cloud_upload_rounded),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
        ),
      ],
    );
  }

  Future<bool?> _confirm(BuildContext context, BulkImportState state) {
    final s = state.summary;
    final replace = state.stockMode == ImportStockMode.replace;
    Widget line(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: AppColors.textSecondary)),
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
                  const Divider(),
                  line('Productos nuevos', '${s.newProducts}'),
                  line('Variantes nuevas', '${s.newVariants}'),
                  line('Variantes existentes', '${s.updatedVariants}'),
                  line('Unidades de stock', '${s.units}'),
                  if (s.newBrands > 0) line('Marcas nuevas', '${s.newBrands}'),
                  if (s.newCategories > 0)
                    line('Categorías nuevas', '${s.newCategories}'),
                  if (s.errorRows > 0) ...[
                    const Divider(),
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

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    width: 170,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

class _RowTile extends StatelessWidget {
  final ImportRow row;
  final ImportStockMode mode;
  const _RowTile({required this.row, required this.mode});

  @override
  Widget build(BuildContext context) {
    final cols = _ReviewViewState._cols;
    Widget cell(int i, Widget child) => SizedBox(
      width: cols[i].$2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: child,
      ),
    );
    Text t(String s, {Color? color}) => Text(
      s,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 13, color: color),
    );
    String money(double? v) => v == null ? '-' : v.toStringAsFixed(2);

    return Container(
      color: row.hasError ? AppColors.error.withValues(alpha: 0.04) : null,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cell(0, t('${row.line}', color: AppColors.textSecondary)),
          cell(1, _badge()),
          cell(2, t(row.productName.isEmpty ? '—' : row.productName)),
          cell(3, t(row.brand.isEmpty ? '-' : row.brand)),
          cell(4, t(row.variantName.isEmpty ? 'Único' : row.variantName)),
          cell(5, t(money(row.cost))),
          cell(6, t(money(row.salePrice))),
          cell(7, t(money(row.wholesalePrice))),
          cell(8, t(row.stock?.toString() ?? '-')),
          cell(
            9,
            t(
              row.effectiveUsesLots && row.lotCode.isNotEmpty
                  ? row.lotCode
                  : '-',
            ),
          ),
          cell(
            10,
            t(
              row.effectiveUsesLots && row.expiry != null
                  ? _d(row.expiry!)
                  : '-',
            ),
          ),
          cell(11, _detail()),
        ],
      ),
    );
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _badge() {
    late final String text;
    late final Color color;
    if (row.hasError) {
      text = 'Error';
      color = AppColors.error;
    } else {
      switch (row.action) {
        case ImportRowAction.createProduct:
          text = 'Producto nuevo';
          color = AppColors.success;
        case ImportRowAction.addVariant:
          text = 'Variante nueva';
          color = Colors.blue;
        case ImportRowAction.updateVariant:
          text = 'Ya existe';
          color = Colors.deepPurple;
      }
    }
    return Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
        if (row.hasWarning)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: _warnColor,
            ),
          ),
      ],
    );
  }

  Widget _detail() {
    if (row.issues.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final i in row.issues)
            Text(
              '${i.column}: ${i.message}',
              style: TextStyle(
                fontSize: 12.5,
                color:
                    i.severity == IssueSeverity.error
                        ? AppColors.error
                        : _warnColor,
              ),
            ),
        ],
      );
    }
    final ex = row.existing;
    if (ex != null && row.stock != null) {
      final cur = ex.currentStock;
      final next = mode == ImportStockMode.add ? cur + row.stock! : row.stock!;
      return Text(
        'Stock: $cur → $next',
        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      );
    }
    return const Text('');
  }
}

// ───────────────────────────── Paso 3: Importando / Resultado ─────────────────────────────

class _ImportingView extends StatelessWidget {
  final BulkImportState state;
  const _ImportingView({required this.state});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Importando productos y stock...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: state.progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 10),
          Text(
            '${(state.progress * 100).round()}%  ·  No cierres esta pantalla',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  final BulkImportState state;
  const _SuccessView({required this.state});

  @override
  Widget build(BuildContext context) {
    final r = state.result ?? const ImportBatchResult();
    final cubit = context.read<BulkImportCubit>();
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 72,
              color: AppColors.success,
            ),
            const SizedBox(height: 12),
            const Text(
              '¡Importación completada!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (state.selectedWarehouse != null) ...[
              const SizedBox(height: 4),
              Text(
                'Stock cargado en «${state.selectedWarehouse!.name}»',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _Stat(
                  'Productos creados',
                  r.createdProducts,
                  AppColors.success,
                ),
                _Stat('Variantes creadas', r.createdVariants, Colors.blue),
                _Stat(
                  'Variantes actualizadas',
                  r.updatedVariants,
                  Colors.deepPurple,
                ),
                _Stat(
                  'Movimientos de stock',
                  r.stockMovements,
                  AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: cubit.reset,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar otro archivo'),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Ver productos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
