import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'dart:developer' as developer;

enum AttributeSearchMode { attribute, value }

class AttributeSearchDialog extends StatefulWidget {
  final AttributeSearchMode mode;
  // CAMBIO: Ahora pedimos el ID directamente, no el nombre
  final String? parentAttributeId;
  final String? parentAttributeName; // Solo para mostrar en el título

  const AttributeSearchDialog({
    super.key,
    required this.mode,
    this.parentAttributeId,
    this.parentAttributeName,
  });

  @override
  State<AttributeSearchDialog> createState() => _AttributeSearchDialogState();
}

class _AttributeSearchDialogState extends State<AttributeSearchDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = true;
  bool _hasSearched = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(String term) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);
      try {
        final isAttrMode = widget.mode == AttributeSearchMode.attribute;
        final repository = sl<ProductsRepository>();
        
        final result = isAttrMode 
            ? await repository.searchAttributes(term)
            : await repository.searchAttributeValues(widget.parentAttributeId!, term);

        result.fold(
          (failure) {
            developer.log('Error searching attributes', error: failure.message);
            if (mounted) {
              AppSnackbar.show(context, message: 'Error de red al buscar', type: SnackbarType.error);
              setState(() => _isLoading = false);
            }
          },
          (data) {
            if (mounted) {
              setState(() {
                _results = data;
                _hasSearched = term.trim().isNotEmpty;
                _isLoading = false;
              });
            }
          }
        );
      } catch (e, st) {
        developer.log('Critical Error searching attributes', error: e, stackTrace: st);
        if (mounted) {
           AppSnackbar.show(context, message: 'Ocurrió un error inesperado', type: SnackbarType.error);
           setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _createNew() async {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final repository = sl<ProductsRepository>();
      if (widget.mode == AttributeSearchMode.attribute) {
        final result = await repository.getOrCreateAttribute(term);
        result.fold(
          (failure) {
            if (mounted) {
              AppSnackbar.show(context, message: failure.message, type: SnackbarType.error);
              setState(() => _isLoading = false);
            }
          },
          (data) {
            if (mounted) Navigator.pop(context, data);
          }
        );
      } else {
        if (widget.parentAttributeId == null) {
          throw Exception('No se puede crear un valor sin un atributo padre.');
        }

        final result = await repository.getOrCreateAttributeValue(widget.parentAttributeId!, term);
        result.fold(
          (failure) {
            if (mounted) {
              AppSnackbar.show(context, message: failure.message, type: SnackbarType.error);
              setState(() => _isLoading = false);
            }
          },
          (data) {
            if (mounted) Navigator.pop(context, data);
          }
        );
      }
    } catch (e, st) {
      developer.log('Error creating attribute', error: e, stackTrace: st);
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al crear',
          type: SnackbarType.error,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAttrMode = widget.mode == AttributeSearchMode.attribute;
    final title =
        isAttrMode
            ? 'Seleccionar Propiedad'
            : 'Valor para ${widget.parentAttributeName}';
    final hint =
        isAttrMode ? 'Ej: Color, Talla, Material...' : 'Ej: Rojo, L, Acero...';
    final fieldName = isAttrMode ? 'name' : 'value';

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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
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
                hintText: hint,
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
                    Text(
                      'No se encontró "${_searchCtrl.text}"',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _createNew,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: Text(
                        'Crear ${isAttrMode ? 'Propiedad' : 'Valor'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
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
                      (_, _) => Divider(height: 1, color: Colors.grey.shade100),
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
                        child: Icon(
                          isAttrMode
                              ? Icons.category_rounded
                              : Icons.label_important_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        item[fieldName] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
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
                    'No hay resultados.',
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
