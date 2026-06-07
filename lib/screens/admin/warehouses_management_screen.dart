import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/shared/data/peru_data.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WarehousesManagementScreen extends StatefulWidget {
  const WarehousesManagementScreen({super.key});

  @override
  State<WarehousesManagementScreen> createState() => _WarehousesManagementScreenState();
}

class _WarehousesManagementScreenState extends State<WarehousesManagementScreen> {
  static const int _pageSize = 8;

  final _supabase = Supabase.instance.client;
  List<WarehouseModel> _warehouses = [];
  bool _isLoading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchWarehouses();
  }

  Future<void> _fetchWarehouses() async {
    try {
      final response = await _supabase
          .from('warehouses')
          .select()
          .order('name', ascending: true);
      setState(() {
        _warehouses = (response as List).map((e) => WarehouseModel.fromJson(e)).toList();
        _currentPage = 0;
      });
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Error cargando almacenes: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showWarehouseDialog([WarehouseModel? warehouse]) async {
    final isEditing = warehouse != null;
    final nameController = TextEditingController(text: warehouse?.name ?? '');
    final referenceController = TextEditingController();
    bool isActive = warehouse?.isActive ?? true;
    String? selectedDepartment;
    String? selectedProvince;
    String? selectedDistrict;

    final rawAddress = (warehouse?.address ?? '').trim();
    if (rawAddress.isNotEmpty) {
      final parts = rawAddress.split(' - ');
      final locationPart = parts.first.trim();
      if (parts.length > 1) {
        referenceController.text = parts.sublist(1).join(' - ').replaceFirst('Ref: ', '').trim();
      }

      final locationPieces = locationPart.split(' / ');
      if (locationPieces.length >= 3) {
        selectedDepartment = locationPieces[0].trim();
        selectedProvince = locationPieces[1].trim();
        selectedDistrict = locationPieces[2].trim();
      }
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEditing ? 'Editar Almacén' : 'Nuevo Almacén'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDepartment,
                      decoration: const InputDecoration(
                        labelText: 'Departamento',
                        border: OutlineInputBorder(),
                      ),
                      items: PeruData.departments
                          .map(
                            (department) => DropdownMenuItem(
                              value: department,
                              child: Text(department),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setStateDialog(() {
                          selectedDepartment = value;
                          selectedProvince = null;
                          selectedDistrict = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedProvince,
                      decoration: const InputDecoration(
                        labelText: 'Provincia',
                        border: OutlineInputBorder(),
                      ),
                      items: PeruData.provincesOf(selectedDepartment)
                          .map(
                            (province) => DropdownMenuItem(
                              value: province,
                              child: Text(province),
                            ),
                          )
                          .toList(),
                      onChanged: selectedDepartment == null
                          ? null
                          : (value) {
                              setStateDialog(() {
                                selectedProvince = value;
                                selectedDistrict = null;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: selectedDistrict,
                      decoration: const InputDecoration(
                        labelText: 'Distrito',
                        border: OutlineInputBorder(),
                      ),
                      items: PeruData.districtsOf(selectedProvince)
                          .map(
                            (district) => DropdownMenuItem(
                              value: district,
                              child: Text(district),
                            ),
                          )
                          .toList(),
                      onChanged: selectedProvince == null
                          ? null
                          : (value) {
                              setStateDialog(() {
                                selectedDistrict = value;
                              });
                            },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: referenceController,
                      decoration: const InputDecoration(
                        labelText: 'Referencia opcional',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (selectedDistrict != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: PeruData.isCoveredDistrict(selectedDistrict)
                              ? Colors.green.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PeruData.isCoveredDistrict(selectedDistrict)
                                ? Colors.green.shade200
                                : Colors.red.shade200,
                          ),
                        ),
                        child: Text(
                          PeruData.isCoveredDistrict(selectedDistrict)
                              ? 'Cobertura disponible en esta zona.'
                              : 'Lo sentimos, aún no llegamos a esa zona.',
                          style: TextStyle(
                            color: PeruData.isCoveredDistrict(selectedDistrict)
                                ? Colors.green.shade800
                                : Colors.red.shade800,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Activo'),
                      value: isActive,
                      onChanged: (val) {
                        setStateDialog(() => isActive = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    if (selectedDepartment == null ||
                        selectedProvince == null ||
                        selectedDistrict == null) {
                      AppSnackbar.show(
                        context,
                        message: 'Selecciona departamento, provincia y distrito.',
                      );
                      return;
                    }

                    if (!PeruData.isCoveredDistrict(selectedDistrict)) {
                      AppSnackbar.show(
                        context,
                        message: 'Lo sentimos, aún no llegamos a esa zona.',
                      );
                      return;
                    }

                    final data = {
                      'name': nameController.text.trim(),
                      'address': [
                        '$selectedDepartment / $selectedProvince / $selectedDistrict',
                        if (referenceController.text.trim().isNotEmpty)
                          'Ref: ${referenceController.text.trim()}',
                      ].join(' - '),
                      'is_active': isActive,
                    };

                    try {
                      if (isEditing) {
                        await _supabase.from('warehouses').update(data).eq('id', warehouse.id);
                      } else {
                        await _supabase.from('warehouses').insert(data);
                      }
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      _fetchWarehouses();
                    } catch (e) {
                      if (!context.mounted) return;
                      AppSnackbar.show(context, message: 'Error guardando: $e');
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _warehouses.length;
    final totalPages = total == 0 ? 1 : (total / _pageSize).ceil();
    final currentPage = _currentPage >= totalPages ? totalPages - 1 : _currentPage;
    final start = currentPage * _pageSize;
    final end = total == 0 ? 0 : ((start + _pageSize) > total ? total : (start + _pageSize));
    final pageItems = total == 0 ? <WarehouseModel>[] : _warehouses.sublist(start, end);

    return AdminLayout(
      title: 'Gestión de Almacenes',
      showBackButton: true,
      showProfileButton: false,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Text(
                        'Mostrando ${total == 0 ? 0 : start + 1}-$end de $total',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        'Página ${total == 0 ? 0 : currentPage + 1} / $totalPages',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: pageItems.length,
                    itemBuilder: (context, index) {
                      final wh = pageItems[index];
                      return ListTile(
                        title: Text(wh.name),
                        subtitle: Text(wh.address ?? 'Sin dirección'),
                        trailing: Switch(value: wh.isActive, onChanged: null),
                        onTap: () => _showWarehouseDialog(wh),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                  child: AdminPageBlocks(
                    currentPage: currentPage,
                    totalPages: totalPages,
                    onPageChanged: (page) => setState(() => _currentPage = page),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showWarehouseDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
