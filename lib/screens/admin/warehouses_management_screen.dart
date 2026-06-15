import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class WarehousesManagementScreen extends StatefulWidget {
  const WarehousesManagementScreen({super.key});

  @override
  State<WarehousesManagementScreen> createState() =>
      _WarehousesManagementScreenState();
}

class _WarehousesManagementScreenState
    extends State<WarehousesManagementScreen> {
  static const int _pageSize = 8;
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  List<WarehouseModel> _warehouses = [];
  bool _isLoading = true;
  int _currentPage = 0;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _fetchWarehouses();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchWarehouses() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('warehouses')
          .select()
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _warehouses =
              (response as List)
                  .map((e) => WarehouseModel.fromJson(e))
                  .toList();
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

  Future<void> _toggleStatus(WarehouseModel wh, bool isActive) async {
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
          .from('warehouses')
          .update({
            'is_active': isActive,
            if (profileId != null) 'updated_by': profileId, // <-- Ya activado
          })
          .eq('id', wh.id!);

      _fetchWarehouses();
      if (mounted) {
        AppSnackbar.show(
          context,
          message: isActive ? 'Almacén activado' : 'Almacén desactivado',
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

  void _showWarehouseForm([WarehouseModel? warehouse]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => _WarehouseFormSheet(
            warehouse: warehouse,
            onSaved: () => _fetchWarehouses(),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtrado local por búsqueda
    final filteredWarehouses =
        _warehouses.where((w) {
          final query = _searchText.toLowerCase();
          return w.name.toLowerCase().contains(query) ||
              (w.address?.toLowerCase().contains(query) ?? false);
        }).toList();

    // Paginación
    final totalPages =
        filteredWarehouses.isEmpty
            ? 1
            : (filteredWarehouses.length / _pageSize).ceil();
    final currentPage =
        _currentPage >= totalPages
            ? (totalPages - 1 < 0 ? 0 : totalPages - 1)
            : _currentPage;
    final start = currentPage * _pageSize;
    final end =
        (start + _pageSize) > filteredWarehouses.length
            ? filteredWarehouses.length
            : (start + _pageSize);
    final pageItems = filteredWarehouses.sublist(start, end);

    return AdminLayout(
      title: 'Almacenes',
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
                hintText: 'Buscar almacén por nombre o dirección...',
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
              'Total: ${filteredWarehouses.length} almacenes',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // ─── LISTA DE ALMACENES ─────────────────────────────────────────────
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
                            Icons.warehouse_outlined,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No se encontraron almacenes',
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
                        final wh = pageItems[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showWarehouseForm(wh),
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
                                      Icons.store_mall_directory_rounded,
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
                                          wh.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on_rounded,
                                              size: 12,
                                              color: Colors.grey.shade500,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                wh.address?.isNotEmpty == true
                                                    ? wh.address!
                                                    : 'Sin dirección registrada',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
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
                                              wh.isActive
                                                  ? Colors.green.shade50
                                                  : Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color:
                                                wh.isActive
                                                    ? Colors.green.shade200
                                                    : Colors.red.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          wh.isActive ? 'ACTIVO' : 'INACTIVO',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color:
                                                wh.isActive
                                                    ? Colors.green.shade700
                                                    : Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Switch(
                                        value: wh.isActive,
                                        onChanged:
                                            (val) => _toggleStatus(wh, val),
                                        activeThumbColor: AppColors.primary,
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

          if (filteredWarehouses.isNotEmpty)
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
        onPressed: () => _showWarehouseForm(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nuevo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET PARA CREAR/EDITAR ──────────────────────────────────────────

class _WarehouseFormSheet extends StatefulWidget {
  final WarehouseModel? warehouse;
  final VoidCallback onSaved;

  const _WarehouseFormSheet({this.warehouse, required this.onSaved});

  @override
  State<_WarehouseFormSheet> createState() => _WarehouseFormSheetState();
}

class _WarehouseFormSheetState extends State<_WarehouseFormSheet> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _addressCtrl;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.warehouse?.name ?? '');
    _addressCtrl = TextEditingController(text: widget.warehouse?.address ?? '');
    _isActive = widget.warehouse?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameCtrl.text.trim();
      final address = _addressCtrl.text.trim();

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

      if (widget.warehouse == null) {
        // Crear
        await _supabase.from('warehouses').insert({
          'name': name,
          'address': address.isNotEmpty ? address : null,
          'is_active': _isActive,
          if (profileId != null) 'created_by': profileId, // <-- Ya activado
        });
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Almacén creado exitosamente',
            type: SnackbarType.success,
          );
        }
      } else {
        // Editar
        await _supabase
            .from('warehouses')
            .update({
              'name': name,
              'address': address.isNotEmpty ? address : null,
              'is_active': _isActive,
              if (profileId != null) 'updated_by': profileId, // <-- Ya activado
            })
            .eq('id', widget.warehouse!.id!);
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Almacén actualizado',
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
          message: 'Error al guardar: $e',
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
    final isEditing = widget.warehouse != null;

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
              isEditing ? 'Editar Almacén' : 'Nuevo Almacén',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            const Text(
              'Nombre del almacén',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ej. Almacén Principal, Depósito Norte...',
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
              'Dirección (Opcional)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressCtrl,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ej. Av. Los Pinos 123, Distrito...',
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
                    ? 'El almacén estará disponible en el sistema'
                    : 'El almacén estará inactivo',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isActive,
              activeThumbColor: AppColors.primary,
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
                          'Guardar Almacén',
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
