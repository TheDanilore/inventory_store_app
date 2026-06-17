import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/providers/network_provider.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class CatalogEmptyState extends StatelessWidget {
  final bool searchByIngredient;
  final String searchTerm;

  const CatalogEmptyState({
    super.key,
    this.searchByIngredient = false,
    this.searchTerm = '',
  });

  @override
  Widget build(BuildContext context) {
    final isIngMode = searchByIngredient && searchTerm.isNotEmpty;

    return AppEmptyState(
      icon: isIngMode ? Icons.science_rounded : Icons.inventory_2_rounded,
      color: isIngMode ? const Color(0xFF10B981) : AppColors.teal,
      title: isIngMode ? 'Sin resultados para "$searchTerm"' : 'Sin productos',
      message:
          isIngMode
              ? 'Ningún producto tiene ese ingrediente activo registrado. '
                  'Verifica el nombre o agrégalo desde el formulario del producto.'
              : 'No se encontraron productos\ncon los filtros actuales.',
    );
  }
}

class CatalogErrorState extends StatelessWidget {
  final String message;
  const CatalogErrorState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isOffline =
        !context.watch<NetworkProvider>().isOnline ||
        message.toLowerCase().contains('conexión') ||
        message.toLowerCase().contains('internet') ||
        message.toLowerCase().contains('offline');

    return AppEmptyState(
      icon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      color: isOffline ? Colors.orange : AppColors.danger,
      title: isOffline ? 'Sin conexión a internet' : 'Ocurrió un error',
      message:
          isOffline ? 'Revisa tu conexión para cargar el catálogo.' : message,
    );
  }
}
