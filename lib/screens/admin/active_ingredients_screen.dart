import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/active_ingredients_provider.dart';
import 'package:inventory_store_app/shared/widgets/admin_page_blocks.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended) {
        setState(() => _isFabExtended = false);
      } else if (_scrollController.offset <= 10 && !_isFabExtended) {
        setState(() => _isFabExtended = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final query = context.read<ActiveIngredientsProvider>().searchQuery;
      if (query.isNotEmpty) {
        _searchCtrl.text = query;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
                child: _AnimatedSearchBar(
                  controller: _searchCtrl,
                  onChanged: provider.onSearchChanged,
                  onClear: () {
                    _searchCtrl.clear();
                    provider.clearSearch();
                  },
                  hasQuery: provider.searchQuery.isNotEmpty,
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
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildListContent(provider),
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
        label: AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _isFabExtended
                              ? const Text(
          'Nuevo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        )
                              : const SizedBox.shrink(),
                        ),
      ),
    );
  }

  Widget _buildListContent(ActiveIngredientsProvider provider) {
    if (provider.isLoading) {
      return const ActiveIngredientsSkeleton(
        key: ValueKey('skeleton'),
        itemCount: 8,
      );
    }
    if (provider.ingredients.isEmpty) {
      return ListView(
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.2),
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
      );
    }
    return ListView.builder(
                                controller: _scrollController,
      key: const ValueKey('list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: provider.ingredients.length,
      itemBuilder: (context, index) {
        final item = provider.ingredients[index];
        return _IngredientCard(
          ingredient: item,
          onEdit: () => _showIngredientForm(item),
          onDelete:
              () =>
                  provider.deleteIngredient(context, item['id'], item['name']),
        );
      },
    );
  }
}

// ─── WIDGETS PRIVADOS ─────────────────────────────────────────────────────────

class _AnimatedSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasQuery;

  const _AnimatedSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasQuery,
  });

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _isFocused ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isFocused ? AppColors.primary : Colors.grey.shade200,
          width: _isFocused ? 1.5 : 1,
        ),
        boxShadow:
            _isFocused
                ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: 'Buscar componente químico...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: _isFocused ? AppColors.primary : Colors.grey.shade400,
            ),
            suffixIcon:
                widget.hasQuery
                    ? IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey),
                      onPressed: widget.onClear,
                    )
                    : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _IngredientCard extends StatefulWidget {
  final Map<String, dynamic> ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _IngredientCard({
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<_IngredientCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onHighlightChanged: (val) => setState(() => _isPressed = val),
          onTap: widget.onEdit,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.science_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ingredient['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (widget.ingredient['description'] != null)
                        Text(
                          widget.ingredient['description'],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_rounded,
                        color: Colors.blue,
                      ),
                      onPressed: widget.onEdit,
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      onPressed: widget.onDelete,
                      tooltip: 'Eliminar',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
