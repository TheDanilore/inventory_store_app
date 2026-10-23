import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/network/network_cubit.dart';
import 'package:inventory_store_app/core/network/network_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centro de Ayuda, Documentación y Soporte del ERP.
///
/// Mejoras de UI/UX respecto a la versión anterior:
///  • Responsive real (móvil / tablet / desktop): ya no se rompe el título.
///  • Modo oscuro completo (antes todo estaba hardcodeado en colores claros).
///  • Header colapsable: el hero se oculta al hacer scroll y solo queda fija
///    la barra de pestañas → más espacio para leer el contenido.
///  • Buscador funcional (antes `_searchQuery` no se usaba) con búsqueda
///    sin tildes, resultados agrupados y chips de búsquedas frecuentes.
///  • Timeline vertical para flujos, FAQ en acordeón, atajos como keycaps,
///    tablas que se convierten en tarjetas en pantallas angostas.
class AdminHelpScreen extends StatefulWidget {
  const AdminHelpScreen({super.key});

  @override
  State<AdminHelpScreen> createState() => _AdminHelpScreenState();
}

// ═════════════════════════════════════════════════════════════════════════════
// MODELO DE CONTENIDO (permite buscar en todas las pestañas)
// ═════════════════════════════════════════════════════════════════════════════
class _HelpTab {
  const _HelpTab(this.label, this.icon, this.groups);
  final String label;
  final IconData icon;
  final List<_Group> groups;
}

class _Group {
  const _Group({
    this.title,
    this.subtitle,
    this.columns = 1,
    required this.items,
  });
  final String? title;
  final String? subtitle;
  final int columns; // columnas en pantallas anchas
  final List<_Item> items;
}

class _Item {
  const _Item(this.text, this.child);
  final String text; // texto indexable para el buscador
  final Widget child;
}

class _Hit {
  const _Hit(this.tabIndex, this.group, this.items);
  final int tabIndex;
  final _Group group;
  final List<_Item> items;
}

// ═════════════════════════════════════════════════════════════════════════════
// TOKENS DE DISEÑO (claro / oscuro) – reutiliza AppColors
// ═════════════════════════════════════════════════════════════════════════════
class _T {
  _T({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.field,
    required this.border,
    required this.strongBorder,
    required this.title,
    required this.body,
    required this.muted,
    required this.accent,
    required this.primaryBtn,
  });

  final bool dark;
  final Color bg;
  final Color surface;
  final Color field;
  final Color border;
  final Color strongBorder;
  final Color title;
  final Color body;
  final Color muted;
  final Color accent;
  final Color primaryBtn;

  factory _T.of(BuildContext context) {
    final dark = AppColors.isDark(context);
    return _T(
      dark: dark,
      bg: AppColors.bg(context),
      surface: AppColors.surf(context),
      field: dark ? AppColors.darkBackground : AppColors.surfaceDark,
      border: AppColors.brd(context),
      strongBorder: dark ? AppColors.darkBorderSubtle : const Color(0xFFCBD5E1),
      title: AppColors.txtPrimary(context),
      body: dark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      muted: AppColors.txtSecondary(context),
      accent: dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      primaryBtn: dark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB),
    );
  }

  /// Aclara un color semántico para que tenga buen contraste en modo oscuro.
  Color tone(Color c) => dark ? Color.lerp(c, Colors.white, 0.45)! : c;

  List<BoxShadow>? get shadow =>
      dark ? null : AppColors.cardShadow(opacity: 0.03);
}

