import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_by_id_usecase.dart';
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
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_detail/product_detail_state.dart';
import 'package:injectable/injectable.dart';

@injectable
class ProductDetailCubit extends Cubit<ProductDetailState> {
  ProductEntity? product;
  bool get isAdmin => true;
  set isAdmin(bool value) {}
  String? initialVariantId;

  final GetProductByIdUseCase _getProductById;
  final GetProductExtraDataUseCase _getExtraData;
  final GetAdminFinancialDataUseCase _getAdminData;
  final GetCurrentProfileIdUseCase? _getProfileId;
  final ExportProductPdfUseCase _exportProductPdf;
  final AddProductReviewUseCase _addReview;

  Future<T> _unwrap<T>(Future<Either<Failure, T>> future) async {
    final res = await future;
    return res.fold((f) => throw Exception(f.message), (r) => r);
  }

  String? _profileId;

  @factoryMethod
  ProductDetailCubit({
    required GetProductByIdUseCase getProductById,
    required GetProductExtraDataUseCase getExtraData,
    required GetAdminFinancialDataUseCase getAdminData,
    CheckWishlistStateUseCase? checkWishlist,
    ToggleWishlistUseCase? toggleWishlist,
    GetCurrentProfileIdUseCase? getProfileId,
    required ExportProductPdfUseCase exportProductPdf,
    CheckCustomerPurchaseUseCase? checkPurchase,
    required AddProductReviewUseCase addReview,
  }) : _getProductById = getProductById,
       _getExtraData = getExtraData,
       _getAdminData = getAdminData,
       _getProfileId = getProfileId,
       _exportProductPdf = exportProductPdf,
       _addReview = addReview,
       super(const ProductDetailState());

  /// Carga el producto mediante su ID y luego inicializa la data extra.
  Future<void> loadProduct(
    String productId, {
    bool? isAdmin,
    String? initialVariantId,
  }) async {
    this.initialVariantId = initialVariantId;
    emit(state.copyWith(viewState: ViewState.loading));

    final result = await _getProductById(productId);
    if (isClosed) return;

    result.fold(
      (failure) => emit(
        state.copyWith(
          viewState: ViewState.error,
          errorMessage: failure.message,
        ),
      ),
      (loadedProduct) {
        product = loadedProduct;
        final effectiveVariantId = initialVariantId ??
            (loadedProduct != null && loadedProduct.productVariants.isNotEmpty
                ? loadedProduct.productVariants.first.id
                : null);
        this.initialVariantId = effectiveVariantId;
        emit(
          state.copyWith(
            product: loadedProduct,
            selectedVariantId: effectiveVariantId,
          ),
        );
        _initData();
      },
    );
  }

  void loadInitialData({
    required ProductEntity product,
    bool? isAdmin,
    String? initialVariantId,
  }) {
    this.product = product;
    final effectiveVariantId = initialVariantId ??
        (product.productVariants.isNotEmpty
            ? product.productVariants.first.id
            : null);
    this.initialVariantId = effectiveVariantId;

    emit(
      state.copyWith(
        product: product,
        selectedVariantId: effectiveVariantId,
      ),
    );

    _initData();
  }

  Future<void> _initData() async {
    await loadData();
  }

  Future<void> loadData() async {
    if (product == null) return;
    emit(state.copyWith(viewState: ViewState.loading));
    await _fetchExtraData();
    if (isClosed) return;
    emit(state.copyWith(viewState: ViewState.success));
  }

  Future<void> _fetchExtraData() async {
    try {
      final extraData = await _unwrap(_getExtraData.call(product!.id));
      if (isClosed) return;

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
      final List<VariantFinancialSummaryEntity> variantSummaries = [];

      final adminData = await _unwrap(_getAdminData.call(product!.id));
      if (isClosed) return;

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
        final cost = (v.unitCost ?? 0) > 0 ? v.unitCost! : 0.0;
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

      final resolvedVariantId = state.selectedVariantId ??
          (variants.isNotEmpty ? variants.first.id : null);

      if (isClosed) return;
      emit(
        state.copyWith(
          selectedVariantId: resolvedVariantId,
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
    } catch (e, st) {
      LoggerService.e(
        'Error al descargar información transaccional y variantes del producto',
        error: e,
        stackTrace: st,
        tag: 'ProductDetailCubit',
      );
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
        break;
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
    if (isClosed) return;

    result.fold(
      (failure) {
        LoggerService.e(
          'Error al generar y exportar PDF del producto: ${failure.message}',
          tag: 'ProductDetailCubit',
        );
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
      },
      (_) {
        emit(state.copyWith(viewState: ViewState.success));
      },
    );
  }

  Future<void> addReview({
    required String userName,
    required int rating,
    String? comment,
    bool isAdminSubmission = true,
  }) async {
    if (product == null) return;

    if (userName.trim().isEmpty) {
      emit(
        state.copyWith(
          viewState: ViewState.error,
          errorMessage: 'Ingresa el nombre del cliente.',
        ),
      );
      return;
    }

    emit(state.copyWith(viewState: ViewState.loading));
    try {
      final pid = _profileId ??
          (_getProfileId != null
              ? (await _unwrap(_getProfileId.call()))
              : null) ??
          '';
      _profileId = pid;

      await _unwrap(
        _addReview.call(
          productId: product!.id,
          profileId: pid,
          userName: userName.trim(),
          rating: rating,
          comment:
              comment?.trim().isNotEmpty == true ? comment!.trim() : null,
        ),
      );

      if (isClosed) return;
      emit(
        state.copyWith(
          viewState: ViewState.success,
          successMessage: 'Reseña enviada con éxito',
        ),
      );

      await loadData();
    } catch (e, st) {
      LoggerService.e(
        'Error al enviar reseña de producto',
        error: e,
        stackTrace: st,
        tag: 'ProductDetailCubit',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          viewState: ViewState.error,
          errorMessage: Failure.from(e).message,
        ),
      );
    }
  }

  Future<bool> canReview() async => true;

  bool validateCartAddition(int qty) {
    final stock = state.effectiveStock;
    if (stock <= 0) {
      emit(
        state.copyWith(viewState: ViewState.error, errorMessage: 'Sin stock.'),
      );
      return false;
    }
    if (qty > stock) {
      emit(
        state.copyWith(
          viewState: ViewState.error,
          errorMessage: 'Cantidad mayor al stock.',
        ),
      );
      return false;
    }
    return true;
  }

  void clearMessages() {
    emit(state.copyWith(clearMessages: true));
  }
}
