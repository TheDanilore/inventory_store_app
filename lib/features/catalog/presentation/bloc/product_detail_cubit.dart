import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/data/repositories/product_detail_service.dart';
import 'package:inventory_store_app/features/dashboard/data/models/product_financial_summary.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail_state.dart';

class ProductDetailCubit extends Cubit<ProductDetailState> {
  final ProductEntity product;
  final bool isAdmin;
  final String? initialVariantId;
  final ProductDetailService _service = ProductDetailService();

  String? _profileId;

  ProductDetailCubit({
    required this.product,
    required this.isAdmin,
    this.initialVariantId,
  }) : super(ProductDetailState(product: product, selectedVariantId: initialVariantId)) {
    _initData();
  }

  Future<void> _initData() async {
    await loadData();
  }

  Future<void> loadData() async {
    emit(state.copyWith(viewState: ViewState.loading));
    await Future.wait([_fetchWishlistState(), _fetchExtraData()]);
    emit(state.copyWith(viewState: ViewState.success));
  }

  Future<void> _fetchWishlistState() async {
    if (isAdmin) {
      emit(state.copyWith(isWishlistLoading: false));
      return;
    }

    try {
      _profileId ??= await _service.fetchCurrentProfileId();
      final pid = _profileId;
      if (pid == null) {
        emit(state.copyWith(isWishlisted: false, isWishlistLoading: false));
        return;
      }
      final isWishlisted = await _service.checkWishlistState(product.id, pid);
      emit(state.copyWith(isWishlisted: isWishlisted, isWishlistLoading: false));
    } catch (_) {
      emit(state.copyWith(isWishlisted: false, isWishlistLoading: false));
    }
  }

  Future<void> _fetchExtraData() async {
    try {
      final extraData = await _service.fetchProductExtraData(product.id);
      
      final images = extraData.images.map((m) => m.toEntity()).toList();
      final variants = extraData.variants.map((m) => m.toEntity()).toList();

      double totalRating = 0;
      for (final r in extraData.reviews) {
        totalRating += (r['rating'] as num).toDouble();
      }
      final averageRating = extraData.reviews.isEmpty ? 0.0 : totalRating / extraData.reviews.length;

      int totalSold = 0;
      double reinvestmentNeeded = 0.0;
      double totalRevenue = 0.0;
      double inventoryValue = 0.0;
      List<VariantFinancialSummary> variantSummaries = [];

      if (isAdmin) {
        final adminData = await _service.fetchAdminFinancialData(product.id);

        final Map<String, Map<String, double>> variantSales = {};
        for (final row in adminData) {
          final q = (row['quantity'] as num?)?.toInt() ?? 0;
          final uc = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
          final ap = (row['applied_price'] as num?)?.toDouble() ?? 0.0;

          totalSold += q;
          reinvestmentNeeded += (q * uc);
          totalRevenue += (q * ap);

          final vid = row['variant_id']?.toString() ?? '';
          if (vid.isNotEmpty) {
            variantSales.putIfAbsent(
              vid,
              () => {'qty': 0, 'cost': 0, 'revenue': 0},
            );
            variantSales[vid]!['qty'] = variantSales[vid]!['qty']! + q;
            variantSales[vid]!['cost'] = variantSales[vid]!['cost']! + (q * uc);
            variantSales[vid]!['revenue'] =
                variantSales[vid]!['revenue']! + (q * ap);
          }
        }

        for (final v in variants) {
          final cost = ((v.unitCost ?? 0) > 0) ? v.unitCost! : (product.unitCost);
          int variantStock = 0;
          for (final row in extraData.stocks) {
            if (row['variant_id'] == v.id) {
              variantStock += (row['available_quantity'] as num?)?.toInt() ?? 0;
            }
          }
          final vInv = variantStock * cost;
          inventoryValue += vInv;

          final s = variantSales[v.id];
          if (s != null) {
            variantSummaries.add(
              VariantFinancialSummary(
                variant: v,
                unitCost: cost,
                stockQuantity: variantStock,
                inventoryValue: vInv,
                soldQuantity: s['qty']!.toInt(),
                soldCost: s['cost']!,
                soldRevenue: s['revenue']!,
              ),
            );
          }
        }

        variantSummaries.sort((a, b) => b.soldQuantity.compareTo(a.soldQuantity));
      }

      emit(state.copyWith(
        warehouseStocks: extraData.stocks,
        batchesList: extraData.batches,
        images: images,
        variants: variants,
        reviewsList: extraData.reviews,
        activeIngredients: extraData.ingredients,
        averageRating: averageRating,
        totalSold: totalSold,
        reinvestmentNeeded: reinvestmentNeeded,
        totalRevenue: totalRevenue,
        inventoryValue: inventoryValue,
        variantSummaries: variantSummaries,
      ));
    } catch (_) {
      // Ignorar error y dejar viewState success, o manejar error
    }
  }

  Future<void> toggleWishlist() async {
    final pid = _profileId;
    if (pid == null) return;
    
    final currentStatus = state.isWishlisted;
    emit(state.copyWith(isWishlistLoading: true));
    try {
      final success = await _service.toggleWishlist(product.id, pid, currentStatus);
      if (success) {
        emit(state.copyWith(isWishlisted: !currentStatus));
      }
    } finally {
      emit(state.copyWith(isWishlistLoading: false));
    }
  }

  void incrementQty() {
    emit(state.copyWith(selectedQty: state.selectedQty + 1));
  }

  void setQty(int qty) {
    emit(state.copyWith(selectedQty: qty > 0 ? qty : 1));
  }

  void decrementQty() {
    if (state.selectedQty > 1) {
      emit(state.copyWith(selectedQty: state.selectedQty - 1));
    }
  }

  void setImageIndex(int index) {
    emit(state.copyWith(selectedImageIndex: index, showVariantImage: false));
  }

  void setVariant(String? variantId) {
    emit(state.copyWith(selectedVariantId: variantId));
  }

  void selectVariantImage(String variantId) {
    if (state.images.isEmpty) return;
    final index = state.images.indexWhere((img) => img.variantId == variantId);
    if (index != -1) {
      emit(state.copyWith(selectedImageIndex: index, showVariantImage: true));
    }
  }

  void toggleAttributeSelection(String attrName, String attrValue) {
    final Map<String, String> currentSelection = Map.from(state.selectedAttributes);
    if (currentSelection[attrName] == attrValue) {
      currentSelection.remove(attrName);
    } else {
      currentSelection[attrName] = attrValue;
    }
    
    String? newMatchedVariantId;
    for (final v in state.variants) {
      bool isMatch = true;
      for (final selectedAttr in currentSelection.entries) {
        final hasAttr = v.attributeValues.any(
            (av) => av.attributeName == selectedAttr.key && av.value == selectedAttr.value);
        if (!hasAttr) {
          isMatch = false;
          break;
        }
      }
      if (isMatch && currentSelection.isNotEmpty) {
        newMatchedVariantId = v.id;
        break; // Toma la primera variante que coincida con todos los atributos seleccionados
      }
    }
    
    emit(state.copyWith(
      selectedAttributes: currentSelection,
      selectedVariantId: newMatchedVariantId ?? state.selectedVariantId
    ));
    
    if (newMatchedVariantId != null) {
      selectVariantImage(newMatchedVariantId);
    }
  }
}