// ═════════════════════════════════════════════════════════════════════════════
// STATE
// ═════════════════════════════════════════════════════════════════════════════
class _AdminHelpScreenState extends State<AdminHelpScreen>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 8;

  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // Colores semánticos
  static const _green = Color(0xFF059669);
  static const _blue = Color(0xFF2563EB);
  static const _purple = Color(0xFF7C3AED);

  // Diagnóstico en tiempo real
  String _appVersion = 'Cargando...';
  String _buildNumber = '';
  int? _latencyMs;
  bool _measuringLatency = false;
  Timer? _latencyTimer;
  bool _supabaseReachable = true;

  _T get _t => _T.of(context);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _loadDiagnostics();
    _latencyTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _searchQuery.isEmpty) {
        _measureLatency();
      }
    });
  }

  @override
  void dispose() {
    _latencyTimer?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDiagnostics() async {
    await _loadAppVersion();
    await _measureLatency();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appVersion = 'Desconocida';
        _buildNumber = '';
      });
    }
  }

  Future<void> _measureLatency() async {
    if (_measuringLatency) return;
    setState(() => _measuringLatency = true);
    try {
      final stopwatch = Stopwatch()..start();
      // Ping ligero a Supabase para medir latencia real
      await Supabase.instance.client
          .from('app_settings')
          .select('key')
          .limit(1)
          .timeout(const Duration(seconds: 5));
      stopwatch.stop();
      if (!mounted) return;
      setState(() {
        _latencyMs = stopwatch.elapsedMilliseconds;
        _supabaseReachable = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _latencyMs = null;
        _supabaseReachable = false;
      });
    } finally {
      if (mounted) {
        setState(() => _measuringLatency = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    AppSnackbar.show(
      context,
      message: '$label copiado al portapapeles',
      type: SnackbarType.info,
    );
  }

  void _setQuery(String value) {
    setState(() => _searchQuery = value.trim());
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _searchQuery = '');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BÚSQUEDA
  // ───────────────────────────────────────────────────────────────────────────
  String _norm(String s) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñ';
    const to = 'aaaaeeeeiiiioooouuuun';
    var out = s.toLowerCase();
    for (var i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  List<String> _searchTokens() {
    final q = _searchQuery.trim();
    if (q.isEmpty) return const [];
    return _norm(
      q,
    ).split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toSet().toList();
  }

  List<TextSpan> _highlightSpans(String text, TextStyle baseStyle) {
    final tokens = _searchTokens();
    if (tokens.isEmpty) return [TextSpan(text: text, style: baseStyle)];
    final t = _t;
    final normalizedText = _norm(text);
    final spans = <TextSpan>[];
    var index = 0;
    while (index < text.length) {
      int? nextMatchIndex;
      String? matchedToken;
      for (final token in tokens) {
        final matchIndex = normalizedText.indexOf(token, index);
        if (matchIndex == -1) continue;
        if (nextMatchIndex == null || matchIndex < nextMatchIndex) {
          nextMatchIndex = matchIndex;
          matchedToken = token;
        } else if (matchIndex == nextMatchIndex && matchedToken != null) {
          if (token.length > matchedToken.length) {
            matchedToken = token;
          }
        }
      }
      if (nextMatchIndex == null || matchedToken == null) {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }
      if (nextMatchIndex > index) {
        spans.add(
          TextSpan(
            text: text.substring(index, nextMatchIndex),
            style: baseStyle,
          ),
        );
        index = nextMatchIndex;
        continue;
      }
      final matchLength = matchedToken.length;
      if (index + matchLength <= text.length) {
        final matchText = text.substring(index, index + matchLength);
        spans.add(
          TextSpan(
            text: matchText,
            style: baseStyle.copyWith(
              backgroundColor: t.accent.withValues(alpha: t.dark ? 0.22 : 0.16),
              color: t.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
        index += matchLength;
      } else {
        spans.add(TextSpan(text: text.substring(index), style: baseStyle));
        break;
      }
    }
    return spans;
  }

  Widget _highlightedText(
    String text, {
    TextStyle? style,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final tokens = _searchTokens();
    if (tokens.isEmpty) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final baseStyle = style ?? TextStyle(fontSize: 13, color: _t.body);
    return RichText(
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(children: _highlightSpans(text, baseStyle)),
    );
  }

  List<_Hit> _search(List<_HelpTab> tabs) {
    final tokens = _searchTokens();
    final hits = <_Hit>[];
    for (var ti = 0; ti < tabs.length; ti++) {
      for (final g in tabs[ti].groups) {
        final groupText = _norm(g.title ?? '');
        final matched =
            g.items.where((it) {
              final hay = '$groupText ${_norm(it.text)}';
              return tokens.every((tk) => hay.contains(tk));
            }).toList();
        if (matched.isNotEmpty) hits.add(_Hit(ti, g, matched));
      }
    }
    return hits;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // BUILD
  // ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = _t;
    final tabs = _buildTabs();
    final searching = _searchQuery.isNotEmpty;
    final hits = searching ? _search(tabs) : const <_Hit>[];
    final total = hits.fold<int>(0, (sum, h) => sum + h.items.length);

    return AdminLayout(
      title: 'Ayuda y Soporte',
      breadcrumb: 'ERP > Ayuda y Documentación',
      body: ColoredBox(
        color: t.bg,
        child: NestedScrollView(
          // El hero se va con el scroll; solo la barra de pestañas queda fija.
          headerSliverBuilder:
              (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(child: _hero()),
              ],
          body: Column(
            children: [
              _navBar(tabs, searching, total),
              Expanded(
                child:
                    searching
                        ? _resultsView(tabs, hits)
                        : TabBarView(
                          controller: _tabController,
                          children: [
                            for (var i = 0; i < tabs.length; i++)
                              _tabBody(i, tabs[i]),
                          ],
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _hero() {
    final t = _t;
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 760;
        final pad = narrow ? 16.0 : 24.0;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centro de Ayuda, Documentación y Operaciones',
              style: TextStyle(
                fontSize: narrow ? 18 : 21,
                fontWeight: FontWeight.w700,
                color: t.title,
                letterSpacing: -0.4,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Guías completas del sistema: arquitectura de cajas y mostradores, roles, comprobantes y atajos.',
              style: TextStyle(fontSize: 13.5, color: t.muted, height: 1.4),
            ),
          ],
        );

        return Container(
          color: t.surface,
          padding: EdgeInsets.fromLTRB(pad, narrow ? 16 : 22, pad, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (narrow) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heroIcon(44),
                    const SizedBox(width: 12),
                    Expanded(child: titleBlock),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _posButton()),
                    const SizedBox(width: 8),
                    Expanded(child: _diagButton(short: true)),
                  ],
                ),
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _heroIcon(52),
                    const SizedBox(width: 16),
                    Expanded(child: titleBlock),
                    const SizedBox(width: 16),
                    _posButton(),
                    const SizedBox(width: 8),
                    _diagButton(),
                  ],
                ),
              const SizedBox(height: 16),
              _searchField(),
              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 12),
                _quickChips(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _heroIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white,
        size: size * 0.5,
      ),
    );
  }

  Widget _posButton() {
    final t = _t;
    final color = t.tone(AppColors.teal);
    return OutlinedButton.icon(
      onPressed: () => context.go('/pos'),
      icon: const Icon(Icons.point_of_sale_rounded, size: 17),
      label: const Text('Ir al POS', maxLines: 1),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.6)),
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _diagButton({bool short = false}) {
    final t = _t;
    return FilledButton.icon(
      onPressed:
          () => _copyToClipboard(
            'DANILORE ONE ERP v1.4.2 | Build 2026.10 | Multi-Warehouse POS & Cloud Sync Enabled',
            'Diagnóstico del sistema',
          ),
      icon: const Icon(Icons.copy_rounded, size: 16),
      label: Text(short ? 'Diagnóstico' : 'Copiar Diagnóstico', maxLines: 1),
      style: FilledButton.styleFrom(
        backgroundColor: t.primaryBtn,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _searchField() {
    final t = _t;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      controller: _searchCtrl,
      onChanged: _setQuery,
      style: TextStyle(fontSize: 14, color: t.title),
      decoration: InputDecoration(
        hintText: 'Buscar en las guías: turnos, Yape, IGV, permisos…',
        hintStyle: TextStyle(fontSize: 13.5, color: t.muted),
        filled: true,
        fillColor: t.field,
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: t.muted),
        suffixIcon:
            _searchQuery.isNotEmpty
                ? IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: Icon(Icons.close_rounded, size: 18, color: t.muted),
                  onPressed: _clearSearch,
                )
                : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: border(t.border),
        enabledBorder: border(t.border),
        focusedBorder: border(t.accent, 1.5),
      ),
    );
  }

  Widget _quickChips() {
    final t = _t;
    const topics = [
      ('Turnos', 'turno'),
      ('Yape y Plin', 'yape'),
      ('IGV', 'igv'),
      ('Permisos', 'permisos'),
      ('Factura', 'factura'),
      ('Lotes', 'lotes'),
      ('Atajos', 'atajos'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Frecuentes',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.muted,
          ),
        ),
        for (final topic in topics)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                _searchCtrl.text = topic.$2;
                _setQuery(topic.$2);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: t.border),
                ),
                child: Text(
                  topic.$1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: t.body,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BARRA DE PESTAÑAS / RESULTADOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _navBar(List<_HelpTab> tabs, bool searching, int total) {
    final t = _t;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(
          top: BorderSide(color: t.border),
          bottom: BorderSide(color: t.border),
        ),
      ),
      child:
          searching
              ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 17, color: t.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$total ${total == 1 ? 'resultado' : 'resultados'} para “$_searchQuery”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.title,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _clearSearch,
                      child: Text(
                        'Limpiar',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: t.accent,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                labelColor: t.accent,
                unselectedLabelColor: t.muted,
                labelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                indicatorColor: t.accent,
                indicatorWeight: 2.5,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                splashBorderRadius: BorderRadius.circular(8),
                tabs: [
                  for (final tab in tabs)
                    Tab(
                      height: 46,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(tab.icon, size: 17),
                          const SizedBox(width: 8),
                          Text(tab.label),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CUERPO: PESTAÑA / RESULTADOS
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _pageList({Key? key, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, c) {
        final pad = c.maxWidth >= 720 ? 24.0 : 16.0;
        return ListView(
          key: key,
          padding: EdgeInsets.fromLTRB(pad, 24, pad, 48),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tabBody(int index, _HelpTab tab) {
    return _pageList(
      key: PageStorageKey<String>('help_tab_$index'),
      children: _spaced([
        for (final g in tab.groups) _groupView(g, g.items),
      ], 32),
    );
  }

  Widget _resultsView(List<_HelpTab> tabs, List<_Hit> hits) {
    final t = _t;
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 44, color: t.muted),
              const SizedBox(height: 12),
              Text(
                'Sin resultados para “$_searchQuery”',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: t.title,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Prueba con otra palabra clave (ej. “turno”, “yape”, “factura”).',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: t.muted),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _clearSearch,
                child: const Text('Ver toda la ayuda'),
              ),
            ],
          ),
        ),
      );
    }

    return _pageList(
      key: const PageStorageKey<String>('help_search'),
      children: _spaced([
        for (final h in hits)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tabLink(tabs[h.tabIndex], h.tabIndex),
              const SizedBox(height: 12),
              _groupView(h.group, h.items),
            ],
          ),
      ], 32),
    );
  }

  Widget _tabLink(_HelpTab tab, int index) {
    final t = _t;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          _clearSearch();
          _tabController.animateTo(index);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tab.icon, size: 14, color: t.accent),
              const SizedBox(width: 6),
              Text(
                tab.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: t.accent,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 16, color: t.accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupView(_Group g, List<_Item> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (g.title != null) ...[
          _sectionHeader(g.title!, g.subtitle),
          const SizedBox(height: 14),
        ],
        _grid(items.map((e) => e.child).toList(), g.columns),
      ],
    );
  }

  /// Distribuye items en N columnas con altura igual por fila (≥720px),
  /// o en una sola columna en pantallas angostas.
  Widget _grid(List<Widget> kids, int columns) {
    if (kids.length == 1 || columns == 1) {
      return Column(children: _spaced(kids, 12));
    }
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 720 ? columns : 1;
        if (cols == 1) return Column(children: _spaced(kids, 12));
        final rows = <Widget>[];
        for (var i = 0; i < kids.length; i += cols) {
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: 12),
                    Expanded(
                      child:
                          i + j < kids.length ? kids[i + j] : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: _spaced(rows, 12));
      },
    );
  }

  List<Widget> _spaced(List<Widget> items, double gap) => [
    for (var i = 0; i < items.length; i++) ...[
      if (i > 0) SizedBox(height: gap),
      items[i],
    ],
  ];

  _Item _i(String text, Widget child) => _Item(text, child);

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTENIDO (pestañas)
  // ═══════════════════════════════════════════════════════════════════════════
  List<_HelpTab> _buildTabs() => [
    _cajasTab(),
    _posTab(),
    _rolesTab(),
    _invoicingTab(),
    _financesTab(),
    _inventoryTab(),
    _shortcutsTab(),
    _diagnosticsTab(),
  ];

  // ── TAB 1: CAJAS ──────────────────────────────────────────────────────────
  _HelpTab _cajasTab() {
    const calloutTitle =
        'Arquitectura de Cajas: ¿Puede haber más de una caja por tienda?';
    const calloutBody =
        'Cada Almacén o Tienda física representa la sede central donde vive el inventario. Dentro de esa misma tienda física pueden operar múltiples Cajas o Mostradores (ej: Mostrador 1, Mostrador 2, Caja Rápida, etc.). Cada cajero opera en su respectiva terminal con su propio Turno de Caja independiente.';

    return _HelpTab('Cajas y Mostradores', Icons.point_of_sale_rounded, [
      _Group(
        items: [
          _i(
            '$calloutTitle $calloutBody',
            _callout(
              title: calloutTitle,
              lead: '¡SÍ, TOTALMENTE!',
              content: calloutBody,
              icon: Icons.lightbulb_rounded,
              color: _blue,
            ),
          ),
        ],
      ),
      _Group(
        title: 'Jerarquía del Sistema',
        subtitle:
            'Comprende la relación entre Tienda (Almacén), Mostrador (Caja) y Turno (Sesión del Cajero)',
        columns: 3,
        items: [
          _i(
            'Nivel 1 Tienda Almacén establecimiento sucursal stock compras transferencias',
            _hierarchyCard(
              badge: 'NIVEL 1',
              title: 'Tienda / Almacén',
              desc:
                  'Establecimiento o sucursal física. Administra el stock real, las compras recibidas y las transferencias de inventario.',
              icon: Icons.apartment_rounded,
              color: _green,
            ),
          ),
          _i(
            'Nivel 2 Caja Mostrador terminal atención cajas activas',
            _hierarchyCard(
              badge: 'NIVEL 2',
              title: 'Caja / Mostrador',
              desc:
                  'Terminal físico de atención (ej. Caja 1, Caja 2). Una tienda puede tener 1, 2 o más cajas activas simultáneamente.',
              icon: Icons.computer_rounded,
              color: _blue,
            ),
          ),
          _i(
            'Nivel 3 Turno de Caja sesión cajero fondo inicial cobros efectivo digitales arqueo cierre',
            _hierarchyCard(
              badge: 'NIVEL 3',
              title: 'Turno de Caja',
              desc:
                  'Sesión de trabajo del cajero con fondo inicial, registro de cobros en efectivo/digitales, arqueo y cierre diario.',
              icon: Icons.access_time_filled_rounded,
              color: _purple,
            ),
          ),
        ],
      ),
      _Group(
        title: 'Flujo de Vida del Turno de Caja',
        subtitle:
            'Ciclo obligatorio para garantizar cuadre exacto de dinero y cero pérdidas en el negocio',
        items: [
          _i(
            'apertura turno fondo base sencillo operaciones cobros yape plin tarjeta egresos retiros arqueo cierre faltante sobrante',
            _stepFlow([
              (
                '1',
                'Apertura de Turno con Fondo Base',
                'Al iniciar la jornada, el cajero ingresa el monto de sencillo en efectivo (ej. S/ 100.00). El sistema congela la hora y usuario de apertura.',
              ),
              (
                '2',
                'Operaciones y Cobros Continuos',
                'Cada venta en efectivo suma a la gaveta de la caja activa. Las ventas con Yape, Plin o Tarjeta se registran con su código de operación en la cuenta bancaria.',
              ),
              (
                '3',
                'Egresos / Retiros de Caja Autorizados',
                'Si se retira dinero para compras de suministros, cambio o pagos a proveedores, se registra un movimiento de egreso con motivo para no descuadrar la caja.',
              ),
              (
                '4',
                'Arqueo y Cierre de Turno',
                'Al finalizar el horario, se cuenta el dinero físico presente. El sistema compara: Fondo Inicial + Ventas Efectivo − Retiros = Total Esperado. Calcula si existe faltante o sobrante.',
              ),
            ]),
          ),
        ],
      ),
      _Group(
        title: 'Preguntas frecuentes',
        subtitle: 'Dudas comunes sobre turnos y cajeros',
        items: [
          _i(
            'dos cajeros mismo turno misma tienda rotación',
            _faq(
              '¿Qué pasa si dos cajeros trabajan en el mismo turno o misma tienda?',
              'Lo óptimo es que cada cajero tenga su propio turno abierto en su respectiva caja/mostrador. Si comparten el mismo mostrador por rotación de turno, el cajero saliente debe cerrar su turno con su arqueo y el nuevo cajero debe abrir un nuevo turno con el dinero que recibe.',
            ),
          ),
          _i(
            'método de pago efectivo turno abierto seguridad contable',
            _faq(
              '¿Por qué el método de pago Efectivo solo aparece si hay un turno abierto?',
              'Por seguridad contable. El dinero en efectivo necesita una gaveta física y un responsable activo. Si no hay turno abierto, el sistema impide cobros en efectivo para evitar dinero no trazable.',
            ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 2: POS ────────────────────────────────────────────────────────────
  _HelpTab _posTab() {
    const cTitle = 'Filosofía del POS: Velocidad Extrema y Teclado';
    const cBody =
        'El Punto de Venta está optimizado para operar en milisegundos con lectores de código de barras USB/Bluetooth o mediante teclado directo sin necesidad de usar el mouse.';
    return _HelpTab('Punto de Venta (POS)', Icons.storefront_rounded, [
      _Group(
        items: [
          _i(
            '$cTitle $cBody',
            _callout(
              title: cTitle,
              content: cBody,
              icon: Icons.bolt_rounded,
              color: const Color(0xFF047857),
            ),
          ),
        ],
      ),
      _Group(
        title: 'Flujo de Venta Rápida en 4 Pasos',
        subtitle: 'Cómo realizar una venta completa en menos de 10 segundos',
        items: [
          _i(
            'venta rápida carrito productos lector código de barras cliente dni ruc comprobante nota de venta boleta factura efectivo yape plin banco f2 cobrar ticket',
            _stepFlow([
              (
                '1',
                'Agregar Productos al Carrito',
                'Pasa el lector de código de barras o presiona "/" para buscar por nombre o SKU. Puedes ajustar cantidades directamente.',
              ),
              (
                '2',
                'Seleccionar Cliente o Dejar en Mostrador',
                'Por defecto se vende a "Cliente General". Si el cliente desea acumular monedas o factura, presiona "Alt + C" para buscar su DNI o RUC.',
              ),
              (
                '3',
                'Elegir Comprobante y Método de Pago',
                'Selecciona Nota de Venta, Boleta o Factura. Elige Efectivo, Yape, Plin o Banco. Si es transferencia, ingresa el Nº de Operación.',
              ),
              (
                '4',
                'Presionar F2 (Cobrar)',
                'El sistema registra la venta, descuenta el stock del almacén en tiempo real, suma puntos de fidelización si aplica e imprime el ticket.',
              ),
            ]),
          ),
        ],
      ),
      _Group(
        title: 'Manejo de Pedidos en Borrador (Alt + B)',
        subtitle: 'Ideal para clientes indecisos en la fila',
        columns: 2,
        items: [
          _i(
            'guardar carrito borrador alt b cola historial',
            _infoTile(
              icon: Icons.bookmark_added_outlined,
              title: 'Guardar Carrito como Borrador',
              desc:
                  'Si un cliente en la cola necesita agregar más cosas, presiona "Borrador" (Alt + B). El carrito se limpia para atender al siguiente cliente y podrás retomar el pedido pendiente más tarde desde el historial.',
            ),
          ),
          _i(
            'limpieza automática campos voucher descuentos operación',
            _infoTile(
              icon: Icons.cleaning_services_rounded,
              title: 'Limpieza Automática de Campos',
              desc:
                  'Al finalizar cada venta, el Nº de operación / voucher y los descuentos se resetean automáticamente para evitar que el siguiente cliente herede datos de la venta anterior.',
            ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 3: ROLES ──────────────────────────────────────────────────────────
  _HelpTab _rolesTab() {
    const cTitle = 'Sistema Basado en Permisos Granulares (RBAC)';
    const cBody =
        'En DANILORE ONE los accesos no están atados rígidamente a nombres fijos, sino a una matriz de permisos directos. Puedes definir exactamente qué puede ver o editar cada colaborador.';
    const headers = [
      'Característica',
      'Entorno POS (Cajeros)',
      'Entorno ERP (Administración)',
    ];
    const rows = [
      [
        'Interfaz',
        'Pantalla completa limpia, modo mostrador',
        'Barra lateral, dashboard, maestros y reportes',
      ],
      [
        'Permiso Clave',
        'pos.access (Acceso a Terminal POS)',
        'erp.access (Acceso al Panel Administrativo)',
      ],
      [
        'Usuario POS-Only',
        'Si no tiene erp.access, jamás ve menú ERP',
        'Si tiene ambos, puede alternar libremente',
      ],
      [
        'Funciones',
        'Turnos, cobros, tickets, búsqueda de stock',
        'Configuraciones, finanzas, costos, compras, roles',
      ],
    ];

    return _HelpTab('Roles y Permisos', Icons.shield_outlined, [
      _Group(
        items: [
          _i(
            '$cTitle $cBody',
            _callout(
              title: cTitle,
              content: cBody,
              icon: Icons.admin_panel_settings_rounded,
              color: const Color(0xFF6D28D9),
            ),
          ),
        ],
      ),
      _Group(
        title: 'Acceso Exclusivo al POS vs Acceso al ERP',
        subtitle:
            'Separación de entornos para cajeros y personal administrativo',
        items: [
          _i(
            [...headers, ...rows.expand((r) => r)].join(' '),
            _comparison(headers: headers, rows: rows),
          ),
        ],
      ),
      _Group(
        title: 'Matriz de Roles Predefinidos en el Sistema',
        subtitle:
            'Puedes crear nuevos roles o ajustar los existentes en Configuración > Roles',
        columns: 2,
        items: [
          _i(
            'administrador admin acceso total monedas sucursales permisos ganancias anular',
            _roleCard(
              role: 'Administrador',
              code: 'admin',
              desc:
                  'Acceso total e irrestricto. Puede configurar monedas, sucursales, asignar permisos, ver ganancias y anular operaciones.',
              color: const Color(0xFFDC2626),
              icon: Icons.shield_rounded,
            ),
          ),
          _i(
            'cajero cashier pos turnos cobros tickets mostrador',
            _roleCard(
              role: 'Cajero',
              code: 'cashier',
              desc:
                  'Enfocado en POS. Abre/cierra turnos, registra cobros, emite tickets. Por seguridad, solo ingresa a su mostrador.',
              color: const Color(0xFF0284C7),
              icon: Icons.point_of_sale_rounded,
            ),
          ),
          _i(
            'encargado de almacén warehouse keeper inventario recepción órdenes de compra kardex lotes vencimiento',
            _roleCard(
              role: 'Encargado de Almacén',
              code: 'warehouse_keeper',
              desc:
                  'Control de inventario, recepción de órdenes de compra, kardex, registro de lotes y fechas de vencimiento.',
              color: const Color(0xFFD97706),
              icon: Icons.inventory_2_rounded,
            ),
          ),
          _i(
            'empleado general employee atención al cliente catálogo precios stock',
            _roleCard(
              role: 'Empleado General',
              code: 'employee',
              desc:
                  'Atención al cliente, consulta de catálogo, precios y stock sin permisos de configuración administrativa.',
              color: const Color(0xFF64748B),
              icon: Icons.person_rounded,
            ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 4: COMPROBANTES ───────────────────────────────────────────────────
  _HelpTab _invoicingTab() {
    const cTitle = 'Tipos de Comprobantes Emitidos';
    const cBody =
        'Cada venta genera un comprobante con serie y correlativo auditado. El detalle de la venta desglosa la Base Imponible (Op. Gravada) y el I.G.V. (18%).';
    return _HelpTab('Comprobantes y SUNAT', Icons.receipt_long_rounded, [
      _Group(
        items: [
          _i(
            '$cTitle $cBody',
            _callout(
              title: cTitle,
              content: cBody,
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF0F766E),
            ),
          ),
        ],
      ),
      _Group(
        title: 'Guía de Comprobantes de Pago',
        subtitle: 'Cuándo utilizar Nota de Venta, Boleta o Factura',
        items: [
          _i(
            'nota de venta comprobante interno mostrador descuenta existencias dni ruc',
            _docTypeCard(
              title: 'Nota de Venta',
              series: 'NV01-00000001',
              badge: 'COMPROBANTE INTERNO',
              color: const Color(0xFF047857),
              desc:
                  'Comprobante interno para mostrador. Descuenta existencias del almacén y registra el ingreso a caja sin requerir validación tributaria directa. Ideal para operaciones rápidas al público general.',
              requirements: const [
                'No requiere DNI ni RUC obligatorio',
                'Descuenta inventario en tiempo real',
                'Afecta caja y cuentas financieras',
              ],
            ),
          ),
          _i(
            'boleta de venta consumidor final dni igv 18 cliente varios',
            _docTypeCard(
              title: 'Boleta de Venta',
              series: 'B001-00000001',
              badge: 'CONSUMIDOR FINAL',
              color: const Color(0xFF1D4ED8),
              desc:
                  'Comprobante legal para personas naturales. Desglosa Base Imponible e IGV del 18%. Se puede emitir con DNI del comprador o como Cliente Varios.',
              requirements: const [
                'DNI obligatorio para ventas mayores a montos de ley',
                'Desglose de IGV 18% incluido en el total',
              ],
            ),
          ),
          _i(
            'factura electrónica crédito fiscal ruc razón social dirección fiscal sunat empresas',
            _docTypeCard(
              title: 'Factura Electrónica',
              series: 'F001-00000001',
              badge: 'CRÉDITO FISCAL',
              color: const Color(0xFF7E22CE),
              desc:
                  'Comprobante tributario para empresas. Otorga derecho a crédito fiscal y costo/gasto.',
              requirements: const [
                'RUC de 11 dígitos válido ante SUNAT',
                'Razón Social completa',
                'Dirección Fiscal obligatoria',
              ],
            ),
          ),
        ],
      ),
      _Group(
        title: 'Nº de Operación / Voucher',
        subtitle:
            'Trazabilidad de transferencias digitales (Yape, Plin, Tarjeta) · campo payment_reference',
        items: [
          _i(
            'código de operación voucher yape plin transferencia bancaria detalle del pedido payment_reference',
            _infoTile(
              icon: Icons.tag_rounded,
              title: '¿Por qué es crucial registrar el código de operación?',
              desc:
                  'Al cobrar con Yape o Plin, la app de tu teléfono genera un código numérico (ej. "33333"). Ingresarlo en la caja permite que en Administración y en el Detalle del Pedido se verifique de inmediato si la transferencia bancaria coincide con el pedido físico.',
            ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 5: FINANZAS ───────────────────────────────────────────────────────
  _HelpTab _financesTab() {
    return _HelpTab('Finanzas y Pagos', Icons.account_balance_wallet_outlined, [
      _Group(
        title: 'Cuentas Financieras del Negocio',
        subtitle: 'Configuradas en ERP > Finanzas > Cuentas Financieras',
        items: [
          _i(
            'cuenta caja principal efectivo billetes monedas turnos auditorías cuadres',
            _infoTile(
              icon: Icons.payments_rounded,
              title: 'Cuenta Caja Principal (Efectivo)',
              desc:
                  'Representa el dinero físico en billetes y monedas. Está vinculada a los turnos de caja para auditorías y cuadres de fin de día.',
            ),
          ),
          _i(
            'cuentas bancarias billeteras digitales bcp bbva interbank yape plin',
            _infoTile(
              icon: Icons.account_balance_rounded,
              title: 'Cuentas Bancarias y Billeteras Digitales',
              desc:
                  'Cuentas de BCP, BBVA, Interbank, Yape y Plin. El dinero de estas ventas no entra a la gaveta física, sino directo a la cuenta de la empresa.',
            ),
          ),
          _i(
            'ventas a crédito cuentas por cobrar saldo pendiente amortizaciones abonos deuda',
            _infoTile(
              icon: Icons.handshake_rounded,
              title: 'Ventas a Crédito y Cuentas por Cobrar',
              desc:
                  'Al vender con "CRÉDITO", el pedido se guarda con saldo pendiente (PAID < TOTAL). Desde el detalle del pedido se pueden registrar amortizaciones o abonos parciales hasta liquidar la deuda.',
            ),
          ),
        ],
      ),
      _Group(
        title: 'Moneda Base del Sistema',
        subtitle: 'Configuración global y tipo de cambio',
        items: [
          _i(
            'moneda oficial tipo de cambio soles pen reportes históricos',
            _infoTile(
              icon: Icons.currency_exchange_rounded,
              title: 'Moneda Oficial Congelada en la Venta',
              desc:
                  'El sistema opera en la moneda base configurada en Ajustes (ej. Soles PEN). Cada venta almacena su tipo de cambio (T/C) para asegurar que reportes históricos nunca sufran distorsiones cambiarias.',
            ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 6: INVENTARIO ─────────────────────────────────────────────────────
  _HelpTab _inventoryTab() {
    const cTitle = 'Control de Lotes con Fecha de Caducidad (FEFO / FIFO)';
    const cBody =
        'Para farmacias, insumos agrícolas, veterinaria o alimentos, cada producto puede registrar lotes con fecha de vencimiento. El sistema despacha automáticamente primero los lotes con vencimiento más próximo para evitar pérdidas.';
    return _HelpTab('Stock y Lotes', Icons.inventory_2_outlined, [
      _Group(
        items: [
          _i(
            '$cTitle $cBody',
            _callout(
              title: cTitle,
              content: cBody,
              icon: Icons.alarm_rounded,
              color: const Color(0xFFD97706),
            ),
          ),
        ],
      ),
      _Group(
        title: 'Alertas de Caducidad en el Dashboard',
        subtitle: 'Monitoreo preventivo de mercadería en bodega',
        items: [
          _i(
            'alerta crítica preventiva vencer caducidad remate promoción devolución proveedor trazabilidad kardex lote',
            _stepFlow(
              [
                (
                  '1',
                  'Alerta Crítica (< 30 días)',
                  'Productos con riesgo inminente de vencer. Requiere remate, promoción o devolución al proveedor.',
                ),
                (
                  '2',
                  'Alerta Preventiva (30 a 60 días)',
                  'El sistema destaca el lote en amarillo en el catálogo y POS para priorizar su venta.',
                ),
                (
                  '3',
                  'Trazabilidad Kardex',
                  'Cada unidad vendida, comprada o devuelta queda anotada con fecha, hora, documento y lote exacto en el Kardex.',
                ),
              ],
              colors: const [
                Color(0xFFDC2626),
                Color(0xFFD97706),
                Color(0xFF2563EB),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  // ── TAB 7: ATAJOS ─────────────────────────────────────────────────────────
  _HelpTab _shortcutsTab() {
    const pos = [
      ('F2', 'Cobrar pedido actual en el POS'),
      ('Alt + C', 'Buscar o cambiar cliente en el POS'),
      ('Alt + B', 'Guardar venta actual como Borrador'),
      ('Esc', 'Limpiar búsqueda / Cerrar diálogos'),
      ('/', 'Enfocar buscador de productos'),
      ('Ctrl + Enter', 'Confirmar pago en modal de cobro'),
    ];
    const erp = [
      ('Ctrl + K / ⌘ + K', 'Paleta de Comandos Universal (navegación rápida)'),
      ('/', 'Filtrar listados o tablas activas'),
      ('R', 'Recargar métricas en tiempo real'),
      ('1 .. 4', 'Cambiar rango de fechas en Dashboard (Hoy, Sem, Mes, Todo)'),
    ];
    return _HelpTab('Atajos de Teclado', Icons.keyboard_outlined, [
      _Group(
        title: 'Atajos en el Punto de Venta (POS)',
        subtitle: 'Optimiza tu velocidad de atención en caja',
        columns: 2,
        items: [
          for (final s in pos) _i('${s.$1} ${s.$2}', _shortcutRow(s.$1, s.$2)),
        ],
      ),
      _Group(
        title: 'Atajos en el Panel ERP Administrativo',
        subtitle: 'Navegación ágil entre módulos',
        columns: 2,
        items: [
          for (final s in erp) _i('${s.$1} ${s.$2}', _shortcutRow(s.$1, s.$2)),
        ],
      ),
    ]);
  }

  // ── TAB 8: DIAGNÓSTICO ────────────────────────────────────────────────────
  _HelpTab _diagnosticsTab() {
    final t = _t;
    final isOnline = context.watch<NetworkCubit>().state is NetworkConnected;

    final latencyText =
        _measuringLatency
            ? 'Midiendo...'
            : _latencyMs == null
            ? (_supabaseReachable ? 'N/D' : 'Error de conexión')
            : '$_latencyMs ms (${_latencyMs! < 100
                ? 'Excelente'
                : _latencyMs! < 300
                ? 'Bueno'
                : _latencyMs! < 600
                ? 'Regular'
                : 'Lento'})';

    final latencyColor =
        _latencyMs == null
            ? (_supabaseReachable ? AppColors.warning : AppColors.error)
            : _latencyMs! < 100
            ? AppColors.success
            : _latencyMs! < 300
            ? AppColors.info
            : _latencyMs! < 600
            ? AppColors.warning
            : AppColors.error;

    final versionDisplay =
        _buildNumber.isNotEmpty
            ? 'DANILORE ONE ERP v$_appVersion (Build $_buildNumber)'
            : 'DANILORE ONE ERP v$_appVersion';

    final rows = [
      ('Versión de Software', versionDisplay, null),
      ('Motor de Base de Datos', 'PostgreSQL vía Supabase Cloud', null),
      (
        'Arquitectura POS',
        'Multi-Store, Multi-Register y caché offline resiliente',
        null,
      ),
      ('Plataforma Activa', 'Flutter Multiplatform Desktop/Web/Android', null),
      ('Latencia a Supabase', latencyText, latencyColor),
      (
        'Conectividad de Red',
        isOnline ? 'Conectado a Internet' : 'Sin conexión a Internet',
        isOnline ? AppColors.success : AppColors.error,
      ),
      ('Seguridad', 'Row Level Security (RLS) + JWT Auth', null),
    ];

    final buildSuffix = _buildNumber.isNotEmpty ? ' (Build $_buildNumber)' : '';
    final reportText =
        'DANILORE ONE ERP v$_appVersion$buildSuffix | Latency: ${_latencyMs?.toString() ?? 'N/D'}ms | DB: PostgreSQL Supabase | Network: ${isOnline ? 'Online' : 'Offline'} | Supabase: ${_supabaseReachable ? 'Reachable' : 'Unreachable'}';

    return _HelpTab('Diagnóstico & Cloud', Icons.cloud_done_rounded, [
      _Group(
        items: [
          _i(
            'servidor supabase cloud activo sincronizado postgresql respaldados estado operativo ${_supabaseReachable ? "activo" : "error"}',
            _statusBanner(reachable: _supabaseReachable && isOnline),
          ),
        ],
      ),
      _Group(
        title: 'Telemetría de la Aplicación',
        subtitle: 'Información del entorno y conectividad',
        columns: 2,
        items: [
          for (final r in rows)
            _i('${r.$1} ${r.$2}', _diagTile(r.$1, r.$2, dot: r.$3)),
        ],
      ),
      _Group(
        items: [
          _i(
            'copiar reporte completo soporte técnico',
            Row(
              children: [
                FilledButton.icon(
                  onPressed:
                      () => _copyToClipboard(
                        reportText,
                        'Reporte de Diagnóstico',
                      ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copiar reporte para soporte técnico'),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.primaryBtn,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _measuringLatency ? null : _measureLatency,
                  icon:
                      _measuringLatency
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Re-medir latencia'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 46),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPONENTES
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _sectionHeader(String title, String? subtitle) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        searching
            ? _highlightedText(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: t.title,
                letterSpacing: -0.3,
              ),
            )
            : Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: t.title,
                letterSpacing: -0.3,
              ),
            ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          searching
              ? _highlightedText(
                subtitle,
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.4),
              )
              : Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.4),
              ),
        ],
      ],
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final t = _t;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
        boxShadow: t.shadow,
      ),
      child: child,
    );
  }

  Widget _iconTile(IconData icon, Color color, {double size = 38}) {
    final t = _t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.dark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: size * 0.5, color: t.tone(color)),
    );
  }

  Widget _badge(String text, Color color) {
    final t = _t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.dark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: t.tone(color),
        ),
      ),
    );
  }

  Widget _monoPill(String text) {
    final t = _t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: t.field,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: t.muted,
        ),
      ),
    );
  }

  Widget _callout({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    String? lead,
  }) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.dark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _iconTile(icon, color, size: 40),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            searching
                                ? _highlightedText(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.tone(color),
                                    height: 1.3,
                                  ),
                                )
                                : Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: t.tone(color),
                                    height: 1.3,
                                  ),
                                ),
                            const SizedBox(height: 6),
                            searching
                                ? _highlightedText(
                                  lead == null ? content : '$lead $content',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.body,
                                    height: 1.55,
                                  ),
                                )
                                : Text.rich(
                                  TextSpan(
                                    children: [
                                      if (lead != null)
                                        TextSpan(
                                          text: '$lead ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: t.title,
                                          ),
                                        ),
                                      TextSpan(text: content),
                                    ],
                                  ),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: t.body,
                                    height: 1.55,
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hierarchyCard({
    required String badge,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
  }) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return _card(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconTile(icon, color),
              const SizedBox(width: 10),
              _badge(badge, color),
            ],
          ),
          const SizedBox(height: 14),
          searching
              ? _highlightedText(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.title,
                ),
              )
              : Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: t.title,
                ),
              ),
          const SizedBox(height: 6),
          searching
              ? _highlightedText(
                desc,
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.5),
              )
              : Text(
                desc,
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.5),
              ),
        ],
      ),
    );
  }

  /// Timeline vertical con conector entre pasos.
  Widget _stepFlow(
    List<(String, String, String)> steps, {
    List<Color>? colors,
  }) {
    final t = _t;
    return _card(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _stepRow(
              steps[i],
              last: i == steps.length - 1,
              color: colors != null ? colors[i] : t.primaryBtn,
            ),
        ],
      ),
    );
  }

  Widget _stepRow(
    (String, String, String) s, {
    required bool last,
    required Color color,
  }) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    s.$1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: t.border,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child:
                        searching
                            ? _highlightedText(
                              s.$2,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.title,
                              ),
                            )
                            : Text(
                              s.$2,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: t.title,
                              ),
                            ),
                  ),
                  const SizedBox(height: 4),
                  searching
                      ? _highlightedText(
                        s.$3,
                        style: TextStyle(
                          fontSize: 13,
                          color: t.muted,
                          height: 1.55,
                        ),
                      )
                      : Text(
                        s.$3,
                        style: TextStyle(
                          fontSize: 13,
                          color: t.muted,
                          height: 1.55,
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq(String question, String answer) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
        boxShadow: t.shadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('$question-$searching'),
          initiallyExpanded: searching,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(44, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          expandedAlignment: Alignment.centerLeft,
          shape: const Border(),
          collapsedShape: const Border(),
          iconColor: t.muted,
          collapsedIconColor: t.muted,
          title: Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 18, color: t.accent),
              const SizedBox(width: 10),
              Expanded(
                child:
                    searching
                        ? _highlightedText(
                          question,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.title,
                            height: 1.35,
                          ),
                        )
                        : Text(
                          question,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.title,
                            height: 1.35,
                          ),
                        ),
              ),
            ],
          ),
          children: [
            searching
                ? _highlightedText(
                  answer,
                  style: TextStyle(fontSize: 13, color: t.body, height: 1.55),
                )
                : Text(
                  answer,
                  style: TextStyle(fontSize: 13, color: t.body, height: 1.55),
                ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String desc,
  }) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconTile(icon, _blue),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                searching
                    ? _highlightedText(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.title,
                        height: 1.3,
                      ),
                    )
                    : Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: t.title,
                        height: 1.3,
                      ),
                    ),
                const SizedBox(height: 4),
                searching
                    ? _highlightedText(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.muted,
                        height: 1.55,
                      ),
                    )
                    : Text(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.muted,
                        height: 1.55,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleCard({
    required String role,
    required String code,
    required String desc,
    required Color color,
    required IconData icon,
  }) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return _card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _iconTile(icon, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    searching
                        ? _highlightedText(
                          role,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.tone(color),
                          ),
                        )
                        : Text(
                          role,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.tone(color),
                          ),
                        ),
                    _monoPill(code),
                  ],
                ),
                const SizedBox(height: 5),
                searching
                    ? _highlightedText(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.muted,
                        height: 1.55,
                      ),
                    )
                    : Text(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.muted,
                        height: 1.55,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _docTypeCard({
    required String title,
    required String series,
    required String badge,
    required Color color,
    required String desc,
    required List<String> requirements,
  }) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return _card(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              searching
                  ? _highlightedText(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.title,
                    ),
                  )
                  : Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: t.title,
                    ),
                  ),
              _badge(badge, color),
              _monoPill(series),
            ],
          ),
          const SizedBox(height: 8),
          searching
              ? _highlightedText(
                desc,
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.55),
              )
              : Text(
                desc,
                style: TextStyle(fontSize: 13, color: t.muted, height: 1.55),
              ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final r in requirements)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: t.tone(color),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child:
                          searching
                              ? _highlightedText(
                                r,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: t.body,
                                ),
                              )
                              : Text(
                                r,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: t.body,
                                ),
                              ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tabla en pantallas anchas; tarjetas apiladas en pantallas angostas.
  Widget _comparison({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final t = _t;
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 640) {
          return _card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: t.border),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rows[i][0],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.title,
                          ),
                        ),
                        for (var k = 1; k < rows[i].length; k++) ...[
                          const SizedBox(height: 10),
                          Text(
                            headers[k].toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: t.accent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            rows[i][k],
                            style: TextStyle(
                              fontSize: 13,
                              color: t.body,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        Widget cell(String text, {bool header = false, bool first = false}) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              text,
              style: TextStyle(
                fontSize: header ? 12.5 : 13,
                fontWeight: header || first ? FontWeight.w700 : FontWeight.w400,
                color: header || first ? t.title : t.body,
                height: 1.45,
              ),
            ),
          );
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.border),
            boxShadow: t.shadow,
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.1),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1.8),
            },
            border: TableBorder(horizontalInside: BorderSide(color: t.border)),
            children: [
              TableRow(
                decoration: BoxDecoration(color: t.field),
                children: [for (final h in headers) cell(h, header: true)],
              ),
              for (final row in rows)
                TableRow(
                  children: [
                    for (var k = 0; k < row.length; k++)
                      cell(row[k], first: k == 0),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _shortcutRow(String keys, String desc) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    final alternatives = keys.split(' / ');
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child:
                searching
                    ? _highlightedText(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.body,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    )
                    : Text(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.body,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
          ),
          const SizedBox(width: 12),
          for (var a = 0; a < alternatives.length; a++) ...[
            if (a > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'o',
                  style: TextStyle(fontSize: 11, color: t.muted),
                ),
              ),
            ..._keycaps(alternatives[a].split(' + ')),
          ],
        ],
      ),
    );
  }

  List<Widget> _keycaps(List<String> parts) {
    final t = _t;
    return [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text('+', style: TextStyle(fontSize: 11, color: t.muted)),
          ),
        Container(
          constraints: const BoxConstraints(minWidth: 28),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: t.field,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.strongBorder),
            boxShadow: [
              BoxShadow(color: t.strongBorder, offset: const Offset(0, 1.5)),
            ],
          ),
          child: Text(
            parts[i],
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: t.title,
            ),
          ),
        ),
      ],
    ];
  }

  Widget _statusBanner({bool reachable = true}) {
    final t = _t;
    final color = reachable ? AppColors.success : AppColors.error;
    final searching = _searchQuery.isNotEmpty;
    final title =
        reachable
            ? 'Servidor Supabase Cloud activo y sincronizado'
            : 'Sin conexión a Supabase o red inaccesible';
    final body =
        reachable
            ? 'Conexión segura con la nube PostgreSQL. Todos los datos, turnos y ventas están respaldados.'
            : 'No se pudo verificar la conexión. Revisa tu red o credenciales de Supabase.';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.dark ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow:
                  reachable
                      ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 0,
                          spreadRadius: 4,
                        ),
                      ]
                      : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                searching
                    ? _highlightedText(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.tone(color),
                      ),
                    )
                    : Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: t.tone(color),
                      ),
                    ),
                const SizedBox(height: 3),
                searching
                    ? _highlightedText(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.body,
                        height: 1.45,
                      ),
                    )
                    : Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        color: t.body,
                        height: 1.45,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagTile(String label, String value, {Color? dot}) {
    final t = _t;
    final searching = _searchQuery.isNotEmpty;
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          searching
              ? _highlightedText(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: t.muted,
                ),
              )
              : Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: t.muted,
                ),
              ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (dot != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child:
                    searching
                        ? _highlightedText(
                          value,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.title,
                            height: 1.35,
                          ),
                        )
                        : Text(
                          value,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: t.title,
                            height: 1.35,
                          ),
                        ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compatibilidad hacia atrás: abre la pantalla completa `/help`
class AdminHelpDialog extends StatelessWidget {
  const AdminHelpDialog({super.key});

  static Future<void> show(BuildContext context) async {
    context.go('/help');
  }

  @override
  Widget build(BuildContext context) {
    return const AdminHelpScreen();
  }
}
