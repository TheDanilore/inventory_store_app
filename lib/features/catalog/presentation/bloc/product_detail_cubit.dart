import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_extra_data_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_admin_financial_data_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/check_wishlist_state_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/toggle_wishlist_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_current_profile_id_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/export_product_pdf_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/check_customer_purchase_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/add_product_review_usecase.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_financial_summary_entity.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail_state.dart';
import 'package:injectable/injectable.dart';

@injectable
class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductEntity? product;
  bool isAdmin = false;
  String? initialVariantId;

  final GetProductExtraDataUseCase _getExtraData;
  final GetAdminFinancialDataUseCase _getAdminData;
  final CheckWishlistStateUseCase _checkWishlist;
  final ToggleWishlistUseCase _toggleWishlist;
  final GetCurrentProfileIdUseCase _getProfileId;
  final ExportProductPdfUseCase _exportProductPdf;
  final CheckCustomerPurchaseUseCase _checkPurchase;
  final AddProductReviewUseCase _addReview;

  Future<T> _unwrap<T>(Future<Either<Failure, T>> future) async {
    final res = await future;
    return res.fold((f) => throw Exception(f.message), (r) => r);
  }

  String? _profileId;

  @factoryMethod
  ProductDetailCubit({
    required GetProductExtraDataUseCase getExtraData,
    required GetAdminFinancialDataUseCase getAdminData,
    required CheckWishlistStateUseCase checkWishlist,
    required ToggleWishlistUseCase toggleWishlist,
    required GetCurrentProfileIdUseCase getProfileId,
    required ExportProductPdfUseCase exportProductPdf,
    required CheckCustomerPurchaseUseCase checkPurchase,
    required AddProductReviewUseCase addReview,
  }) : _getExtraData = getExtraData,
       _getAdminData = getAdminData,
       _checkWishlist = checkWishlist,
       _toggleWishlist = toggleWishlist,
       _getProfileId = getProfileId,
       _exportProductPdf = exportProductPdf,
       _checkPurchase = checkPurchase,
       _addReview = addReview,
       super(const ProductDetailState());

  void loadInitialData({
    required ProductEntity product,
    bool isAdmin = false,
    String? initialVariantId,
  }) {
    this.product = product;
    this.isAdmin = isAdmin;
    this.initialVariantId = initialVariantId;

    emit(state.copyWith(product: product, selectedVariantId: initialVariantId));

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
      _profileId ??= await _unwrap(_getProfileId.call());
      final pid = _profileId;
      if (pid == null) {
        emit(state.copyWith(isWishlisted: false, isWishlistLoading: false));
        return;
      }
      final isWishlisted = await _unwrap(
        _checkWishlist.call(productId: product!.id, profileId: pid),
      );
      emit(
        state.copyWith(isWishlisted: isWishlisted, isWishlistLoading: false),
      );
    } catch (_) {
      emit(state.copyWith(isWishlisted: false, isWishlistLoading: false));
    }
  }

  Future<void> _fetchExtraData() async {
    try {
      final extraData = await _unwrap(_getExtraData.call(product!.id));

      final images = extraData.images;
      final variants = extraData.variants;

      double totalRating = 0;
      for (final r in extraData.reviews) {
        totalRating += (r['rating'] as num).toDouble();
      }
      final averageRating =
          extraData.reviews.isEmpty
              ? 0.0
              : totalRating / extraData.reviews.length;

      int totalSold = 0;
      double reinvestmentNeeded = 0.0;
      double totalRevenue = 0.0;
      double inventoryValue = 0.0;
      List<VariantFinancialSummaryEntity> variantSummaries = [];

      if (isAdmin) {
        final adminData = await _unwrap(_getAdminData.call(product!.id));

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
          final cost =
              ((v.unitCost ?? 0) > 0) ? v.unitCost! : (product!.unitCost);
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
              VariantFinancialSummaryEntity(
                variant: v,
                unitCost: cost,
                stockQuantity: variantStock,
                inventoryValue: vInv,
                soldQuantity: s['qty']!.round(),
                soldCost: s['cost']!,
                soldRevenue: s['revenue']!,
              ),
            );
          }
        }

        variantSummaries.sort(
          (a, b) => b.soldQuantity.compareTo(a.soldQuantity),
        );
      }

      emit(
        state.copyWith(
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
        ),
      );
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
      final success = await _unwrap(
        _toggleWishlist.call(
          productId: product!.id,
          profileId: pid,
          currentStatus: currentStatus,
        ),
      );
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
    final Map<String, String> currentSelection = Map.from(
      state.selectedAttributes,
    );
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
          (av) =>
              av.attributeName == selectedAttr.key &&
              av.value == selectedAttr.value,
        );
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

    emit(
      state.copyWith(
        selectedAttributes: currentSelection,
        selectedVariantId: newMatchedVariantId ?? state.selectedVariantId,
      ),
    );

    if (newMatchedVariantId != null) {
      selectVariantImage(newMatchedVariantId);
    }
  }

  Future<void> exportProductPdf() async {
    if (product == null) return;

    emit(state.copyWith(viewState: ViewState.loading));
    final stockMap = <String, int>{};
    for (final row in state.warehouseStocks) {
      final variantId = row['variant_id'] as String?;
      final stock = (row['available_quantity'] as num?)?.toInt() ?? 0;
      if (variantId != null) {
        stockMap.update(
          variantId,
          (current) => current + stock,
          ifAbsent: () => stock,
        );
      }
    }

    final result = await _exportProductPdf(
      product: product!,
      variants: state.variants,
      stockByVariant: stockMap,
    );

    result.fold(
      (failure) {
        // Handle failure if needed, maybe emit an error state
        emit(state.copyWith(viewState: ViewState.success));
      },
      (_) {
        emit(state.copyWith(viewState: ViewState.success));
      },
    );
  }

  // REVIEW LOGIC
  Future<void> addReview({
    required String userName,
    required int rating,
    String? comment,
    required bool isAdminSubmission,
  }) async {
    if (product == null) return;
    
    emit(state.copyWith(viewState: ViewState.loading));
    try {
      if (isAdminSubmission) {
        if (userName.trim().isEmpty) {
          emit(state.copyWith(
            viewState: ViewState.error,
            errorMessage: 'Ingresa el nombre del cliente.',
          ));
          return;
        }
        await _unwrap(_addReview.call(
          productId: product!.id,
          profileId: _profileId ?? '',
          userName: userName.trim(),
          rating: rating,
          comment: comment?.trim().isNotEmpty == true ? comment!.trim() : null,
        ));
      } else {
        final pid = _profileId ?? await _unwrap(_getProfileId.call());
        _profileId = pid;
        if (pid == null) {
          emit(state.copyWith(
            viewState: ViewState.error,
            errorMessage: 'Inicia sesión para opinar.',
          ));
          return;
        }

        final hasPurchased = await _unwrap(
          _checkPurchase.call(productId: product!.id, profileId: pid),
        );
        if (!hasPurchased) {
          emit(state.copyWith(
            viewState: ViewState.error,
            errorMessage: 'Debes haber comprado este producto para opinar.',
          ));
          return;
        }

        await _unwrap(_addReview.call(
          productId: product!.id,
          profileId: pid,
          userName: userName,
          rating: rating,
          comment: comment?.trim().isNotEmpty == true ? comment!.trim() : null,
        ));
      }

      emit(state.copyWith(
        viewState: ViewState.success,
        successMessage: 'Reseña enviada, ¡gracias!',
      ));
      
      await loadData();
    } catch (e) {
      emit(state.copyWith(
        viewState: ViewState.error,
        errorMessage: 'Error al enviar reseña: $e',
      ));
    }
  }
  Future<bool> canReview() async {
    if (isAdmin) return true;
    try {
      final pid = _profileId ?? await _unwrap(_getProfileId.call());
      if (pid == null) return false;
      return await _unwrap(
        _checkPurchase.call(productId: product!.id, profileId: pid),
      );
    } catch (e) {
      return false;
    }
  }

  bool validateCartAddition(int qty) {
    final stock = state.effectiveStock;
    if (stock <= 0) {
      emit(state.copyWith(
        viewState: ViewState.error,
        errorMessage: 'Sin stock.',
      ));
      return false;
    }
    if (qty > stock) {
      emit(state.copyWith(
        viewState: ViewState.error,
        errorMessage: 'Cantidad mayor al stock.',
      ));
      return false;
    }
    return true;
  }

  void clearMessages() {
    emit(state.copyWith(clearMessages: true));
  }
}
