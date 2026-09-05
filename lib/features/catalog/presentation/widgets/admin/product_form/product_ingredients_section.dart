import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_ingredient_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/create_ingredient_uc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/product_form/product_form_models.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

/// Sección de Ingredientes Activos / Componentes.
///
/// Gestiona controllers locales indexados por [IngredientRowModel.id].
/// El Cubit mantiene la colección de modelos puros; el widget mantiene los controllers.
class ProductIngredientsSection extends StatefulWidget {
  const ProductIngredientsSection({super.key});

  @override
  State<ProductIngredientsSection> createState() =>
      _ProductIngredientsSectionState();
}

class _ProductIngredientsSectionState extends State<ProductIngredientsSection> {
  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _concentrationControllers = {};
  final Map<String, TextEditingController> _unitControllers = {};

  @override
  void dispose() {
    for (final ctrl in _nameControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _concentrationControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _unitControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _syncControllers(List<IngredientRowModel> rows) {
    final ids = rows.map((r) => r.id).toSet();

    // Eliminar controllers huérfanos
    _nameControllers.keys.toList().forEach((id) {
      if (!ids.contains(id)) {
        _nameControllers.remove(id)?.dispose();
        _concentrationControllers.remove(id)?.dispose();
        _unitControllers.remove(id)?.dispose();
      }
    });

    // Crear controllers faltantes
    for (final row in rows) {
      if (!_nameControllers.containsKey(row.id)) {
        _nameControllers[row.id] = TextEditingController(text: row.name);
        _concentrationControllers[row.id] = TextEditingController(
          text: row.concentration,
        );
        _unitControllers[row.id] = TextEditingController(text: row.unit);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();

    return BlocBuilder<ProductFormCubit, ProductFormState>(
      buildWhen:
          (p, c) =>
              p.ingredientsEnabled != c.ingredientsEnabled ||
              p.ingredientRows != c.ingredientRows,
      builder: (context, state) {
        _syncControllers(state.ingredientRows);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ingredientes Activos / Componentes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      state.ingredientsEnabled
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        state.ingredientsEnabled
                            ? AppColors.primary.withValues(alpha: 0.25)
                            : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.science_rounded,
                      color:
                          state.ingredientsEnabled
                              ? AppColors.primary
                              : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gestión de componentes activos',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  state.ingredientsEnabled
                                      ? AppColors.primary
                                      : Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Permite buscar este producto por componente químico',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: state.ingredientsEnabled,
                      onChanged: (val) {
                        cubit.setIngredientsEnabled(val);
                        if (val && cubit.state.ingredientRows.isEmpty) {
                          cubit.addIngredientRow();
                        }
                      },
                      activeThumbColor: AppColors.primary,
                      activeTrackColor: AppColors.primary.withValues(alpha: 0.38),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child:
                    state.ingredientsEnabled
                        ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 14),
                            if (state.ingredientRows.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  'Sin componentes. Agrega uno con el botón.',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.ingredientRows.length,
                                separatorBuilder:
                                    (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final row = state.ingredientRows[idx];
                                  final nameCtrl = _nameControllers[row.id]!;
                                  final concentrationCtrl =
                                      _concentrationControllers[row.id]!;
                                  final unitCtrl = _unitControllers[row.id]!;
                                  final isWideScreen =
                                      MediaQuery.of(context).size.width >= 768;

                                  Widget nameField = GestureDetector(
                                    onTap: () async {
                                      final result = await showDialog<
                                        Map<String, dynamic>
                                      >(
                                        context: context,
                                        builder:
                                            (_) =>
                                                const IngredientSearchDialog(),
                                      );

                                      if (result != null) {
                                        nameCtrl.text =
                                            result['name'] as String;
                                        cubit.updateIngredientRow(
                                          idx,
                                          row.copyWith(
                                            ingredientId:
                                                result['id'] as String,
                                            name:
                                                result['name'] as String,
                                          ),
                                          syncState: true,
                                        );
                                      }
                                    },
                                    child: AbsorbPointer(
                                      child: TextField(
                                        controller: nameCtrl,
                                        decoration: InputDecoration(
                                          labelText:
                                              'Componente / Ingrediente Activo *',
                                          hintText:
                                              'Buscar o crear ingrediente...',
                                          isDense: true,
                                          suffixIcon: const Icon(
                                            Icons.search_rounded,
                                            color: AppColors.primary,
                                            size: 20,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 10,
                                              ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  );

                                  Widget concentrationField = TextField(
                                    controller: concentrationCtrl,
                                    keyboardType: TextInputType.number,
                                    onChanged:
                                        (val) => cubit.updateIngredientRow(
                                          idx,
                                          row.copyWith(concentration: val),
                                          syncState: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Concentración',
                                      hintText: 'Ej: 500',
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  );

                                  Widget unitField = TextField(
                                    controller: unitCtrl,
                                    onChanged:
                                        (val) => cubit.updateIngredientRow(
                                          idx,
                                          row.copyWith(unit: val),
                                          syncState: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Unidad',
                                      hintText: 'Ej: mg',
                                      isDense: true,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                    ),
                                    style: const TextStyle(fontSize: 13),
                                  );

                                  Widget deleteBtn = IconButton(
                                    onPressed:
                                        () => cubit.removeIngredientRow(idx),
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red.shade400,
                                      size: 20,
                                    ),
                                    tooltip: 'Eliminar componente',
                                  );

                                  return Container(
                                    key: ValueKey(row.id),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: isWideScreen
                                        ? Row(
                                            children: [
                                              Expanded(
                                                flex: 5,
                                                child: nameField,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 2,
                                                child: concentrationField,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                flex: 2,
                                                child: unitField,
                                              ),
                                              const SizedBox(width: 6),
                                              deleteBtn,
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(child: nameField),
                                                  deleteBtn,
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: concentrationField,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: unitField),
                                                ],
                                              ),
                                            ],
                                          ),
                                  );
                                },
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: cubit.addIngredientRow,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Agregar componente'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class IngredientSearchDialog extends StatefulWidget {
  const IngredientSearchDialog({super.key});

  @override
  State<IngredientSearchDialog> createState() => _IngredientSearchDialogState();
}

class _IngredientSearchDialogState extends State<IngredientSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;
  final GetIngredientsUC _getIngredientsUC = sl<GetIngredientsUC>();
  final CreateIngredientUC _createIngredientUC = sl<CreateIngredientUC>();

  void _search(String term) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (term.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _isLoading = true);
      try {
        final resEither = await _getIngredientsUC.call(
          searchQuery: term.trim(),
        );
        final res = resEither.fold(
          (l) => <Map<String, dynamic>>[],
          (r) => r.map((e) => {'id': e.id, 'name': e.name}).toList(),
        );
        if (mounted) {
          setState(() {
            _results = res;
            _hasSearched = true;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _createIngredient() async {
    final name = _searchCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final resEither = await _createIngredientUC.call(name);
      final res = resEither.fold(
        (l) => null,
        (r) => {'id': r.id, 'name': r.name},
      );
      if (mounted) Navigator.pop(context, res);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al crear ingrediente. Posiblemente ya existe.',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth >= 640;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isDesktop) ...[
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.science_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Buscar Componente Químico',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isDesktop)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  'ESC',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18,
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _searchCtrl,
          autofocus: true,
          onChanged: _search,
          onSubmitted: (_) {
            if (_results.isNotEmpty) {
              Navigator.pop(context, _results.first);
            } else if (_hasSearched) {
              _createIngredient();
            }
          },
          decoration: InputDecoration(
            hintText: 'Ej: Paracetamol, Clorpirifos, Ibuprofeno...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      _search('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 12),

        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else if (_hasSearched && _results.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.science_outlined,
                    size: 32,
                    color: Colors.orange.shade400,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No se encontró "${_searchCtrl.text}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¿Deseas registrar este componente químico en el catálogo?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _createIngredient,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    'Crear "${_searchCtrl.text.trim()}"',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (_results.isNotEmpty)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: isDesktop
                  ? (screenHeight * 0.45).clamp(240.0, 420.0)
                  : screenHeight * 0.4,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder:
                  (_, _) => Divider(height: 1, color: Colors.grey.shade100),
              itemBuilder: (context, index) {
                final item = _results[index];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.pop(context, item),
                    hoverColor: AppColors.primary.withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.science_rounded,
                              color: AppColors.primary,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item['name'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Center(
              child: Text(
                'Escribe para buscar componentes...',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ),
          ),
      ],
    );

    if (isDesktop) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        elevation: 12,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: content,
          ),
        ),
      );
    } else {
      return Dialog(
        alignment: Alignment.bottomCenter,
        insetPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 28,
          ),
          child: SafeArea(
            top: false,
            child: content,
          ),
        ),
      );
    }
  }
}
