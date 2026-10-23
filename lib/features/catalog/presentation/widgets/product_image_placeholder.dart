import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Información visual temática de una categoría de producto.
class ProductCategoryVisualInfo {
  final String label;
  final IconData icon;
  final Color primaryColor;
  final Color bgStart;
  final Color bgEnd;

  const ProductCategoryVisualInfo({
    required this.label,
    required this.icon,
    required this.primaryColor,
    required this.bgStart,
    required this.bgEnd,
  });
}

/// Helper para clasificar productos en identidades visuales por categoría o nombre.
class ProductVisualClassifier {
  ProductVisualClassifier._();

  static ProductCategoryVisualInfo resolve({
    String? categoryName,
    required String productName,
    bool isDark = false,
  }) {
    final cat = (categoryName ?? '').trim().toUpperCase();
    final name = productName.trim().toUpperCase();

    // 1. Salud / Farmacia / Analgésicos / Antiinflamatorios / Medicamentos
    if (cat.contains('ANALG') ||
        cat.contains('INFLAM') ||
        cat.contains('FARM') ||
        cat.contains('MEDIC') ||
        cat.contains('SALUD') ||
        name.contains('PARACETAMOL') ||
        name.contains('IBUPROFENO') ||
        name.contains('AMOXICILINA') ||
        name.contains('PASTILLA') ||
        name.contains('JARABE') ||
        name.contains('TABLETA') ||
        name.contains('CAPSULA') ||
        name.contains('CÁPSULA') ||
        name.contains('ASPIRINA') ||
        name.contains('ANTIBIOT')) {
      return ProductCategoryVisualInfo(
        label: 'FARMACIA',
        icon: Icons.medication_rounded,
        primaryColor: const Color(0xFF0284C7),
        bgStart: isDark ? const Color(0xFF0C2438) : const Color(0xFFF0F9FF),
        bgEnd: isDark ? const Color(0xFF071826) : const Color(0xFFE0F2FE),
      );
    }

    // 2. Fertilizantes / Abono / Nutrición vegetal
    if (cat.contains('FERTILIZ') ||
        cat.contains('ABONO') ||
        name.contains('NITRATO') ||
        name.contains('SULFATO') ||
        name.contains('UREA') ||
        name.contains('FOSFATO') ||
        name.contains('POTASIO') ||
        name.contains('COMPOST') ||
        name.contains('FOLIAR') ||
        name.contains('SACO')) {
      return ProductCategoryVisualInfo(
        label: 'FERTILIZANTE',
        icon: Icons.eco_rounded,
        primaryColor: const Color(0xFF059669),
        bgStart: isDark ? const Color(0xFF09291D) : const Color(0xFFF0FDF4),
        bgEnd: isDark ? const Color(0xFF061E15) : const Color(0xFFDCFCE7),
      );
    }

    // 3. Agroquímicos / Insecticidas / Fungicidas / Plagas
    if (cat.contains('INSECTIC') ||
        cat.contains('PLAGA') ||
        cat.contains('AGROQ') ||
        name.contains('THIODAN') ||
        name.contains('BAMECTIN') ||
        name.contains('ACARITINA') ||
        name.contains('FUNGICIDA') ||
        name.contains('HERBICIDA') ||
        name.contains('PESTICIDA') ||
        name.contains('VENENO')) {
      return ProductCategoryVisualInfo(
        label: 'AGROQUÍMICO',
        icon: Icons.pest_control_rounded,
        primaryColor: const Color(0xFFD97706),
        bgStart: isDark ? const Color(0xFF2B1D06) : const Color(0xFFFFFBEB),
        bgEnd: isDark ? const Color(0xFF1F1404) : const Color(0xFFFEF3C7),
      );
    }

    // 4. Insumos médicos / Limpieza / Antisépticos
    if (cat.contains('INSUMO') ||
        cat.contains('LIMPIEZA') ||
        name.contains('ALCOHOL') ||
        name.contains('GASA') ||
        name.contains('ALGODON') ||
        name.contains('ALGODÓN') ||
        name.contains('JERINGA') ||
        name.contains('GUANTE') ||
        name.contains('DESINFECTANTE')) {
      return ProductCategoryVisualInfo(
        label: 'INSUMO',
        icon: Icons.sanitizer_rounded,
        primaryColor: const Color(0xFF0D9488),
        bgStart: isDark ? const Color(0xFF062826) : const Color(0xFFF0FDFA),
        bgEnd: isDark ? const Color(0xFF041C1A) : const Color(0xFFCCFBF1),
      );
    }

    // 5. Bebidas / Agua / Líquidos
    if (cat.contains('AGUA') ||
        cat.contains('BEBIDA') ||
        name.contains('AGUA') ||
        name.contains('GASEOSA') ||
        name.contains('JUGO') ||
        name.contains('BOTELLA')) {
      return ProductCategoryVisualInfo(
        label: 'BEBIDAS',
        icon: Icons.water_drop_rounded,
        primaryColor: const Color(0xFF0891B2),
        bgStart: isDark ? const Color(0xFF082732) : const Color(0xFFECFEFF),
        bgEnd: isDark ? const Color(0xFF051B23) : const Color(0xFFCFFAFE),
      );
    }

    // 6. Ropa / Textil / Moda
    if (cat.contains('ROPA') ||
        cat.contains('TEXTIL') ||
        cat.contains('MODA') ||
        name.contains('POLO') ||
        name.contains('CAMISA') ||
        name.contains('PANTALON') ||
        name.contains('PANTALÓN') ||
        name.contains('HUD') ||
        name.contains('POLERA') ||
        name.contains('CASACA')) {
      return ProductCategoryVisualInfo(
        label: 'TEXTIL',
        icon: Icons.checkroom_rounded,
        primaryColor: const Color(0xFF7C3AED),
        bgStart: isDark ? const Color(0xFF22113D) : const Color(0xFFFAF5FF),
        bgEnd: isDark ? const Color(0xFF170B2A) : const Color(0xFFEDE9FE),
      );
    }

    // 7. Calzado
    if (cat.contains('CALZADO') ||
        cat.contains('ZAPAT') ||
        name.contains('ZAPATILLA') ||
        name.contains('BOTA') ||
        name.contains('SANDALIA')) {
      return ProductCategoryVisualInfo(
        label: 'CALZADO',
        icon: Icons.snowshoeing_rounded,
        primaryColor: const Color(0xFFEA580C),
        bgStart: isDark ? const Color(0xFF2E1306) : const Color(0xFFFFF7ED),
        bgEnd: isDark ? const Color(0xFF200C03) : const Color(0xFFFFEDD5),
      );
    }

    // 8. General / Por defecto
    return ProductCategoryVisualInfo(
      label: cat.isNotEmpty ? cat : 'ARTÍCULO',
      icon: Icons.inventory_2_rounded,
      primaryColor: AppColors.primary,
      bgStart: isDark ? AppColors.darkSurfaceElevated : const Color(0xFFF8FAFC),
      bgEnd: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
    );
  }
}

