// ignore_for_file: avoid_web_libraries_in_flutter
// ignore: deprecated_member_use
import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html' as html;

/// En Flutter Web, recorre todos los elementos de video en el DOM y Shadow DOM
// ignore: unintended_html_in_doc_comment
/// (incluyendo el shadowRoot de CanvasKit / <flt-glass-pane>) y fuerza
/// la detención física de todos los tracks de cámara activos (MediaStreamTrack.stop()).
/// Esto garantiza que la luz de la cámara web (LED) y el punto rojo de grabación del
/// navegador se apaguen de inmediato.
void stopAllWebCameraStreams() {
  _performStop();
  // Se ejecutan ticks diferidos para atrapar cualquier elemento mientras el widget se desmonta
  Timer(const Duration(milliseconds: 150), _performStop);
  Timer(const Duration(milliseconds: 400), _performStop);
}

void _performStop() {
  try {
    _traverseAndStopVideos(html.document);
  } catch (_) {}
}

void _traverseAndStopVideos(dynamic rootNode) {
  if (rootNode == null) return;

  try {
    // Si el nodo en sí es un video
    if (rootNode is html.VideoElement) {
      _killVideoElement(rootNode);
    }

    // Buscar todos los tags <video> en este nivel
    try {
      final videos = rootNode.querySelectorAll('video');
      for (final v in videos) {
        if (v is html.VideoElement) {
          _killVideoElement(v);
        }
      }
    } catch (_) {}

    // Buscar elementos con shadowRoot (como flt-glass-pane o flutter-view en CanvasKit)
    try {
      final allElements = rootNode.querySelectorAll('*');
      for (final el in allElements) {
        if (el is html.Element && el.shadowRoot != null) {
          _traverseAndStopVideos(el.shadowRoot);
        }
      }
    } catch (_) {}
  } catch (_) {}
}

void _killVideoElement(html.VideoElement video) {
  try {
    final stream = video.srcObject;
    if (stream is html.MediaStream) {
      for (final track in stream.getTracks()) {
        try {
          track.stop();
        } catch (_) {}
      }
      video.srcObject = null;
    }
    video.pause();
  } catch (_) {}
}
