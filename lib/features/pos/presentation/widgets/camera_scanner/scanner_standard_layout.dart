import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/services/product_ocr_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/ocr_variants_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/scanner_hud_overlays.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/scanner_manual_input_bar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/scanner_top_toolbar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerStandardLayout extends StatelessWidget {
  final MobileScannerController scannerController;
  final Animation<double> scanAnimation;
  final PosScannerMode scannerMode;
  final String title;
  final bool isTorchOn;
  final CameraFacing cameraFacing;
  final bool isResolving;
  final bool isOcrProcessing;
  final String? lastScannedName;
  final int scannedCount;
  final bool isContinuous;
  final ProductOcrMatchResult? pendingAmbiguousResult;
  final TextEditingController manualInputCtrl;
  final FocusNode manualFocusNode;

  final ValueChanged<String> onBarcodeDetected;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final ValueChanged<PosScannerMode> onModeChanged;
  final VoidCallback onDismissFeedback;
  final VoidCallback onManualSubmit;
  final ValueChanged<ProductVariantEntity> onAmbiguousVariantSelected;
  final VoidCallback onCloseAmbiguousSheet;
  final VoidCallback onCaptureCameraOcr;
  final VoidCallback onPickGalleryOcr;

  const ScannerStandardLayout({
    super.key,
    required this.scannerController,
    required this.scanAnimation,
    required this.scannerMode,
    required this.title,
    required this.isTorchOn,
    required this.cameraFacing,
    required this.isResolving,
    required this.isOcrProcessing,
    required this.lastScannedName,
    required this.scannedCount,
    required this.isContinuous,
    required this.pendingAmbiguousResult,
    required this.manualInputCtrl,
    required this.manualFocusNode,
    required this.onBarcodeDetected,
    required this.onClose,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    required this.onModeChanged,
    required this.onDismissFeedback,
    required this.onManualSubmit,
    required this.onAmbiguousVariantSelected,
    required this.onCloseAmbiguousSheet,
    required this.onCaptureCameraOcr,
    required this.onPickGalleryOcr,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Visor de la cámara
          Positioned.fill(
            child: MobileScanner(
              controller: scannerController,
              fit: BoxFit.cover,
              onDetect: (capture) {
                if (scannerMode != PosScannerMode.barcode) return;
                for (final barcode in capture.barcodes) {
                  final rawValue = barcode.rawValue;
                  if (rawValue != null && rawValue.isNotEmpty) {
                    onBarcodeDetected(rawValue);
                    break;
                  }
                }
              },
              errorBuilder:
                  (context, error) => CameraErrorView(
                    errorMessage: error.errorDetails?.message,
                  ),
            ),
          ),

          // 2. Máscara HUD adaptativa según modo
          Positioned.fill(
            child:
                scannerMode == PosScannerMode.barcode
                    ? CenteredScanHud(scanAnimation: scanAnimation)
                    : OcrScanHud(
                      isSplit: false,
                      isOcrProcessing: isOcrProcessing,
                      onCaptureCamera: onCaptureCameraOcr,
                      onPickGallery: onPickGalleryOcr,
                    ),
          ),

          // 3. Barra Superior Flotante con Selector de Modos
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: ScannerTopToolbar(
              title: title,
              isTorchOn: isTorchOn,
              cameraFacing: cameraFacing,
              scannerMode: scannerMode,
              onClose: onClose,
              onToggleTorch: onToggleTorch,
              onSwitchCamera: onSwitchCamera,
              onModeChanged: onModeChanged,
            ),
          ),

          // 4. Banner flotante de confirmación continua
          if (lastScannedName != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 108,
              left: 16,
              right: 16,
              child: ScannedFeedbackBanner(
                productName: lastScannedName!,
                onDismiss: onDismissFeedback,
              ),
            ),

          // 5. Barra Inferior con Entrada Manual (solo en modo barcode)
          if (scannerMode == PosScannerMode.barcode)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ScannerManualInputBar(
                controller: manualInputCtrl,
                focusNode: manualFocusNode,
                isContinuous: isContinuous,
                scannedCount: scannedCount,
                isResolving: isResolving,
                onSubmit: onManualSubmit,
                onClose: onClose,
              ),
            ),

          // 6. Selector flotante de variantes si el OCR detectó ambigüedad
          if (pendingAmbiguousResult != null)
            OcrVariantsSheet(
              result: pendingAmbiguousResult!,
              onClose: onCloseAmbiguousSheet,
              onVariantSelected: onAmbiguousVariantSelected,
            ),

          // 7. Indicador de carga de resolución de código
          if (isResolving)
            Positioned.fill(
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.teal,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 14),
                      Text(
                        'Buscando código...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 8. Indicador de carga OCR
          if (isOcrProcessing) const OcrProcessingOverlay(),
        ],
      ),
    );
  }
}
