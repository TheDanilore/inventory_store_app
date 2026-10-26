import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/scanner_painters.dart';

/// Retícula compacta con esquinas verde esmeralda (#10B981) y animación láser para modo dividido
class CompactScanHud extends StatelessWidget {
  final Animation<double> scanAnimation;

  const CompactScanHud({super.key, required this.scanAnimation});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = (constraints.maxWidth * 0.78).clamp(190.0, 320.0);
        final boxHeight = (constraints.maxHeight * 0.60).clamp(100.0, 160.0);
        final leftOffset = (constraints.maxWidth - boxWidth) / 2;
        final topOffset = (constraints.maxHeight - boxHeight) / 2 + 12;
        final scanRect = Rect.fromLTWH(
          leftOffset,
          topOffset,
          boxWidth,
          boxHeight,
        );

        return Stack(
          children: [
            // 1. Máscara oscura
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerOverlayPainter(
                  scanWindow: scanRect,
                  borderRadius: 16,
                  overlayColor: Colors.black.withValues(alpha: 0.52),
                ),
              ),
            ),

            // 2. Retícula con 4 esquinas destacadas verde esmeralda (#10B981)
            Positioned.fill(
              child: CustomPaint(
                painter: CornerBracketPainter(
                  scanRect: scanRect,
                  color: const Color(0xFF10B981),
                  cornerLength: 22,
                  strokeWidth: 3.5,
                ),
              ),
            ),

            // 3. Línea láser animada dentro del marco
            AnimatedBuilder(
              animation: scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: topOffset + (scanAnimation.value * (boxHeight - 4)),
                  left: leftOffset + 6,
                  width: boxWidth - 12,
                  height: 2.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // 4. Etiqueta instructiva compacta
            Positioned(
              bottom: 6,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 13,
                        color: Color(0xFF10B981),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Apunta al código de barras o QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// HUD centrado a pantalla completa para escaneo individual o ráfaga
class CenteredScanHud extends StatelessWidget {
  final Animation<double> scanAnimation;

  const CenteredScanHud({super.key, required this.scanAnimation});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = (constraints.maxWidth * 0.70).clamp(210.0, 300.0);
        final leftOffset = (constraints.maxWidth - boxSize) / 2;
        final topOffset = (constraints.maxHeight - boxSize) / 2 - 20;
        final scanRect = Rect.fromLTWH(leftOffset, topOffset, boxSize, boxSize);

        return Stack(
          children: [
            // 1. Máscara oscura
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerOverlayPainter(
                  scanWindow: scanRect,
                  borderRadius: 22,
                  overlayColor: Colors.black.withValues(alpha: 0.58),
                ),
              ),
            ),

            // 2. Marco con esquinas redondeadas color Neón Teal
            Positioned(
              top: topOffset,
              left: leftOffset,
              width: boxSize,
              height: boxSize,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppColors.teal.withValues(alpha: 0.95),
                    width: 2.5,
                  ),
                ),
              ),
            ),

            // 3. Línea láser animada
            AnimatedBuilder(
              animation: scanAnimation,
              builder: (context, child) {
                return Positioned(
                  top: topOffset + (scanAnimation.value * (boxSize - 4)),
                  left: leftOffset + 8,
                  width: boxSize - 16,
                  height: 2.5,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.teal,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.9),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Texto instructivo debajo del marco
            Positioned(
              top: topOffset + boxSize + 16,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 15,
                        color: AppColors.teal,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Apunta al código de barras o QR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// HUD para el modo de reconocimiento óptico de caracteres (OCR)
class OcrScanHud extends StatelessWidget {
  final bool isSplit;
  final bool isOcrProcessing;
  final VoidCallback onCaptureCamera;
  final VoidCallback onPickGallery;

  const OcrScanHud({
    super.key,
    required this.isSplit,
    required this.isOcrProcessing,
    required this.onCaptureCamera,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = (constraints.maxWidth * 0.86).clamp(240.0, 420.0);
        final boxHeight =
            isSplit
                ? (constraints.maxHeight * 0.58).clamp(110.0, 170.0)
                : (constraints.maxHeight * 0.44).clamp(200.0, 310.0);
        final leftOffset = (constraints.maxWidth - boxWidth) / 2;
        final topOffset =
            (constraints.maxHeight - boxHeight) / 2 + (isSplit ? 24 : -10);
        final scanRect = Rect.fromLTWH(
          leftOffset,
          topOffset,
          boxWidth,
          boxHeight,
        );

        return Stack(
          children: [
            // 1. Máscara oscura
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerOverlayPainter(
                  scanWindow: scanRect,
                  borderRadius: 20,
                  overlayColor: Colors.black.withValues(alpha: 0.52),
                ),
              ),
            ),

            // 2. Esquinas destacadas ámbar dorado
            Positioned.fill(
              child: CustomPaint(
                painter: CornerBracketPainter(
                  scanRect: scanRect,
                  color: const Color(0xFFF59E0B),
                  cornerLength: 26,
                  strokeWidth: 3.5,
                ),
              ),
            ),

            // 3. Indicador instructivo dentro del marco
            Positioned(
              top: topOffset + 10,
              left: leftOffset + 12,
              right: leftOffset + 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: 13,
                        color: Color(0xFFF59E0B),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Enfoca el nombre y presentación del producto',
                        style: TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 4. Botones de captura flotantes
            Positioned(
              bottom: isSplit ? 6 : 80,
              left: 20,
              right: 20,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.45),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: isOcrProcessing ? null : onCaptureCamera,
                        icon:
                            isOcrProcessing
                                ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                ),
                        label: Text(
                          isOcrProcessing
                              ? 'Leyendo...'
                              : 'Capturar y Leer Etiqueta',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: EdgeInsets.symmetric(
                            horizontal: isSplit ? 14 : 20,
                            vertical: isSplit ? 8 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Cargar foto de galería',
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: isOcrProcessing ? null : onPickGallery,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.photo_library_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Toast Banner flotante animado de confirmación de producto agregado
class ScannedFeedbackBanner extends StatelessWidget {
  final String productName;
  final VoidCallback onDismiss;

  const ScannedFeedbackBanner({
    super.key,
    required this.productName,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xE80F172A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.28),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'AGREGADO AL CARRITO',
                          style: TextStyle(
                            color: Color(0xFF34D399),
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            '+1',
                            style: TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      productName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlay de procesamiento OCR con IA
class OcrProcessingOverlay extends StatelessWidget {
  const OcrProcessingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFF59E0B),
                strokeWidth: 3.5,
              ),
              SizedBox(height: 16),
              Text(
                'Leyendo texto de etiqueta con IA...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Reconociendo marca, título y variantes',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vista cuando la cámara no está disponible o da error
class CameraErrorView extends StatelessWidget {
  final String? errorMessage;

  const CameraErrorView({super.key, this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white70,
              size: 36,
            ),
            const SizedBox(height: 8),
            const Text(
              'Cámara no disponible',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              errorMessage ?? 'Usa el buscador por nombre abajo.',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
