import 'package:flutter/material.dart';

/// Contenedor de scroll que asegura que el ListView ocupe todo el ancho de la pantalla
/// (para que el scrollbar quede pegado al borde derecho), mientras que el contenido
/// se centra y se restringe a un ancho máximo de 1200px con padding responsivo.
class SettingsScrollContent extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const SettingsScrollContent({
    super.key,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final horizontalPadding = isMobile ? 12.0 : 20.0;

        return ListView(
          padding: EdgeInsets.fromLTRB(0, 4, 0, isMobile ? 40 : 60),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
