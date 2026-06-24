import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/models/product_financial_summary.dart';
import 'package:inventory_store_app/services/shared/product_detail_service.dart';

class ProductDetailProvider extends ChangeNotifier {
  final ProductDetailService _service = ProductDetailService();

  final ProductModel product;
  final bool isAdmin;
  final String? initialVariantId;

  bool isLoadingExtra = true;
  bool isWishlistLoading = true;
  bool isWishlisted = false;
  bool showVariantImage = false;

  // Profile id cacheado — se obtiene una sola vez para evitar round-trips repetidos
  String? _profileId;

  int selectedQty = 1;
  int selectedImageIndex = 0;
  String? selectedVariantId;
  final Map<String, String> selectedAttributes = {};

  List<Map<String, dynamic>> warehouseStocks = [];
  List<Map<String, dynamic>> batchesList = [];
  List<ProductImageModel> images = [];
  List<ProductVariantModel> variants = [];
  List<Map<String, dynamic>> reviewsList = [];
  List<Map<String, dynamic>> activeIngredients = [];

  // Decisiones Rápidas (Admin)
  int totalSold = 0;
  double reinvestmentNeeded = 0.0;
  double inventoryValue = 0.0;
  double totalRevenue = 0.0;
  List<VariantFinancialSummary> variantSummaries = [];

  double averageRating = 0.0;

  ProductDetailProvider({
    required this.product, 
    required this.isAdmin,
    this.initialVariantId,
  }) {
    if (initialVariantId != null) {
      selectedVariantId = initialVariantId;
    }
    _initData();
  }

  Future<void> _initData() async {
    await loadData();
  }

  Future<void> loadData() async {
    isLoadingExtra = true;
    notifyListeners();
    await Future.wait([_fetchWishlistState(), _fetchExtraData()]);
  }

