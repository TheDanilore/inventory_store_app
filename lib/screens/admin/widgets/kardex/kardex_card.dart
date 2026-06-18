import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/kardex_movement_model.dart';

class KardexCard extends StatefulWidget {
  final KardexMovementModel item;

  const KardexCard({super.key, required this.item});

  @override
  State<KardexCard> createState() => _KardexCardState();
}

class _KardexCardState extends State<KardexCard> {
  bool _isExpanded = false;

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'Fecha desconocida';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$day/$month/$year  $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  Widget _buildMovementBadge(String type) {
    final upperType = type.toUpperCase();
    bool isEntry = upperType.contains('IN') || upperType.contains('ENTRADA');
    bool isSale =
        upperType.contains('SALE') ||
        upperType.contains('VENTA') ||
        upperType.contains('ORDER');

    Color bgColor = isEntry ? Colors.green.shade50 : Colors.red.shade50;
    Color textColor = isEntry ? Colors.green.shade700 : Colors.red.shade700;
    String label = isEntry ? 'INGRESO' : 'SALIDA';

    if (isSale) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      label = 'VENTA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.item.movement;
    final movementType = widget.item.movementType;

    final iconColor =
        widget.item.isEntry
            ? Colors.green
            : (widget.item.isSale ? Colors.blue : Colors.red);
    final iconData =
        widget.item.isEntry ? Icons.arrow_downward : Icons.arrow_upward;

    final hasDetails =
        (widget.item.referenceId != null) ||
        (move.notes != null && move.notes!.toString().isNotEmpty);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: hasDetails ? _toggleExpand : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDate(move.createdAt?.toIso8601String()),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  _buildMovementBadge(movementType),
                ],
              ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // IMAGEN EN CACHÉ
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child:
                          widget.item.imageUrl != null &&
                                  widget.item.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: widget.item.imageUrl!,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color: Colors.grey.shade50,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color: Colors.grey.shade50,
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 20,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                              )
                              : Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.grey.shade400,
                              ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            height: 1.2,
                          ),
                        ),
                        if (widget.item.attrsText != 'Única') ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.item.attrsText,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                        if (widget.item.usesBatches &&
                            widget.item.batchNumber != 'DEFAULT') ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.tag_rounded,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Lote: ${widget.item.batchNumber}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (widget.item.sku != null &&
                            widget.item.sku!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${widget.item.sku}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.warehouse,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.item.warehouseName,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Cant.',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Row(
                        children: [
                          Icon(iconData, color: iconColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.item.isEntry ? '+' : ''}${move.quantity}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: iconColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Stock: ${move.previousStock} → ${move.newStock}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      if (move.unitCost != null)
                        Text(
                          'Costo: S/ ${move.unitCost}',
                          style: const TextStyle(fontSize: 11),
                        ),
                    ],
                  ),
                ],
              ),
              if (hasDetails) ...[
                const SizedBox(height: 8),
                Center(
                  child: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade400,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child:
                      !_isExpanded
                          ? const SizedBox.shrink()
                          : Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.item.referenceId != null)
                                  Text(
                                    'ID Ref: ${widget.item.referenceId}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: Colors.black54,
                                    ),
                                  ),
                                if (move.notes != null &&
                                    move.notes!.toString().isNotEmpty) ...[
                                  if (widget.item.referenceId != null)
                                    const SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.notes,
                                        size: 14,
                                        color: Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          move.notes ?? '',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade700,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
