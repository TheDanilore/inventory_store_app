import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/customer_catalog_cubit.dart';
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
      if (!mounted) return;
      final cubit = context.read<CustomerCatalogCubit>();
      if (_focusNode.hasFocus && !cubit.state.isSearchMode) {
        cubit.setSearchMode(true);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onBack(CustomerCatalogCubit cubit) {
    _focusNode.unfocus();
    cubit.setSearchMode(false);
    if (_ctrl.text.isNotEmpty || cubit.state.searchTerm.isNotEmpty) {
      _ctrl.clear();
      cubit.setSearchTerm('');
    }
  }

  void _onClear(CustomerCatalogCubit cubit) {
    _ctrl.clear();
    cubit.setSearchTerm('');
    // Optionally keep focus or unfocus
  }

  void _onSubmitted(CustomerCatalogCubit cubit, String val) {
    _focusNode.unfocus();
    cubit.saveSearchTerm(val);
    cubit.setSearchMode(false);
    cubit.setSearchTerm(val);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CustomerCatalogCubit>();
    final state = context.watch<CustomerCatalogCubit>().state;

    // Update controller if term is cleared from elsewhere
    if (state.searchTerm.isEmpty && _ctrl.text.isNotEmpty) {
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
          if (state.isSearchMode || state.searchTerm.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.primary,
                size: 22,
              ),
              onPressed: () => _onBack(cubit),
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
              onSubmitted: (val) => _onSubmitted(cubit, val),
            ),
          ),
          if (_ctrl.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                color: Colors.grey.shade400,
                size: 20,
              ),
              onPressed: () => _onClear(cubit),
            ),
        ],
      ),
    );
  }
}
