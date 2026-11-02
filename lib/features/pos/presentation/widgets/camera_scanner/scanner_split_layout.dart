import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/services/product_ocr_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/ocr_variants_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/scanner_hud_overlays.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/scanner_live_cart_panel.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/camera_scanner/scanner_top_toolbar.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerSplitLayout extends StatelessWidget {
  final MobileScannerController scannerController;
  final Animation<double> scanAnimation;
  final PosScannerMode scannerMode;
  final String title;
  final bool isTorchOn;
  final CameraFacing cameraFacing;
  final bool isResolving;
  final bool isOcrProcessing;
  final String? lastScannedName;
  final ProductOcrMatchResult? pendingAmbiguousResult;
  final CartCubit cartCubit;
  final TextEditingController manualInputCtrl;
  final FocusNode manualFocusNode;

  final ValueChanged<String> onBarcodeDetected;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;
  final VoidCallback onSwitchCamera;
  final ValueChanged<PosScannerMode> onModeChanged;
  final VoidCallback onDismissFeedback;
  final VoidCallback onManualSubmit;
  final VoidCallback onOpenSearchModal;
  final ValueChanged<ProductVariantEntity> onAmbiguousVariantSelected;
  final VoidCallback onCloseAmbiguousSheet;
  final VoidCallback onCaptureCameraOcr;
  final VoidCallback onPickGalleryOcr;

  const ScannerSplitLayout({
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
    required this.pendingAmbiguousResult,
    required this.cartCubit,
    required this.manualInputCtrl,
    required this.manualFocusNode,
    required this.onBarcodeDetected,
    required this.onClose,
    required this.onToggleTorch,
    required this.onSwitchCamera,
    required this.onModeChanged,
    required this.onDismissFeedback,
    required this.onManualSubmit,
    required this.onOpenSearchModal,
    required this.onAmbiguousVariantSelected,
    required this.onCloseAmbiguousSheet,
    required this.onCaptureCameraOcr,
    required this.onPickGalleryOcr,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 80;
    final defaultCameraHeight =
        isDesktop
            ? 310.0
            : (MediaQuery.of(context).size.height *
                (scannerMode == PosScannerMode.ocrLabel ? 0.42 : 0.36));
    final cameraHeight = isKeyboardOpen ? 0.0 : defaultCameraHeight;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            if (isKeyboardOpen)
              ScannerKeyboardHeader(
                onClose: onClose,
                onHideKeyboard: () => FocusScope.of(context).unfocus(),
              ),

            // Visor de Cámara Superior con colapso animado
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: cameraHeight,
              child: ClipRect(
                child:
                    cameraHeight == 0.0
                        ? const SizedBox.shrink()
                        : Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: scannerController,
                              fit: BoxFit.cover,
                              onDetect: (capture) {
                                if (scannerMode != PosScannerMode.barcode) {
                                  return;
                                }
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

                            // HUD adaptado según modo
                            Positioned.fill(
                              child:
                                  scannerMode == PosScannerMode.barcode
                                      ? CompactScanHud(
                                        scanAnimation: scanAnimation,
                                      )
                                      : OcrScanHud(
                                        isSplit: true,
                                        isOcrProcessing: isOcrProcessing,
                                        onCaptureCamera: onCaptureCameraOcr,
                                        onPickGallery: onPickGalleryOcr,
                                      ),
                            ),

                            // Barra superior flotante de controles
                            Positioned(
                              top:
                                  MediaQuery.of(context).padding.top > 0
                                      ? MediaQuery.of(context).padding.top + 6
                                      : 10,
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

                            // Pill Banner Toast flotante
                            if (lastScannedName != null)
                              Positioned(
                                bottom: 10,
                                left: 16,
                                right: 16,
                                child: ScannedFeedbackBanner(
                                  productName: lastScannedName!,
                                  onDismiss: onDismissFeedback,
                                ),
                              ),

                            // Selector flotante de variantes si el OCR detectó ambigüedad
                            if (pendingAmbiguousResult != null)
                              OcrVariantsSheet(
                                result: pendingAmbiguousResult!,
                                onClose: onCloseAmbiguousSheet,
                                onVariantSelected: onAmbiguousVariantSelected,
                              ),

                            // Overlay de búsqueda en proceso
                            if (isResolving)
                              Positioned.fill(
                                child: Container(
                                  color: Colors.black45,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.teal,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              ),

                            // Overlay de procesamiento OCR inteligente
                            if (isOcrProcessing) const OcrProcessingOverlay(),
                          ],
                        ),
              ),
            ),

            if (isKeyboardOpen && lastScannedName != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                child: ScannedFeedbackBanner(
                  productName: lastScannedName!,
                  onDismiss: onDismissFeedback,
                ),
              ),

            // Panel Interactivo del Carrito en Vivo
            Expanded(
              child: ScannerLiveCartPanel(
                cartCubit: cartCubit,
                manualInputCtrl: manualInputCtrl,
                manualFocusNode: manualFocusNode,
                onManualSubmit: onManualSubmit,
                onOpenSearchModal: onOpenSearchModal,
                onCheckout: onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
