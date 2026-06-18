import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/active_ingredients_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/active_ingredients/active_ingredients_skeleton.dart';
import 'package:inventory_store_app/screens/admin/widgets/active_ingredients/active_ingredient_form_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

class ActiveIngredientsScreen extends StatefulWidget {
  const ActiveIngredientsScreen({super.key});

  @override
  State<ActiveIngredientsScreen> createState() =>
      _ActiveIngredientsScreenState();
}

class _ActiveIngredientsScreenState extends State<ActiveIngredientsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query = context.read<ActiveIngredientsProvider>().searchQuery;
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

  void _showIngredientForm([Map<String, dynamic>? ingredient]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ActiveIngredientFormSheet(ingredient: ingredient),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Componentes Químicos',
      showBackButton: true,
      body: Consumer<ActiveIngredientsProvider>(
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
                    hintText: 'Buscar componente químico...',
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
                  'Total: ${provider.totalIngredients} componentes',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // ─── LISTA ────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchIngredients(),
                  color: AppColors.primary,
                  child:
                      provider.isLoading
                          ? const ActiveIngredientsSkeleton(itemCount: 8)
                          : provider.ingredients.isEmpty
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
                                      Icons.science_outlined,
                                      size: 60,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      provider.searchQuery.isNotEmpty
                                          ? 'No se encontraron componentes'
                                          : 'No hay componentes registrados',
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
                            itemCount: provider.ingredients.length,
                            itemBuilder: (context, index) {
                              final item = provider.ingredients[index];
                              return Card(
                                elevation: 0,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    child: const Icon(
                                      Icons.science_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  title: Text(
                                    item['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle:
                                      item['description'] != null
                                          ? Text(
                                            item['description'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          )
                                          : null,
                                  trailing: PopupMenuButton(
                                    onSelected: (val) {
                                      if (val == 'edit') {
                                        _showIngredientForm(item);
                                      }
                                      if (val == 'delete') {
                                        provider.deleteIngredient(
                                          context,
                                          item['id'],
                                          item['name'],
                                        );
                                      }
                                    },
                                    itemBuilder:
                                        (context) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Editar'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text(
                                              'Eliminar',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ),

              if (provider.ingredients.isNotEmpty && provider.totalPages > 1)
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
        backgroundColor: AppColors.primary,
        onPressed: () => _showIngredientForm(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Nuevo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
