import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/warehouse_model.dart';
import 'package:inventory_store_app/providers/admin/warehouses_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/warehouses/warehouses_skeleton.dart';
import 'package:inventory_store_app/screens/admin/widgets/warehouses/warehouse_form_sheet.dart';
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
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query = context.read<WarehousesProvider>().searchQuery;
      if (query.isNotEmpty) {
        _searchCtrl.text = query;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showWarehouseForm([WarehouseModel? warehouse]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WarehouseFormSheet(warehouse: warehouse),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Almacenes',
      showBackButton: true,
      body: Consumer<WarehousesProvider>(
        builder: (context, provider, child) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── BUSCADOR ───────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: provider.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar almacén por nombre o dirección...',
                    hintStyle: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: Colors.grey.shade400,
                    ),
                    suffixIcon:
                        provider.searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                _searchCtrl.clear();
                                provider.clearSearch();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Text(
                  'Total: ${provider.totalWarehouses} almacenes',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // ─── LISTA DE ALMACENES ─────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchWarehouses(),
                  color: AppColors.primary,
                  child:
                      provider.isLoading
                          ? const WarehousesSkeleton(itemCount: 5)
                          : provider.warehouses.isEmpty
                          ? ListView(
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.2,
                              ),
                              Center(
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
                                      provider.searchQuery.isNotEmpty
                                          ? 'No se encontraron almacenes'
                                          : 'No hay almacenes registrados',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                          : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: provider.warehouses.length,
                            itemBuilder: (context, index) {
                              final wh = provider.warehouses[index];
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                                      wh.address?.isNotEmpty ==
                                                              true
                                                          ? wh.address!
                                                          : 'Sin dirección registrada',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            Colors
                                                                .grey
                                                                .shade600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    wh.isActive
                                                        ? Colors.green.shade50
                                                        : Colors.red.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color:
                                                      wh.isActive
                                                          ? Colors
                                                              .green
                                                              .shade200
                                                          : Colors.red.shade200,
                                                ),
                                              ),
                                              child: Text(
                                                wh.isActive
                                                    ? 'ACTIVO'
                                                    : 'INACTIVO',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      wh.isActive
                                                          ? Colors
                                                              .green
                                                              .shade700
                                                          : Colors.red.shade700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Switch(
                                              value: wh.isActive,
                                              onChanged: (val) {
                                                provider.toggleWarehouseStatus(
                                                  context,
                                                  wh,
                                                  val,
                                                );
                                              },
                                              activeThumbColor:
                                                  AppColors.primary,
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
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
              ),

              if (provider.warehouses.isNotEmpty && provider.totalPages > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: AdminPageBlocks(
                    currentPage: provider.currentPage,
                    totalPages: provider.totalPages,
                    onPageChanged: (page) => provider.setPage(page),
                  ),
                ),
            ],
          );
        },
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
