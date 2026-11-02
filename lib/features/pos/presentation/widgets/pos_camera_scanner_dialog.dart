import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/utils/camera_stream_stopper.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/services/pos_barcode_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/services/product_ocr_scanner_service.dart';

import 'camera_scanner/quick_product_search_sheet.dart';
import 'camera_scanner/scanner_standard_layout.dart';
import 'camera_scanner/scanner_split_layout.dart';

/// Modos de captura disponibles en el visor de cámara del POS
enum PosScannerMode {
  /// Escaneo rápido de códigos de barra (1D) y QR tradicionales
  barcode,

  /// Reconocimiento óptico de caracteres (OCR) para leer etiquetas, marcas y variantes
  ocrLabel,
}

/// Modal interactivo de escaneo por cámara de Códigos de Barra y QR.
///
/// Soporta:
/// - Modo Individual: escanea un producto, lo retorna y se cierra.
/// - Modo Continuo (Ráfaga): mantiene la cámara encendida y añade producto tras
///   producto a la lista/carrito en tiempo real sin interrupciones.
/// - Vista dividida (Split Scanner + Live Cart) estilo retail con HUD reticular.
/// - Apagado garantizado de la cámara al cerrar el modal (libera hardware/webcam).
/// - Linterna, cambio de cámara, entrada manual y búsqueda por título.
/// - Escaneo inteligente OCR de etiquetas y desambiguación automática de variantes.
class PosCameraScannerDialog extends StatefulWidget {
  final String? warehouseId;
  final String? title;
  final bool continuousMode;
  final FutureOr<dynamic> Function(PosScanResult result)? onContinuousScan;
  final bool returnRawCode;
  final CartCubit? cartCubit;

  const PosCameraScannerDialog({
    super.key,
    this.warehouseId,
    this.title,
    this.continuousMode = false,
    this.onContinuousScan,
    this.returnRawCode = false,
    this.cartCubit,
  });

  /// Abre el modal de escaneo adaptado a la plataforma y garantiza
  /// el apagado total del hardware de la cámara web al salir.
  static Future<PosScanResult?> show(
    BuildContext context, {
    String? warehouseId,
    String? title,
    bool continuousMode = false,
    FutureOr<dynamic> Function(PosScanResult result)? onContinuousScan,
    bool returnRawCode = false,
    CartCubit? cartCubit,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    PosScanResult? result;
    if (isDesktop) {
      result = await showDialog<PosScanResult>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder:
            (_) => Dialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cartCubit != null ? 580 : 520,
                  maxHeight: cartCubit != null ? 760 : 680,
                ),
                child: PosCameraScannerDialog(
                  warehouseId: warehouseId,
                  title: title,
                  continuousMode: continuousMode,
                  onContinuousScan: onContinuousScan,
                  returnRawCode: returnRawCode,
                  cartCubit: cartCubit,
                ),
              ),
            ),
      );
    } else {
      result = await showModalBottomSheet<PosScanResult>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          final bottomInset = MediaQuery.of(sheetCtx).viewInsets.bottom;
          final screenHeight = MediaQuery.of(sheetCtx).size.height;
          final baseHeight = screenHeight * (cartCubit != null ? 0.94 : 0.85);
          final sheetHeight =
              bottomInset > 0
                  ? (screenHeight - bottomInset).clamp(320.0, baseHeight)
                  : baseHeight;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Container(
              height: sheetHeight,
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: PosCameraScannerDialog(
                warehouseId: warehouseId,
                title: title,
                continuousMode: continuousMode,
                onContinuousScan: onContinuousScan,
                returnRawCode: returnRawCode,
                cartCubit: cartCubit,
              ),
            ),
          );
        },
      );
    }
    // Garantiza el apagado físico del hardware de la cámara (web/móvil)
    stopAllWebCameraStreams();
    return result;
  }

  /// Escanea un código de barras o QR físico directamente y retorna su texto plano (raw code).
  /// Ideal para formularios de alta/edición de productos donde el código aún no existe en BD.
  static Future<String?> showForRawCode(
    BuildContext context, {
    String? title,
  }) async {
    final result = await show(
      context,
      title: title ?? 'Escanear Código de Barras / QR',
      returnRawCode: true,
    );
    return result?.rawCode;
  }

  @override
  State<PosCameraScannerDialog> createState() => _PosCameraScannerDialogState();
}