/// Placeholder visual elegante, moderno y temático por categoría cuando un producto no tiene imagen.
class ProductImagePlaceholder extends StatelessWidget {
  final String productName;
  final String? categoryName;
  final double? width;
  final double? height;
  final bool compact;
  final bool isDark;
  final double borderRadius;

  const ProductImagePlaceholder({
    super.key,
    required this.productName,
    this.categoryName,
    this.width,
    this.height,
    this.compact = false,
    this.isDark = false,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final visual = ProductVisualClassifier.resolve(
      categoryName: categoryName,
      productName: productName,
      isDark: isDark,
    );

    // Modo compacto: para tablas, carrito del POS, badges de vencimiento, etc.
    if (compact) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [visual.bgStart, visual.bgEnd],
          ),
          border: Border.all(
            color: visual.primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            visual.icon,
            color: visual.primaryColor,
            size: (height != null) ? height! * 0.52 : 18,
          ),
        ),
      );
    }

    // Modo tarjeta completa: para el catálogo POS o vista de cuadrícula
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [visual.bgStart, visual.bgEnd],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Aura sutil de fondo
          Positioned(
            top: 10,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: visual.primaryColor.withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
              ),
            ),
          ),

          // Contenedor circular con icono representativo
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceHighlight : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: visual.primaryColor.withValues(
                      alpha: isDark ? 0.35 : 0.2,
                    ),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: visual.primaryColor.withValues(
                        alpha: isDark ? 0.25 : 0.12,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    visual.icon,
                    size: 22,
                    color: visual.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Chip sutil de Categoría (sin texto feo de "Sin imagen")
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: visual.primaryColor.withValues(
                    alpha: isDark ? 0.2 : 0.1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: visual.primaryColor.withValues(
                      alpha: isDark ? 0.35 : 0.2,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  visual.label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: visual.primaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget completo de miniatura de producto con carga reactiva y fallback automático.
class ProductThumbnail extends StatelessWidget {
  final String? imageUrl;
  final String productName;
  final String? categoryName;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool compact;
  final bool isDark;
  final BoxFit fit;

  const ProductThumbnail({
    super.key,
    this.imageUrl,
    required this.productName,
    this.categoryName,
    this.width,
    this.height,
    this.borderRadius = 10,
    this.compact = false,
    this.isDark = false,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.trim().startsWith('http');

    final placeholder = ProductImagePlaceholder(
      productName: productName,
      categoryName: categoryName,
      width: width,
      height: height,
      compact: compact,
      isDark: isDark,
      borderRadius: borderRadius,
    );

    if (!hasUrl) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: imageUrl!.trim(),
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
      ),
    );
  }
}
