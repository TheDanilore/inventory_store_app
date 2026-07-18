import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_ingredient_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/create_ingredient_uc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form_state.dart';
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
      buildWhen: (p, c) => 
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                  onChanged: cubit.setIngredientsEnabled,
                  activeThumbColor: AppColors.primary,
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
                              border: Border.all(color: Colors.grey.shade200),
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

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
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
                                                        result['name']
                                                            as String,
                                                  ),
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
                                                      'Toca para buscar o crear...',
                                                  isDense: true,
                                                  suffixIcon: const Icon(
                                                    Icons.search_rounded,
                                                    color: AppColors.primary,
                                                  ),
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed:
                                              () => cubit.removeIngredientRow(
                                                idx,
                                              ),
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            color: Colors.red.shade400,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: concentrationCtrl,
                                            keyboardType: TextInputType.number,
                                            onChanged:
                                                (val) =>
                                                    cubit.updateIngredientRow(
                                                      idx,
                                                      row.copyWith(
                                                        concentration: val,
                                                      ),
                                                    ),
                                            decoration: InputDecoration(
                                              labelText: 'Concentración (Nro)',
                                              hintText: 'Ej: 500',
                                              isDense: true,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: unitCtrl,
                                            onChanged:
                                                (val) =>
                                                    cubit.updateIngredientRow(
                                                      idx,
                                                      row.copyWith(unit: val),
                                                    ),
                                            decoration: InputDecoration(
                                              labelText: 'Unidad de medida',
                                              hintText: 'Ej: mg',
                                              isDense: true,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            style: const TextStyle(
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
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
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Buscar Componente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _search,
              decoration: InputDecoration(
                hintText: 'Ej: Paracetamol, Clorpirifos...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_hasSearched && _results.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
                        size: 36,
                        color: Colors.orange.shade400,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No se encontró "${_searchCtrl.text}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '¿Deseas agregar este ingrediente activo a la base de datos?',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _createIngredient,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text(
                        'Sí, crear ingrediente',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
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
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  separatorBuilder:
                      (_, _) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final item = _results[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.science_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Escribe para buscar...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
