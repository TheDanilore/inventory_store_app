import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

/// Visor inteligente de recursos gráficos (SVG vectoriales, renders 3D WebP/PNG y URLs).
///
/// Implementa la recomendación de UI/UX:
/// - Tarjetas blancas o superficies limpias con bordes suaves (`BorderRadius.circular(16)`).
/// - Sombras difusas y sutiles que aportan profundidad sobre fondos ligeramente grises.
/// - Máxima nitidez en vectores (.svg) con [SvgPicture.asset].
/// - Texturas y volumen vibrante en renders 3D (.webp / .png) con [Image.asset].
class AppAssetMedia extends StatelessWidget {
  /// Ruta del asset local o URL remota (ej: 'assets/icons/fire.svg', 'assets/images/delivery.png', 'https://...').
  final String? assetPath;

  /// Ancho del contenedor o render.
  final double? width;

  /// Alto del contenedor o render.
  final double? height;

  /// Modo de ajuste de la imagen (por defecto [BoxFit.contain] para resaltar siluetas 3D con transparencia).
  final BoxFit fit;

  /// Opcional: filtro de color para iconos SVG monocromáticos.
  final Color? colorFilter;

  /// Widget fallback si el asset es nulo o falla al cargar.
  final Widget? fallbackWidget;

  /// Padding interno para que el render 3D o icono respire con respecto al contenedor.
  final EdgeInsetsGeometry padding;

  const AppAssetMedia({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.colorFilter,
    this.fallbackWidget,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final path = assetPath?.trim() ?? '';
    if (path.isEmpty) {
      return _buildFallback();
    }

    Widget content;
    final isHttp = path.startsWith('http://') || path.startsWith('https://');
    final isSvg = path.toLowerCase().endsWith('.svg');

    if (isHttp) {
      if (isSvg) {
        content = SvgPicture.network(
          path,
          width: width,
          height: height,
          fit: fit,
          colorFilter:
              colorFilter != null
                  ? ColorFilter.mode(colorFilter!, BlendMode.srcIn)
                  : null,
          placeholderBuilder: (_) => _buildShimmer(),
        );
      } else {
        content = CachedNetworkImage(
          imageUrl: path,
          width: width,
          height: height,
          fit: fit,
          placeholder: (_, _) => _buildShimmer(),
          errorWidget: (_, _, _) => _buildFallback(),
        );
      }
    } else if (isSvg) {
      content = SvgPicture.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        colorFilter:
            colorFilter != null
                ? ColorFilter.mode(colorFilter!, BlendMode.srcIn)
                : null,
        placeholderBuilder: (_) => _buildShimmer(),
      );
    } else {
      // Renders 3D PNG o WebP con canal alfa/transparente
      content = Image.asset(
        path,
        width: width,
        height: height,
        fit: fit,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }

    if (padding != EdgeInsets.zero) {
      return Padding(padding: padding, child: content);
    }
    return content;
  }

  Widget _buildShimmer() {
    return AppShimmer(
      width: width ?? 56,
      height: height ?? 56,
      borderRadius: 16,
    );
  }

  Widget _buildFallback() {
    if (fallbackWidget != null) return fallbackWidget!;
    return Center(
      child: Icon(
        Icons.layers_outlined,
        size: (width != null && height != null) ? (width! * 0.4) : 24,
        color: AppColors.textMuted.withValues(alpha: 0.6),
      ),
    );
  }
}

/// Tarjeta Premium con contraste optimizado para renders 3D e iconos SVG.
///
/// Sigue la regla de oro de diseño:
/// Contenedor blanco con `BorderRadius.circular(16)` sobre fondo ligeramente gris,
/// generando el contraste perfecto para que el volumen y las sombras transparentes resalten.
class PremiumAssetCard extends StatelessWidget {
  /// Recurso gráfico del render 3D o SVG (ej: 'assets/icons/fire.svg' o URL).
  final String? assetPath;

  /// Alternativamente, un widget gráfico personalizado en el contenedor superior.
  final Widget? mediaWidget;

  /// Tamaño asignado al render 3D / media.
  final double mediaSize;

  /// Título de la tarjeta (ej. Producto, Categoría o Estado).
  final String title;

  /// Subtítulo o descripción secundaria.
  final String? subtitle;

  /// Etiqueta o badge flotante (ej: 'NUEVO', '-20%', '1 Litro').
  final String? tag;

  /// Color del badge tag.
  final Color? tagColor;

  /// Widget complementario en la base (ej: Precio, botón agregar, rating).
  final Widget? footer;

  /// Callback al presionar la tarjeta.
  final VoidCallback? onTap;

  /// Radio de las esquinas del contenedor (por defecto 16.0).
  final double borderRadius;

  /// Color de fondo del contenedor (por defecto blanco para máximo contraste).
  final Color backgroundColor;

  /// Borde del contenedor.
  final Border? border;

  /// Si muestra sombra sutil multicapa.
  final bool elevated;

  const PremiumAssetCard({
    super.key,
    this.assetPath,
    this.mediaWidget,
    this.mediaSize = 100,
    required this.title,
    this.subtitle,
    this.tag,
    this.tagColor,
    this.footer,
    this.onTap,
    this.borderRadius = 16,
    this.backgroundColor = Colors.white,
    this.border,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        border ??
        Border.all(color: AppColors.border.withValues(alpha: 0.7), width: 1);

    final cardContent = Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow:
            elevated
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
                : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Área del Render 3D / Icono sobre fondo de contraste
                  Center(
                    child: Container(
                      height: mediaSize,
                      width: double.infinity,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.background.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(borderRadius - 4),
                      ),
                      child:
                          mediaWidget ??
                          AppAssetMedia(
                            assetPath: assetPath,
                            width: mediaSize * 0.85,
                            height: mediaSize * 0.85,
                            fit: BoxFit.contain,
                          ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Título principal
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),

                  // Subtítulo
                  if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],

                  // Footer opcional (precios, controles)
                  if (footer != null) ...[const SizedBox(height: 8), footer!],
                ],
              ),
            ),

            // Badge / Tag superior derecho
            if (tag != null && tag!.trim().isNotEmpty)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (tagColor ?? AppColors.primary).withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (tagColor ?? AppColors.primary).withValues(
                        alpha: 0.3,
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tag!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: tagColor ?? AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// Contenedor de cápsula para iconos vectoriales SVG o métricas destacadas
/// (ej. fuego de calorías/ofertas, reloj de tiempo, carrito, entrega express).
class PremiumAssetBadge extends StatelessWidget {
  final String assetPath;
  final String? label;
  final Color? tintColor;
  final Color? backgroundColor;
  final double iconSize;
  final VoidCallback? onTap;

  const PremiumAssetBadge({
    super.key,
    required this.assetPath,
    this.label,
    this.tintColor,
    this.backgroundColor,
    this.iconSize = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = tintColor ?? AppColors.primary;
    final bg = backgroundColor ?? effectiveColor.withValues(alpha: 0.08);

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: label != null ? 10 : 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppAssetMedia(
            assetPath: assetPath,
            width: iconSize,
            height: iconSize,
            colorFilter:
                assetPath.endsWith('.svg') && tintColor != null
                    ? effectiveColor
                    : null,
          ),
          if (label != null && label!.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              label!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: effectiveColor,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: content,
      );
    }
    return content;
  }
}
