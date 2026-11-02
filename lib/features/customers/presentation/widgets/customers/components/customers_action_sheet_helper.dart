import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/inspector/customer_side_sheet_inspector.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/inspector/mobile_customer_action_sheet.dart';

/// Coordinador de sheets de detalle e inspector táctil para clientes.
class CustomerActionSheetHelper {
  const CustomerActionSheetHelper._();

  /// Abre el inspector lateral pro estilo Stripe/Linear para Desktop y Tablet.
  static Future<void> openDesktopInspector({
    required BuildContext context,
    required CustomerEntity customer,
    required VoidCallback onEdit,
    required VoidCallback onOpenFullDetail,
    required void Function(String phone) onWhatsApp,
    required void Function(String phone) onCall,
    required void Function(String text, String label) onCopy,
  }) async {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final drawerWidth = screenWidth >= 1440 ? 560.0 : 500.0;

    await AdaptiveDetailSheet.show(
      context,
      desktopWidth: drawerWidth,
      barrierLabel: 'Cerrar inspector',
      builder: (dialogContext) {
        return CustomerSideSheetInspector(
          customer: customer,
          onClose: () => Navigator.of(dialogContext).maybePop(),
          onEdit: () {
            Navigator.of(dialogContext).pop();
            onEdit();
          },
          onOpenFullDetail: () {
            Navigator.of(dialogContext).pop();
            onOpenFullDetail();
          },
          onWhatsApp: onWhatsApp,
          onCall: onCall,
          onCopy: onCopy,
        );
      },
    );
  }

  /// Abre el modal inferior táctil estilo Apple HIG para móviles.
  static void showMobileActionSheet({
    required BuildContext context,
    required CustomerEntity customer,
    required VoidCallback onOpenDetail,
    required VoidCallback onEdit,
    required void Function(String phone) onWhatsApp,
    required void Function(String phone) onCall,
    required void Function(String doc, String docType) onCopyDoc,
  }) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (sheetCtx) => MobileCustomerActionSheet(
            customer: customer,
            onOpenDetail: () {
              Navigator.of(sheetCtx).pop();
              onOpenDetail();
            },
            onEdit: () {
              Navigator.of(sheetCtx).pop();
              onEdit();
            },
            onWhatsApp: () {
              Navigator.of(sheetCtx).pop();
              if (customer.phone != null) onWhatsApp(customer.phone!);
            },
            onCall: () {
              Navigator.of(sheetCtx).pop();
              if (customer.phone != null) onCall(customer.phone!);
            },
            onCopyDoc: () {
              Navigator.of(sheetCtx).pop();
              if (customer.documentNumber != null) {
                onCopyDoc(
                  customer.documentNumber!,
                  customer.documentType ?? 'Documento',
                );
              }
            },
          ),
    );
  }
}
