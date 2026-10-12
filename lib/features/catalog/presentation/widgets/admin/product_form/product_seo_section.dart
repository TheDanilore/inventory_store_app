import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/product_form/product_form_state.dart';

class ProductSeoSection extends StatefulWidget {
  final TextEditingController? nombreCtrl;
  final TextEditingController? descCtrl;

  const ProductSeoSection({
    super.key,
    this.nombreCtrl,
    this.descCtrl,
  });

  @override
  State<ProductSeoSection> createState() => _ProductSeoSectionState();
}

class _ProductSeoSectionState extends State<ProductSeoSection> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProductFormCubit>();
    _titleCtrl = TextEditingController(text: cubit.state.seoTitle);
    _descCtrl = TextEditingController(text: cubit.state.seoDescription);

    _titleCtrl.addListener(() {
      cubit.setSeoTitle(_titleCtrl.text);
      setState(() {});
    });

    _descCtrl.addListener(() {
      cubit.setSeoDescription(_descCtrl.text);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<ProductFormCubit, ProductFormState>(
      listenWhen: (p, c) =>
          p.seoTitle != c.seoTitle || p.seoDescription != c.seoDescription,
      listener: (context, state) {
        if (_titleCtrl.text != state.seoTitle) {
          _titleCtrl.text = state.seoTitle;
        }
        if (_descCtrl.text != state.seoDescription) {
          _descCtrl.text = state.seoDescription;
        }
      },
      buildWhen: (p, c) =>
          p.slug != c.slug ||
          p.seoTitle != c.seoTitle ||
          p.seoDescription != c.seoDescription,
      builder: (context, state) {
        final slug = state.slug.isNotEmpty ? state.slug : 'audifonos-nova-pro-wireless';
        final fallbackName = widget.nombreCtrl?.text.trim() ?? '';
        final displayTitle = state.seoTitle.isNotEmpty
            ? state.seoTitle
            : (fallbackName.isNotEmpty
                ? '$fallbackName | Tienda Oficial'
                : 'Audífonos Nova Pro Wireless | Tienda Oficial Aura');

        final fallbackDesc = widget.descCtrl?.text.trim() ?? '';
        final displayDesc = state.seoDescription.isNotEmpty
            ? state.seoDescription
            : (fallbackDesc.isNotEmpty
                ? fallbackDesc
                : 'Audífonos inalámbricos de alta definición con cancelación activa de ruido (ANC) híbrida y hasta 55 horas de batería continua.');

        return Container(
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
              // Header del bloque SEO
              Text(
                'OPTIMIZACIÓN PARA BUSCADORES (SEO)',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Personaliza la forma en que los motores de búsqueda como Google indexan esta ficha.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 18),

              // Tarjeta SERP Google Live Preview (Imagen 4)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'VISTA PREVIA DE RESULTADO EN GOOGLE',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // URL verde/teal estilo SERP
                    Text(
                      'https://tienda.com/productos/$slug',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF0D9488), // Verde esmeralda Google
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Título azul cliqueable estilo SERP
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB), // Azul Google Search
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Snippet de descripción
                    Text(
                      displayDesc,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Input Título SEO con contador 48 / 70 caracteres
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Título SEO de la página',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '${_titleCtrl.text.length} / 70 caracteres',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _titleCtrl.text.length > 70
                          ? Colors.red
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleCtrl,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Ingresa un título optimizado para buscadores',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.8,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Input Meta Descripción con contador 125 / 160 caracteres
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Meta Descripción',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    '${_descCtrl.text.length} / 160 caracteres',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: _descCtrl.text.length > 160
                          ? Colors.red
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Breve resumen persuasivo que aparecerá en los resultados de búsqueda',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF6366F1),
                      width: 1.8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
