// ─── CLIENT SECTION ───────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

typedef ClientTapCallback = void Function(Map<String, dynamic> client);

class AdminSaleClientSection extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSearchChanged;
  final bool searching;
  final List<Map<String, dynamic>> matches;
  final String? selectedClientId;
  final ClientTapCallback onClientTap;
  final int saldoActualCliente;
  final Map<String, dynamic>? creditInfo;
  final bool isCredito;

  const AdminSaleClientSection({
    super.key,
    required this.controller,
    required this.onSearchChanged,
    required this.searching,
    required this.matches,
    required this.selectedClientId,
    required this.onClientTap,
    required this.saldoActualCliente,
    required this.creditInfo,
    required this.isCredito,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: selectedClientId != null ? AppColors.teal : AppColors.border,
          width: selectedClientId != null ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: controller,
              onChanged: onSearchChanged,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, teléfono o documento…',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          if (searching)
            const _ClientSearchState(
              icon: null,
              isLoading: true,
              message: 'Buscando clientes…',
            )
          else if (selectedClientId != null)
            _SelectedClientBanner(
              saldo: saldoActualCliente,
              creditInfo: creditInfo,
              isCredito: isCredito,
            )
          else if (controller.text.trim().isEmpty)
            const _ClientSearchState(
              icon: Icons.person_search_rounded,
              message: 'Busca un cliente o ingresa un nombre para el ticket.',
            )
          else if (matches.isEmpty)
            _ClientSearchState(
              icon: Icons.person_add_alt_1_rounded,
              message: 'Venta libre a nombre de: "${controller.text.trim()}"',
              isHighlight: true,
            )
          else
            _ClientMatchesList(
              matches: matches,
              selectedClientId: selectedClientId,
              onClientTap: onClientTap,
            ),
        ],
      ),
    );
  }
}

class _ClientSearchState extends StatelessWidget {
  final IconData? icon;
  final bool isLoading;
  final String message;
  final bool isHighlight;

  const _ClientSearchState({
    this.icon,
    this.isLoading = false,
    required this.message,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHighlight ? AppColors.teal : AppColors.textMuted;
    return Row(
      children: [
        if (isLoading)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(AppColors.teal),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedClientBanner extends StatelessWidget {
  final int saldo;
  final Map<String, dynamic>? creditInfo;
  final bool isCredito;

  const _SelectedClientBanner({
    required this.saldo,
    required this.creditInfo,
    required this.isCredito,
  });

  @override
  Widget build(BuildContext context) {
    if (isCredito && creditInfo != null) {
      final isActive = creditInfo!['is_active'] == true;
      final limit = (creditInfo!['credit_limit'] as num).toDouble();
      final debt = (creditInfo!['current_debt'] as num).toDouble();
      final disponible = (limit - debt).clamp(0.0, double.infinity);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade50 : Colors.red.shade50,
          borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
        ),
        child: Row(
          children: [
            Icon(
              isActive ? Icons.check_circle_rounded : Icons.block_rounded,
              color: isActive ? AppColors.success : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente seleccionado · ${isActive ? "Crédito activo" : "Sin crédito activo"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppColors.success : Colors.red,
                    ),
                  ),
                  if (isActive)
                    Text(
                      'Disponible: S/ ${disponible.toStringAsFixed(2)} de S/ ${limit.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: disponible > 0 ? AppColors.success : Colors.red,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cliente seleccionado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
                if (saldo > 0)
                  Text(
                    '$saldo monedas disponibles',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientMatchesList extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final String? selectedClientId;
  final ClientTapCallback onClientTap;

  const _ClientMatchesList({
    required this.matches,
    required this.selectedClientId,
    required this.onClientTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 2),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: matches.length,
          separatorBuilder:
              (_, _) => const Divider(height: 1, color: AppColors.divider),
          itemBuilder: (context, index) {
            final client = matches[index];
            final name = client['full_name'] as String? ?? 'Cliente';
            final doc = client['document_number'] as String?;
            final phone = client['phone'] as String?;
            final wallet = (client['wallet_balance'] as num?)?.toInt() ?? 0;
            final isSelected = selectedClientId == client['id'];

            return GestureDetector(
              onTap: () => onClientTap(client),
              child: Container(
                color: isSelected ? AppColors.tealLight : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teal : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.teal : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color:
                                  isSelected
                                      ? AppColors.tealDark
                                      : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            [
                              if (doc != null && doc.isNotEmpty) 'Doc: $doc',
                              if (phone != null && phone.isNotEmpty)
                                'Tel: $phone',
                              if (wallet > 0) '$wallet monedas',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.chevron_right_rounded,
                      size: 18,
                      color: isSelected ? AppColors.teal : AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
