import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class CategoriesManagementScreen extends StatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  State<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends State<CategoriesManagementScreen> {
  static const int _pageSize = 8;
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<CategoryModel> _categories = [];
  bool _isLoading = true;
  int _currentPage = 0;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _categories =
              (response as List).map((e) => CategoryModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackbar.show(
          context,
          message: 'Error al cargar: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  Future<void> _toggleStatus(CategoryModel cat, bool isActive) async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? profileId;
      if (authUserId != null) {
        final p =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        profileId = p?['id'] as String?;
      }

      await _supabase
          .from('categories')
          .update({
            'is_active': isActive,
            if (profileId != null) 'updated_by': profileId,
          })
          .eq('id', cat.id!);

      _fetchCategories();
      if (mounted) {
        AppSnackbar.show(
          context,
          message: isActive ? 'Categoría activada' : 'Categoría desactivada',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _showCategoryForm([CategoryModel? category]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _CategoryFormSheet(
            category: category,
            onSaved: () => _fetchCategories(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado local por búsqueda
    final filteredCategories =
        _categories.where((c) {
          final query = _searchText.toLowerCase();
          return c.name.toLowerCase().contains(query) ||
              (c.description?.toLowerCase().contains(query) ?? false);
        }).toList();

    // Paginación
    final totalPages =
        filteredCategories.isEmpty
            ? 1
            : (filteredCategories.length / _pageSize).ceil();
    final currentPage =
        _currentPage >= totalPages
            ? (totalPages - 1 < 0 ? 0 : totalPages - 1)
            : _currentPage;
    final start = currentPage * _pageSize;
    final end =
        (start + _pageSize) > filteredCategories.length
            ? filteredCategories.length
            : (start + _pageSize);
    final pageItems = filteredCategories.sublist(start, end);

    return AdminLayout(
      title: 'Categorías',
      showBackButton: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── BUSCADOR ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                setState(() {
                  _searchText = val;
                  _currentPage = 0; // Regresar a la pag 1 al buscar
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar categoría por nombre...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                ),
                suffixIcon:
                    _searchText.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchText = '');
                          },
                        )
                        : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'Total: ${filteredCategories.length} categorías',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // ─── LISTA DE CATEGORÍAS ────────────────────────────────────────────
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : pageItems.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron categorías',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: pageItems.length,
                      itemBuilder: (context, index) {
                        final cat = pageItems[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showCategoryForm(cat),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.style_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cat.description?.isNotEmpty == true
                                              ? cat.description!
                                              : 'Sin descripción',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              cat.isActive
                                                  ? Colors.green.shade50
                                                  : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color:
                                                cat.isActive
                                                    ? Colors.green.shade200
                                                    : Colors.red.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          cat.isActive ? 'ACTIVO' : 'INACTIVO',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                cat.isActive
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Switch(
                                        value: cat.isActive,
                                        onChanged:
                                            (val) => _toggleStatus(cat, val),
                                        activeColor: AppColors.primary,
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
          ),

          if (filteredCategories.isNotEmpty)
            if (totalPages > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: AdminPageBlocks(
                  currentPage: _currentPage,
                  totalPages: totalPages,
                  onPageChanged: (page) => setState(() => _currentPage = page),
                ),
              ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nueva',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET PARA CREAR/EDITAR ──────────────────────────────────────────

class _CategoryFormSheet extends StatefulWidget {
  final CategoryModel? category;
  final VoidCallback onSaved;

  const _CategoryFormSheet({this.category, required this.onSaved});

  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category?.name ?? '');
    _descCtrl = TextEditingController(text: widget.category?.description ?? '');
    _isActive = widget.category?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final desc = _descCtrl.text.trim();

      // Obtener el ID del usuario actual para la auditoría (created_by / updated_by)
      final authUserId = _supabase.auth.currentUser?.id;
      String? profileId;
      if (authUserId != null) {
        final p =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        profileId = p?['id'] as String?;
      }

      if (widget.category == null) {
        // Crear
        await _supabase.from('categories').insert({
          'name': name,
          'description': desc.isNotEmpty ? desc : null,
          'is_active': _isActive,
          if (profileId != null) 'created_by': profileId,
        });
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Categoría creada',
            type: SnackbarType.success,
          );
        }
      } else {
        // Editar
        await _supabase
            .from('categories')
            .update({
              'name': name,
              'description': desc.isNotEmpty ? desc : null,
              'is_active': _isActive,
              if (profileId != null) 'updated_by': profileId,
            })
            .eq('id', widget.category!.id!);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Categoría actualizada',
            type: SnackbarType.success,
          );
        }
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              e.toString().contains('categories_name_key')
                  ? 'Ya existe una categoría con ese nombre'
                  : 'Error al guardar: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.category != null;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Text(
              isEditing ? 'Editar Categoría' : 'Nueva Categoría',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            const Text(
              'Nombre de la categoría',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ej. Electrónica, Ropa...',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator:
                  (val) =>
                      val == null || val.trim().isEmpty
                          ? 'El nombre es requerido'
                          : null,
            ),

            const SizedBox(height: 16),
            const Text(
              'Descripción (Opcional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                    'Breve descripción de los productos en esta categoría...',
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text(
                'Estado',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                _isActive
                    ? 'La categoría estará visible en el sistema'
                    : 'La categoría estará oculta',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isActive,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
              onChanged: (val) => setState(() => _isActive = val),
            ),

            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'Guardar Categoría',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
