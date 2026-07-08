import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';

class CatalogEmptyState extends StatelessWidget {
  final bool searchByIngredient;
  final String searchTerm;
  final VoidCallback? onRetry;

  const CatalogEmptyState({
    super.key,
    this.searchByIngredient = false,
    this.searchTerm = '',
    this.onRetry,
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
      action: onRetry != null
          ? FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar / Limpiar'),
            )
          : null,
    );
  }
}

class CatalogErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const CatalogErrorState({
    super.key, 
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline =
        !context.watch<NetworkCubit>().isOnline ||
        message.toLowerCase().contains('conexión') ||
        message.toLowerCase().contains('internet') ||
        message.toLowerCase().contains('offline');

    return AppEmptyState(
      icon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      color: isOffline ? Colors.orange : AppColors.danger,
      title: isOffline ? 'Sin conexión a internet' : 'Ocurrió un error',
      message:
          isOffline ? 'Revisa tu conexión para cargar el catálogo.' : message,
      action: onRetry != null
          ? FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isOffline ? Colors.orange : AppColors.danger,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            )
          : null,
    );
  }
}
