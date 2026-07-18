import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

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

  void _search(String term) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _isLoading = true);
      try {
        final isAttrMode = widget.mode == AttributeSearchMode.attribute;
        final tableName = isAttrMode ? 'attributes' : 'attribute_values';
        final fieldName = isAttrMode ? 'name' : 'value';

        dynamic query = Supabase.instance.client
            .from(tableName)
            .select('id, $fieldName');

        if (term.trim().isNotEmpty) {
          query = query.ilike(fieldName, '%${term.trim()}%');
        }

        if (!isAttrMode && widget.parentAttributeId != null) {
          query = query.eq('attribute_id', widget.parentAttributeId!);
        }

        final res = await query.order(fieldName).limit(15);

        if (mounted) {
          setState(() {
            _results = List<Map<String, dynamic>>.from(res);
            _hasSearched = term.trim().isNotEmpty;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _createNew() async {
    final term = _searchCtrl.text.trim();
    if (term.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      if (widget.mode == AttributeSearchMode.attribute) {
        // Buscar exacto primero
        final exist =
            await Supabase.instance.client
                .from('attributes')
                .select('id, name')
                .ilike('name', term)
                .maybeSingle();

        if (exist != null) {
          if (mounted) Navigator.pop(context, exist);
          return;
        }

        final res =
            await Supabase.instance.client
                .from('attributes')
                .insert({'name': term})
                .select('id, name')
                .single();

        if (mounted) Navigator.pop(context, res);
      } else {
        // Modo Valor
        if (widget.parentAttributeId == null) {
          throw Exception('No se puede crear un valor sin un atributo padre.');
        }

        final exist =
            await Supabase.instance.client
                .from('attribute_values')
                .select('id, value')
                .eq('attribute_id', widget.parentAttributeId!)
                .ilike('value', term)
                .maybeSingle();

        if (exist != null) {
          if (mounted) Navigator.pop(context, exist);
          return;
        }

        final res =
            await Supabase.instance.client
                .from('attribute_values')
                .insert({
                  'attribute_id': widget.parentAttributeId!,
                  'value': term,
                })
                .select('id, value')
                .single();

        if (mounted) Navigator.pop(context, res);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al crear: $e',
          backgroundColor: Colors.red,
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
