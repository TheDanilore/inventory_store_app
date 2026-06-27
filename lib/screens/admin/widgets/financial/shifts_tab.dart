import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/cash_shift_model.dart';
import 'package:inventory_store_app/providers/admin/cash_shifts_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/close_shift_sheet.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/open_shift_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/shared/widgets/app_empty_state.dart';

class ShiftsTab extends StatefulWidget {
  const ShiftsTab({super.key});

  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab> {
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended) {
        setState(() => _isFabExtended = false);
      } else if (_scrollController.offset <= 10 && !_isFabExtended) {
        setState(() => _isFabExtended = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CashShiftsProvider>(
      builder: (context, provider, _) {
        final shifts = provider.shifts;
        final isLoading = provider.isLoading;
        final openShifts = shifts.where((s) => s.status == 'OPEN').toList();

        return Stack(
          children: [
            Column(
              children: [
                if (openShifts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      children: openShifts.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ActiveShiftBanner(
                          shift: s,
                          onClose: () async {
                            final expected = await provider.calcExpected(s.id, s.accountId ?? '', s.openingAmount);
                            if (context.mounted) {
                              CloseShiftSheet.show(context, shift: s, expectedAmount: expected);
                            }
                          },
                        ),
                      )).toList(),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, openShifts.isNotEmpty ? 4 : 14, 16, 0),
                  child: Row(
                    children: [
                      _StatusChip(
                        label: 'Abiertos',
                        count: provider.totalOpenCount,
                        color: AppColors.success,
                        selected: provider.filterStatus == 'OPEN',
                        onTap: () {
                          provider.setFilterStatus(provider.filterStatus == 'OPEN' ? 'Todos' : 'OPEN');
                        },
                      ),
                      const SizedBox(width: 6),
                      _StatusChip(
                        label: 'Cerrados',
                        count: provider.totalClosedCount,
                        color: AppColors.textSecondary,
                        selected: provider.filterStatus == 'CLOSED',
                        onTap: () {
                          provider.setFilterStatus(provider.filterStatus == 'CLOSED' ? 'Todos' : 'CLOSED');
                        },
                      ),
                      const Spacer(),
                      DateFilterCalendar(
                        dateRange: provider.dateFrom != null && provider.dateTo != null
                            ? DateTimeRange(start: provider.dateFrom!, end: provider.dateTo!)
                            : null,
                        onDateRangeSelected: (picked) {
                          provider.setDateRange(
                            picked.start,
                            DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                          );
                        },
                        onClear: () {
                          provider.setDateRange(null, null);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: isLoading && shifts.isEmpty
                      ? const _ShiftsSkeleton()
                      : shifts.isEmpty
                          ? const AppEmptyState(icon: Icons.store_rounded, title: 'Sin turnos', message: 'No hay turnos registrados en este período.')
                          : Column(
                              children: [
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh: () async => provider.fetchShifts(),
                                    child: AnimationLimiter(
                                      child: ListView.separated(
                                        controller: _scrollController,
                                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                        itemCount: shifts.length,
                                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                                        itemBuilder: (_, i) => AnimationConfiguration.staggeredList(
                                          position: i,
                                          duration: const Duration(milliseconds: 375),
                                          child: SlideAnimation(
                                            verticalOffset: 50.0,
                                            child: FadeInAnimation(
                                              child: _ShiftCard(
                                                shift: shifts[i],
                                                onClose: shifts[i].status == 'OPEN' ? () async {
                                                  final expected = await provider.calcExpected(shifts[i].id, shifts[i].accountId ?? '', shifts[i].openingAmount);
                                                  if (context.mounted) {
                                                    CloseShiftSheet.show(context, shift: shifts[i], expectedAmount: expected);
                                                  }
                                                } : null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 80), // Keep some padding so last item can be seen above pagination/FAB
                              ],
                            ),
                ),
                // --- PAGINACIÓN ANCLADA ---
                if (provider.totalPages > 1 && !isLoading)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: AdminPageBlocks(
                        currentPage: provider.currentPage,
                        totalPages: provider.totalPages,
                        onPageChanged: (page) => provider.setPage(page),
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_shifts',
                onPressed: isLoading ? null : () {
                  // Solo vibrar si no es web para evitar MissingPluginException
                  if (!kIsWeb) {
                    Vibration.vibrate(duration: 50, amplitude: 128);
                  }
                  final availableAccounts = provider.cajaAccounts.where((a) => !provider.openAccountIds.contains(a.id)).toList();
                  if (availableAccounts.isEmpty) {
                    AppSnackbar.show(context, message: 'Todas las cajas tienen turnos abiertos', type: SnackbarType.warning);
                    return;
                  }
                  OpenShiftSheet.show(context, accounts: availableAccounts);
                },
                backgroundColor: AppColors.success,
                icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                label: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _isFabExtended 
                      ? const Text('Abrir turno', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActiveShiftBanner extends StatefulWidget {
  final CashShiftModel shift;
  final Future<void> Function() onClose;

  const _ActiveShiftBanner({required this.shift, required this.onClose});

  @override
  State<_ActiveShiftBanner> createState() => _ActiveShiftBannerState();
}

class _ActiveShiftBannerState extends State<_ActiveShiftBanner> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.1),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.point_of_sale_rounded, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Turno abierto en:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                Text(widget.shift.accountName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.success)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : () async {
              setState(() => _isLoading = true);
              await widget.onClose();
              if (mounted) setState(() => _isLoading = false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              minimumSize: const Size(0, 36),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isLoading
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.lock_clock_rounded, size: 16),
            label: Text(_isLoading ? 'Cargando' : 'Cerrar', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({required this.label, required this.count, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? color : AppColors.textSecondary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: selected ? color : AppColors.textSecondary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatefulWidget {
  final CashShiftModel shift;
  final Future<void> Function()? onClose;

  const _ShiftCard({required this.shift, this.onClose});

  @override
  State<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends State<_ShiftCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.shift.status == 'OPEN';
    final shift = widget.shift;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: (isOpen ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.point_of_sale_rounded, color: isOpen ? AppColors.success : AppColors.textSecondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(shift.accountName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 12, color: AppColors.success.withValues(alpha: 0.8)),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd MMM HH:mm').format(shift.openedAt), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: (isOpen ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(isOpen ? 'ABIERTO' : 'CERRADO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isOpen ? AppColors.success : AppColors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Apertura', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                      Text('S/ ${shift.openingAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                  ),
                ),
                if (!isOpen) ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cierre', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        Text('S/ ${shift.actualAmount?.toStringAsFixed(2) ?? '0.00'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Diferencia', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                        Text(
                          'S/ ${shift.differenceAmount?.toStringAsFixed(2) ?? '0.00'}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: shift.differenceAmount == null || shift.differenceAmount == 0
                                ? AppColors.success
                                : (shift.differenceAmount! > 0 ? AppColors.success : AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isOpen && widget.onClose != null)
                  ElevatedButton(
                    onPressed: _isLoading ? null : () async {
                      setState(() => _isLoading = true);
                      await widget.onClose!();
                      if (mounted) setState(() => _isLoading = false);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(0, 32),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Cerrar Turno', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _ShiftsSkeleton extends StatelessWidget {
  const _ShiftsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const AppShimmer(width: 40, height: 40, isCircular: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        AppShimmer(width: 140, height: 16),
                        SizedBox(height: 8),
                        AppShimmer(width: 80, height: 12),
                      ],
                    ),
                  ),
                  const AppShimmer(width: 60, height: 24, borderRadius: 6),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  AppShimmer(width: 60, height: 16),
                  AppShimmer(width: 60, height: 16),
                  AppShimmer(width: 60, height: 16),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
