import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CatalogSearchBar extends StatefulWidget {
  const CatalogSearchBar({super.key});

  @override
  State<CatalogSearchBar> createState() => _CatalogSearchBarState();
}

class _CatalogSearchBarState extends State<CatalogSearchBar> {
  final TextEditingController _ctrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      final provider = context.read<CustomerCatalogProvider>();
      if (_focusNode.hasFocus && !provider.isSearchMode) {
        provider.setSearchMode(true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onBack(CustomerCatalogProvider provider) {
    _focusNode.unfocus();
    provider.setSearchMode(false);
    if (_ctrl.text.isNotEmpty || provider.searchTerm.isNotEmpty) {
      _ctrl.clear();
      provider.setSearchTerm('');
    }
  }

  void _onClear(CustomerCatalogProvider provider) {
    _ctrl.clear();
    provider.setSearchTerm('');
    // Optionally keep focus or unfocus
  }

  void _onSubmitted(CustomerCatalogProvider provider, String val) {
    _focusNode.unfocus();
    provider.saveSearchTerm(val);
    provider.setSearchMode(false);
    provider.setSearchTerm(val);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomerCatalogProvider>();

    // Update controller if term is cleared from elsewhere
    if (provider.searchTerm.isEmpty && _ctrl.text.isNotEmpty) {
      _ctrl.text = '';
    }

    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (provider.isSearchMode || provider.searchTerm.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              onPressed: () => _onBack(provider),
            )
          else
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 10),
              child: Icon(Icons.search_rounded, color: Colors.grey, size: 20),
            ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '¿Qué estás buscando?',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              style: const TextStyle(fontSize: 14),
              onSubmitted: (val) => _onSubmitted(provider, val),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
              onPressed: () => _onClear(provider),
            ),
        ],
      ),
    );
  }
}