class _PosCameraScannerDialogState extends State<PosCameraScannerDialog>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  final _manualInputCtrl = TextEditingController();
  final _manualFocusNode = FocusNode();

  bool _isResolving = false;
  bool _isTorchOn = false;
  bool _isClosing = false;
  CameraFacing _cameraFacing = CameraFacing.back;
  late final AnimationController _animController;
  late final Animation<double> _scanAnimation;

  // Estado para modo continuo
  int _scannedCount = 0;
  String? _lastScannedName;
  Timer? _feedbackTimer;
  DateTime _lastDetectionTime = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastRawCode = '';

  // Estado para Modo OCR y resolución de variantes
  PosScannerMode _scannerMode = PosScannerMode.barcode;
  bool _isOcrProcessing = false;
  ProductOcrMatchResult? _pendingAmbiguousResult;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: _cameraFacing,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _feedbackTimer?.cancel();
    ProductOcrScannerService.dispose();
    try {
      _scannerController.stop();
      _scannerController.dispose();
    } catch (_) {}
    stopAllWebCameraStreams();
    _manualInputCtrl.dispose();
    _manualFocusNode.dispose();
    super.dispose();
  }

  /// Cierra el diálogo y garantiza el apagado del hardware de cámara
  Future<void> _safeClose([PosScanResult? result]) async {
    if (_isClosing) return;
    _isClosing = true;

    try {
      await _scannerController.stop();
    } catch (_) {}
    stopAllWebCameraStreams();

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  Future<void> _handleBarcodeDetected(String rawCode) async {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty || _isResolving || _isClosing) return;

    // Evitar lecturas duplicadas en ráfaga del mismo código en menos de 1.3 segundos
    final now = DateTime.now();
    if (trimmed == _lastRawCode &&
        now.difference(_lastDetectionTime).inMilliseconds < 1300) {
      return;
    }

    _lastRawCode = trimmed;
    _lastDetectionTime = now;

    setState(() => _isResolving = true);
    AppFeedbackService.mediumImpact();

    if (widget.returnRawCode) {
      AppFeedbackService.lightImpact();
      final rawResult = PosScanResult(
        product: ProductEntity(id: '', name: trimmed),
        rawCode: trimmed,
      );
      await _safeClose(rawResult);
      return;
    }

    try {
      final result = await PosBarcodeScannerService.resolveCode(
        trimmed,
        warehouseId: widget.warehouseId,
      );

      if (!mounted || _isClosing) return;

      if (result != null) {
        AppFeedbackService.triggerFeedback();

        if (widget.continuousMode || widget.onContinuousScan != null) {
          // Modo Rápido / Continuo: agrega a la lista y se mantiene escaneando
          if (widget.onContinuousScan != null) {
            final scanSuccess = await widget.onContinuousScan!(result);
            if (scanSuccess == false) {
              if (mounted) setState(() => _isResolving = false);
              return;
            }
          }

          if (mounted) {
            setState(() {
              _scannedCount++;
              _lastScannedName = result.product.name;
              _isResolving = false;
            });

            _feedbackTimer?.cancel();
            _feedbackTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() => _lastScannedName = null);
              }
            });
          }
        } else {
          // Modo Individual: detiene cámara y retorna el resultado
          await _safeClose(result);
        }
      } else {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'No se encontró producto para el código "$trimmed"',
            type: SnackbarType.warning,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al buscar código: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted && !_isClosing) {
        setState(() => _isResolving = false);
      }
    }
  }

  void _onManualSubmit() {
    final code = _manualInputCtrl.text.trim();
    if (code.isNotEmpty) {
      _manualInputCtrl.clear();
      _handleBarcodeDetected(code);
    }
  }

  Future<void> _captureAndScanOcr({bool fromGallery = false}) async {
    if (_isResolving || _isOcrProcessing || _isClosing) return;

    try {
      final picker = ImagePicker();
      final source = fromGallery ? ImageSource.gallery : ImageSource.camera;

      try {
        await _scannerController.stop();
      } catch (_) {}

      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 1920,
      );

      if (mounted && !_isClosing) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }

      if (pickedFile == null) return;

      setState(() => _isOcrProcessing = true);
      AppFeedbackService.mediumImpact();

      final result = await ProductOcrScannerService.recognizeFromImageFile(
        pickedFile.path,
        warehouseId: widget.warehouseId,
      );

      if (!mounted || _isClosing) return;

      if (result == null) {
        AppSnackbar.show(
          context,
          message:
              'No se reconoció ningún producto en la etiqueta. Intenta enfocar más de cerca el título.',
          type: SnackbarType.warning,
        );
        return;
      }

      if (result.isDirectMatch && result.variant != null) {
        AppFeedbackService.triggerFeedback();

        final scanResult = PosScanResult(
          product: result.product,
          variant: result.variant,
          rawCode:
              result.variant?.barcode ??
              result.variant?.sku ??
              result.product.id,
        );

        if (widget.cartCubit != null) {
          final added = await PosBarcodeScannerService.addScanResultToCart(
            context: context,
            scanResult: scanResult,
            cartCubit: widget.cartCubit!,
            warehouseId: widget.warehouseId,
            showSnackbar: false,
          );

          if (added && mounted) {
            final variantLabel =
                result.variant?.shortLabel.isNotEmpty == true
                    ? ' (${result.variant!.shortLabel})'
                    : '';
            setState(() {
              _scannedCount++;
              _lastScannedName = '${result.product.name}$variantLabel';
            });
            _feedbackTimer?.cancel();
            _feedbackTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _lastScannedName = null);
            });
          }
        } else if (widget.continuousMode || widget.onContinuousScan != null) {
          if (widget.onContinuousScan != null) {
            await widget.onContinuousScan!(scanResult);
          }
          if (mounted) {
            setState(() {
              _scannedCount++;
              _lastScannedName = result.product.name;
            });
          }
        } else {
          await _safeClose(scanResult);
        }
      } else {
        AppFeedbackService.mediumImpact();
        setState(() {
          _pendingAmbiguousResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al leer etiqueta: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOcrProcessing = false);
      }
    }
  }

  Future<void> _openQuickTitleSearchModal(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (modalCtx) => QuickProductSearchSheet(
            warehouseId: widget.warehouseId,
            onProductSelected: (product) async {
              Navigator.of(modalCtx).pop();
              if (widget.cartCubit != null) {
                await PosBarcodeScannerService.addScanResultToCart(
                  context: context,
                  scanResult: PosScanResult(
                    product: product,
                    variant: product.defaultVariant,
                    rawCode: product.id,
                  ),
                  cartCubit: widget.cartCubit!,
                  warehouseId: widget.warehouseId,
                  showSnackbar: false,
                );
                if (mounted) {
                  setState(() {
                    _lastScannedName = product.name;
                  });
                  _feedbackTimer?.cancel();
                  _feedbackTimer = Timer(const Duration(seconds: 3), () {
                    if (mounted) {
                      setState(() => _lastScannedName = null);
                    }
                  });
                }
              }
            },
          ),
    );
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    if (mounted) setState(() => _isTorchOn = !_isTorchOn);
  }

  Future<void> _switchCamera() async {
    await _scannerController.switchCamera();
    if (mounted) {
      setState(() {
        _cameraFacing =
            _cameraFacing == CameraFacing.back
                ? CameraFacing.front
                : CameraFacing.back;
      });
    }
  }

  void _setScannerMode(PosScannerMode mode) {
    setState(() {
      _scannerMode = mode;
      _pendingAmbiguousResult = null;
    });
  }

  Future<void> _onAmbiguousVariantSelectedStandard(
    ProductVariantEntity variant,
  ) async {
    final match = _pendingAmbiguousResult;
    if (match == null) return;
    final scanResult = PosScanResult(
      product: match.product,
      variant: variant,
      rawCode: variant.barcode ?? variant.sku ?? match.product.id,
    );
    setState(() => _pendingAmbiguousResult = null);

    if (widget.continuousMode || widget.onContinuousScan != null) {
      if (widget.onContinuousScan != null) {
        await widget.onContinuousScan!(scanResult);
      }
      if (mounted) {
        setState(() {
          _scannedCount++;
          _lastScannedName = '${match.product.name} (${variant.label})';
        });
      }
    } else {
      await _safeClose(scanResult);
    }
  }

  Future<void> _onAmbiguousVariantSelectedSplit(
    ProductVariantEntity variant,
  ) async {
    final match = _pendingAmbiguousResult;
    if (match == null) return;
    final scanResult = PosScanResult(
      product: match.product,
      variant: variant,
      rawCode: variant.barcode ?? variant.sku ?? match.product.id,
    );
    setState(() => _pendingAmbiguousResult = null);

    if (widget.cartCubit != null) {
      await PosBarcodeScannerService.addScanResultToCart(
        context: context,
        scanResult: scanResult,
        cartCubit: widget.cartCubit!,
        warehouseId: widget.warehouseId,
        showSnackbar: false,
      );
      if (mounted) {
        setState(() {
          _scannedCount++;
          _lastScannedName = '${match.product.name} (${variant.label})';
        });
        _feedbackTimer?.cancel();
        _feedbackTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() => _lastScannedName = null);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.title ??
        (_scannerMode == PosScannerMode.ocrLabel
            ? 'Reconocer Etiqueta (OCR)'
            : (widget.continuousMode ? 'Escaneo Continuo' : 'Escanear Código'));

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        try {
          _scannerController.stop();
        } catch (_) {}
        stopAllWebCameraStreams();
      },
      child:
          widget.cartCubit != null
              ? ScannerSplitLayout(
                scannerController: _scannerController,
                scanAnimation: _scanAnimation,
                scannerMode: _scannerMode,
                title: title,
                isTorchOn: _isTorchOn,
                cameraFacing: _cameraFacing,
                isResolving: _isResolving,
                isOcrProcessing: _isOcrProcessing,
                lastScannedName: _lastScannedName,
                pendingAmbiguousResult: _pendingAmbiguousResult,
                cartCubit: widget.cartCubit!,
                manualInputCtrl: _manualInputCtrl,
                manualFocusNode: _manualFocusNode,
                onBarcodeDetected: _handleBarcodeDetected,
                onClose: () => _safeClose(),
                onToggleTorch: _toggleTorch,
                onSwitchCamera: _switchCamera,
                onModeChanged: _setScannerMode,
                onDismissFeedback:
                    () => setState(() => _lastScannedName = null),
                onManualSubmit: _onManualSubmit,
                onOpenSearchModal: () => _openQuickTitleSearchModal(context),
                onAmbiguousVariantSelected: _onAmbiguousVariantSelectedSplit,
                onCloseAmbiguousSheet:
                    () => setState(() => _pendingAmbiguousResult = null),
                onCaptureCameraOcr:
                    () => _captureAndScanOcr(fromGallery: false),
                onPickGalleryOcr: () => _captureAndScanOcr(fromGallery: true),
              )
              : ScannerStandardLayout(
                scannerController: _scannerController,
                scanAnimation: _scanAnimation,
                scannerMode: _scannerMode,
                title: title,
                isTorchOn: _isTorchOn,
                cameraFacing: _cameraFacing,
                isResolving: _isResolving,
                isOcrProcessing: _isOcrProcessing,
                lastScannedName: _lastScannedName,
                scannedCount: _scannedCount,
                isContinuous:
                    widget.continuousMode || widget.onContinuousScan != null,
                pendingAmbiguousResult: _pendingAmbiguousResult,
                manualInputCtrl: _manualInputCtrl,
                manualFocusNode: _manualFocusNode,
                onBarcodeDetected: _handleBarcodeDetected,
                onClose: () => _safeClose(),
                onToggleTorch: _toggleTorch,
                onSwitchCamera: _switchCamera,
                onModeChanged: _setScannerMode,
                onDismissFeedback:
                    () => setState(() => _lastScannedName = null),
                onManualSubmit: _onManualSubmit,
                onAmbiguousVariantSelected: _onAmbiguousVariantSelectedStandard,
                onCloseAmbiguousSheet:
                    () => setState(() => _pendingAmbiguousResult = null),
                onCaptureCameraOcr:
                    () => _captureAndScanOcr(fromGallery: false),
                onPickGalleryOcr: () => _captureAndScanOcr(fromGallery: true),
              ),
    );
  }
}