  Future<void> _fetchWishlistState() async {
    if (isAdmin) {
      isWishlistLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Obtener el profileId una sola vez y cachearlo
      _profileId ??= await _service.fetchCurrentProfileId();
      final pid = _profileId;
      if (pid == null) {
        isWishlisted = false;
        return;
      }
      isWishlisted = await _service.checkWishlistState(product.id, pid);
    } catch (_) {
      isWishlisted = false;
    } finally {
      isWishlistLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchExtraData() async {
    try {
      final extraData = await _service.fetchProductExtraData(product.id);

      warehouseStocks = extraData.stocks;
      batchesList = extraData.batches;
      images = extraData.images;
      variants = extraData.variants;
      reviewsList = extraData.reviews;
      activeIngredients = extraData.ingredients;

      double totalRating = 0;
      for (final r in reviewsList) {
        totalRating += (r['rating'] as num).toDouble();
      }
      averageRating =
          reviewsList.isEmpty ? 0.0 : totalRating / reviewsList.length;

      if (isAdmin) {
        final adminData = await _service.fetchAdminFinancialData(product.id);
        int soldUnits = 0;
        double reinvestment = 0.0;
        double revenue = 0.0;

        final Map<String, Map<String, double>> variantSales = {};
        for (final row in adminData) {
          final q = (row['quantity'] as num?)?.toInt() ?? 0;
          final uc = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
          final ap = (row['applied_price'] as num?)?.toDouble() ?? 0.0;

          soldUnits += q;
          reinvestment += (q * uc);
          revenue += (q * ap);

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

        totalSold = soldUnits;
        reinvestmentNeeded = reinvestment;
        totalRevenue = revenue;

        double invValue = 0.0;
        final summaries = <VariantFinancialSummary>[];
        for (final v in variants) {
          final cost = ((v.unitCost ?? 0) > 0) ? v.unitCost! : product.unitCost;
          int variantStock = 0;
          for (final row in warehouseStocks) {
            if (row['variant_id'] == v.id) {
              variantStock += (row['available_quantity'] as num?)?.toInt() ?? 0;
            }
          }
          final vInv = variantStock * cost;
          invValue += vInv;

          final sales = variantSales[v.id];
          summaries.add(
            VariantFinancialSummary(
              variant: v,
              unitCost: cost,
              stockQuantity: variantStock,
              inventoryValue: vInv,
              soldQuantity: sales?['qty']?.toInt() ?? 0,
              soldCost: sales?['cost'] ?? 0.0,
              soldRevenue: sales?['revenue'] ?? 0.0,
            ),
          );
        }
        inventoryValue = invValue;
        variantSummaries = summaries;
      }

      if (variants.isNotEmpty) {
        ProductVariantModel? toSelect;
        
        if (selectedVariantId != null) {
          try {
            toSelect = variants.firstWhere((v) => v.id == selectedVariantId);
          } catch (_) {}
        }

        if (toSelect == null) {
          ProductVariantModel? firstWithStock;
          for (final v in variants) {
            int stock = 0;
            for (final row in warehouseStocks) {
              if (row['variant_id'] == v.id) {
                stock += ((row['available_quantity'] as num?)?.toInt() ?? 0);
              }
            }
            if (stock > 0) {
              firstWithStock = v;
              break;
            }
          }
          toSelect = firstWithStock ?? variants.first;
        }

        selectedVariantId = toSelect.id;
        selectedAttributes.clear();
        toSelect.attributeMap.forEach((k, val) {
          selectedAttributes[k] = val;
        });
      }
    } catch (e) {
      debugPrint('Error loading extra: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        debugPrint('Sin conexión a internet.');
      } else {
        debugPrint('No se pudieron cargar los datos extra.');
      }
    } finally {
      isLoadingExtra = false;
      notifyListeners();
    }
  }

  Future<void> toggleWishlist() async {
    if (isAdmin) return;
    final pid = _profileId;
    if (pid == null) throw Exception('Inicia sesión para usar favoritos.');

    final previousState = isWishlisted;

    // Optimistic UI update
    isWishlisted = !isWishlisted;
    notifyListeners();

    try {
      final success = await _service.toggleWishlist(
        product.id,
        pid,
        previousState,
      );
      if (success != isWishlisted) {
        isWishlisted = success;
        notifyListeners();
      }
    } catch (e) {
      // Revert on error
      isWishlisted = previousState;
      notifyListeners();
      rethrow;
    }
  }

  void selectVariant(ProductVariantModel v) {
    selectedVariantId = v.id;
    selectedAttributes.clear();
    v.attributeMap.forEach((k, val) {
      selectedAttributes[k] = val;
    });
    showVariantImage = true;
    selectedQty = 1;
    notifyListeners();
  }

  void selectAttribute(String key, String value) {
    selectedAttributes[key] = value;
    final matchedVariant = variants.cast<ProductVariantModel?>().firstWhere((
      v,
    ) {
      if (v == null) return false;
      bool matches = true;
      selectedAttributes.forEach((k, val) {
        if (v.attributeMap[k] != val) matches = false;
      });
      return matches;
    }, orElse: () => null);

    if (matchedVariant != null) {
      selectedVariantId = matchedVariant.id;
    } else {
      selectedVariantId = null;
    }

    showVariantImage = true;
    selectedQty = 1;
    notifyListeners();
  }

  void setShowVariantImage(bool show) {
    showVariantImage = show;
    notifyListeners();
  }

  void setSelectedQty(int qty) {
    selectedQty = qty;
    notifyListeners();
  }

  void setPage(int index) {
    selectedImageIndex = index;
    notifyListeners();
  }

  // ─── DERIVED GETTERS ─────────────────────────────────────────────────────

  ProductVariantModel? get selectedVariant {
    if (selectedVariantId != null &&
        variants.any((v) => v.id == selectedVariantId)) {
      return variants.firstWhere((v) => v.id == selectedVariantId);
    }
    return null;
  }

  double get baseSalePrice {
    final vSale = selectedVariant?.salePrice;
    if (vSale != null && vSale > 0) return vSale;
    return product.salePrice;
  }

  double? get baseWholesalePrice {
    final vWholesale = selectedVariant?.wholesalePrice;
    if (vWholesale != null && vWholesale > 0) return vWholesale;
    return product.wholesalePrice;
  }
  int get baseWholesaleMinQty =>
      selectedVariant?.wholesaleMinQuantity ?? product.wholesaleMinQuantity;

  double get effectivePrice {
    if (baseWholesalePrice != null && selectedQty >= baseWholesaleMinQty) {
      return baseWholesalePrice!;
    }
    return baseSalePrice;
  }

  bool get isActive {
    if (!product.isActive) return false;
    final v = selectedVariant;
    if (v != null && !v.isActive) return false;
    return true;
  }

  int get effectiveStock {
    if (!product.stockControl) return 999;
    final v = selectedVariant;
    if (v == null) return 0;
    int s = 0;
    for (final row in warehouseStocks) {
      if (row['variant_id'] == v.id) {
        s += (row['available_quantity'] as num?)?.toInt() ?? 0;
      }
    }
    return s;
  }

  bool get canBuy => isActive && effectiveStock > 0 && selectedVariant != null;

  String? variantImageUrl(ProductVariantModel v) {
    if (v.images.isNotEmpty) {
      return v.images.first.imageUrl;
    }
    final match = images.firstWhere(
      (img) => img.variantId == v.id,
      orElse:
          () => ProductImageModel(
            id: '',
            productId: '',
            imageUrl: '',
            displayOrder: 0,
          ),
    );
    if (match.id.isNotEmpty) return match.imageUrl;
    return null;
  }

  String? get selectedVariantImageUrl {
    final v = selectedVariant;
    if (v == null) return null;
    return variantImageUrl(v);
  }

  List<String> get attributeKeys {
    final Set<String> keys = {};
    for (final v in variants) {
      keys.addAll(v.attributeMap.keys);
    }
    final list = keys.toList();
    list.sort();
    return list;
  }

  Map<String, List<String>> get attributeOptions {
    final Map<String, Set<String>> map = {};
    for (final key in attributeKeys) {
      map[key] = {};
    }
    for (final v in variants) {
      v.attributeMap.forEach((k, val) {
        map[k]?.add(val);
      });
    }
    return map.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  bool isOptionEnabled(String key, String value) {
    for (final v in variants) {
      if (v.attributeMap[key] == value) {
        bool matchesOther = true;
        selectedAttributes.forEach((k, selectedVal) {
          if (k != key && v.attributeMap[k] != selectedVal) {
            matchesOther = false;
          }
        });
        if (matchesOther) return true;
      }
    }
    return false;
  }
}
