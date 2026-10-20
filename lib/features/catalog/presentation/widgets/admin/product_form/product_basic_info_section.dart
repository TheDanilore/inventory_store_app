import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductBasicInfoSection extends StatefulWidget {
  final TextEditingController nombreCtrl;
  final TextEditingController descCtrl;

  const ProductBasicInfoSection({
    super.key,
    required this.nombreCtrl,
    required this.descCtrl,
  });

  @override
  State<ProductBasicInfoSection> createState() =>
      _ProductBasicInfoSectionState();
}

class _ProductBasicInfoSectionState extends State<ProductBasicInfoSection> {
  late final TextEditingController _slugCtrl;
  bool _userEditedSlug = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProductFormCubit>();
    _slugCtrl = TextEditingController(text: cubit.state.slug);

    widget.nombreCtrl.addListener(_onNameChanged);
    _slugCtrl.addListener(_onSlugChanged);
  }

  void _onNameChanged() {
    if (!_userEditedSlug) {
      final cubit = context.read<ProductFormCubit>();
      final generatedSlug = _slugify(widget.nombreCtrl.text);
      if (_slugCtrl.text != generatedSlug) {
        _slugCtrl.text = generatedSlug;
        cubit.setSlug(generatedSlug);
      }
    }
  }

  void _onSlugChanged() {
    final cubit = context.read<ProductFormCubit>();
    if (_slugCtrl.text != cubit.state.slug) {
      cubit.setSlug(_slugCtrl.text);
    }
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàäâã]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöôõ]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'[\s-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  void _applyFormat(String prefix, [String suffix = '']) {
    final text = widget.descCtrl.text;
    final selection = widget.descCtrl.selection;
    if (selection.start < 0 || selection.end < 0) {
      widget.descCtrl.text = '$text$prefix$suffix';
      return;
    }

    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );
    widget.descCtrl.text = newText;
    widget.descCtrl.selection = TextSelection(
      baseOffset: selection.start + prefix.length,
      extentOffset: selection.end + prefix.length,
    );
  }

  @override
  void dispose() {
    widget.nombreCtrl.removeListener(_onNameChanged);
    _slugCtrl.removeListener(_onSlugChanged);
    _slugCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ProductFormCubit>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<ProductFormCubit, ProductFormState>(
      listenWhen: (p, c) => p.slug != c.slug,
      listener: (context, state) {
        if (_slugCtrl.text != state.slug) {
          _slugCtrl.text = state.slug;
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TÍTULO DEL PRODUCTO * (Imagen 5)
            Row(
              children: [
                Text(
                  'TÍTULO DEL PRODUCTO',
                  style: TextStyle(
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: widget.nombreCtrl,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Ej. Audífonos Nova Pro Wireless',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF6366F1),
                    width: 1.8,
                  ),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'El título del producto es obligatorio';
                }
                if (v.trim().length < 2) {
                  return 'El título es muy corto (mín. 2 caracteres)';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // ENLACE PERMANENTE (SLUG) (Imagen 5)
            Text(
              'ENLACE PERMANENTE (SLUG)',
              style: TextStyle(
                fontSize: 12.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w800,
                color:
                    isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                ),
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
              ),
              child: Row(
                children: [
                  // Prefijo de Dominio tienda.com/productos/ (Imagen 5)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(11),
                        bottomLeft: Radius.circular(11),
                      ),
                      border: Border(
                        right: BorderSide(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    child: Text(
                      'tienda.com/productos/',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  // Input Editable del Slug
                  Expanded(
                    child: TextFormField(
                      controller: _slugCtrl,
                      onChanged: (val) {
                        _userEditedSlug = true;
                      },
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'audifonos-nova-pro-wireless',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  // Botón para resetear slug desde el título
                  IconButton(
                    onPressed: () {
                      _userEditedSlug = false;
                      _slugCtrl.text = _slugify(widget.nombreCtrl.text);
                      cubit.setSlug(_slugCtrl.text);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    tooltip: 'Sincronizar slug con el título',
                    splashRadius: 16,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Categoría y Marca en fila responsiva
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 500;

                final categoryField = BlocBuilder<
                  ProductFormCubit,
                  ProductFormState
                >(
                  buildWhen:
                      (p, c) =>
                          p.isLoadingCategories != c.isLoadingCategories ||
                          p.categories != c.categories ||
                          p.selectedCategoryId != c.selectedCategoryId,
                  builder: (context, state) {
                    if (state.isLoadingCategories) {
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    final hasMatchingCategory = state.categories.any(
                      (cat) => cat.id == state.selectedCategoryId,
                    );
                    final effectiveCategoryId =
                        hasMatchingCategory ? state.selectedCategoryId : null;

                    return DropdownButtonFormField<String?>(
                      key: ValueKey(
                        'cat_${effectiveCategoryId}_${state.categories.length}',
                      ),
                      initialValue: effectiveCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        prefixIcon: const Icon(
                          Icons.category_outlined,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Sin categoría'),
                        ),
                        ...state.categories.map(
                          (cat) => DropdownMenuItem<String?>(
                            value: cat.id,
                            child: Text(cat.name),
                          ),
                        ),
                      ],
                      onChanged: cubit.setSelectedCategory,
                    );
                  },
                );

                final brandField =
                    BlocBuilder<ProductFormCubit, ProductFormState>(
                      buildWhen:
                          (p, c) =>
                              p.isLoadingBrands != c.isLoadingBrands ||
                              p.brands != c.brands ||
                              p.selectedBrandId != c.selectedBrandId,
                      builder: (context, state) {
                        if (state.isLoadingBrands) {
                          return const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        final hasMatchingBrand = state.brands.any(
                          (brand) => brand.id == state.selectedBrandId,
                        );
                        final effectiveBrandId =
                            hasMatchingBrand ? state.selectedBrandId : null;

                        return DropdownButtonFormField<String?>(
                          key: ValueKey(
                            'brand_${effectiveBrandId}_${state.brands.length}',
                          ),
                          initialValue: effectiveBrandId,
                          decoration: InputDecoration(
                            labelText: 'Marca / Fabricante',
                            prefixIcon: const Icon(
                              Icons.verified_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFCBD5E1),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin marca'),
                            ),
                            ...state.brands.map(
                              (brand) => DropdownMenuItem<String?>(
                                value: brand.id,
                                child: Text(brand.name),
                              ),
                            ),
                          ],
                          onChanged: cubit.setSelectedBrand,
                        );
                      },
                    );

                if (isWide) {
                  return Row(
                    children: [
                      Expanded(child: categoryField),
                      const SizedBox(width: 16),
                      Expanded(child: brandField),
                    ],
                  );
                }

                return Column(
                  children: [
                    categoryField,
                    const SizedBox(height: 16),
                    brandField,
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // DESCRIPCIÓN DETALLADA con Barra de Formato (Imagen 5)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DESCRIPCIÓN DETALLADA',
                  style: TextStyle(
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w800,
                    color:
                        isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  'Soporta HTML & Markdown',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color:
                        isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Contenedor enriquecido con Toolbar + Textarea (Imagen 5)
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1),
                ),
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
              ),
              child: Column(
                children: [
                  // Toolbar de formato según Imagen 5: B, I, U, |, Listas, |, Link, Clear
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(13),
                        topRight: Radius.circular(13),
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color:
                              isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _ToolbarButton(
                          label: 'B',
                          isBold: true,
                          tooltip: 'Negrita (**texto**)',
                          onTap: () => _applyFormat('**', '**'),
                        ),
                        _ToolbarButton(
                          label: 'I',
                          isItalic: true,
                          tooltip: 'Cursiva (*texto*)',
                          onTap: () => _applyFormat('*', '*'),
                        ),
                        _ToolbarButton(
                          label: 'U',
                          isUnderline: true,
                          tooltip: 'Subrayado (<u>texto</u>)',
                          onTap: () => _applyFormat('<u>', '</u>'),
                        ),
                        const _ToolbarDivider(),
                        _ToolbarIconButton(
                          icon: Icons.format_list_bulleted_rounded,
                          tooltip: 'Lista de viñetas',
                          onTap: () => _applyFormat('\n• '),
                        ),
                        _ToolbarIconButton(
                          icon: Icons.format_list_numbered_rounded,
                          tooltip: 'Lista numerada',
                          onTap: () => _applyFormat('\n1. '),
                        ),
                        const _ToolbarDivider(),
                        _ToolbarIconButton(
                          icon: Icons.link_rounded,
                          tooltip: 'Insertar enlace',
                          onTap: () => _applyFormat('[', '](https://)'),
                        ),
                        const Spacer(),
                        _ToolbarIconButton(
                          icon: Icons.cleaning_services_outlined,
                          tooltip: 'Limpiar formato',
                          onTap: () {
                            widget.descCtrl.text = widget.descCtrl.text
                                .replaceAll('*', '')
                                .replaceAll('<u>', '')
                                .replaceAll('</u>', '');
                          },
                        ),
                      ],
                    ),
                  ),

                  // Campo Multilínea de Descripción
                  TextFormField(
                    controller: widget.descCtrl,
                    maxLines: 5,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Describe las características principales, dimensiones, compatibilidad o especificaciones...',
                      contentPadding: EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.label,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              decoration:
                  isUnderline ? TextDecoration.underline : TextDecoration.none,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 17, color: const Color(0xFF475569)),
        ),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  const _ToolbarDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: const Color(0xFFCBD5E1),
    );
  }
}
