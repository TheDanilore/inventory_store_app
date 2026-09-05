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

        final result =
            isAttrMode
                ? await repository.searchAttributes(term)
                : await repository.searchAttributeValues(
                  widget.parentAttributeId!,
                  term,
                );

        result.fold(
          (failure) {
            developer.log('Error searching attributes', error: failure.message);
            if (mounted) {
              AppSnackbar.show(
                context,
                message: 'Error de red al buscar',
                type: SnackbarType.error,
              );
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
          },
        );
      } catch (e, st) {
        developer.log(
          'Critical Error searching attributes',
          error: e,
          stackTrace: st,
        );
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Ocurrió un error inesperado',
            type: SnackbarType.error,
          );
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
              AppSnackbar.show(
                context,
                message: failure.message,
                type: SnackbarType.error,
              );
              setState(() => _isLoading = false);
            }
          },
          (data) {
            if (mounted) Navigator.pop(context, data);
          },
        );
      } else {
        if (widget.parentAttributeId == null) {
          throw Exception('No se puede crear un valor sin un atributo padre.');
        }

        final result = await repository.getOrCreateAttributeValue(
          widget.parentAttributeId!,
          term,
        );
        result.fold(
          (failure) {
            if (mounted) {
              AppSnackbar.show(
                context,
                message: failure.message,
                type: SnackbarType.error,
              );
              setState(() => _isLoading = false);
            }
          },
          (data) {
            if (mounted) Navigator.pop(context, data);
          },
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
              child: Icon(
                isAttrMode
                    ? Icons.category_rounded
                    : Icons.label_important_rounded,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
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
              _createNew();
            }
          },
          decoration: InputDecoration(
            hintText: hint,
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
                    isAttrMode ? Icons.category_outlined : Icons.label_outline,
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
                  '¿Deseas agregar esto como nuevo ${isAttrMode ? 'atributo' : 'valor'}?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _createNew,
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
                final valueText = item[fieldName] as String;
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
                            child: Icon(
                              isAttrMode
                                  ? Icons.category_rounded
                                  : Icons.label_important_rounded,
                              color: AppColors.primary,
                              size: 15,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              valueText,
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
                'Escribe para buscar o crear...',
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
