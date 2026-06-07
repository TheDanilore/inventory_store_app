import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkProvider with ChangeNotifier {
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  NetworkProvider() {
    _initNetworkCheck();
  }

  Future<void> _initNetworkCheck() async {
    // Revisar estado inicial
    final result = await Connectivity().checkConnectivity();
    _updateStatus(result);

    // Escuchar cambios en tiempo real
    Connectivity().onConnectivityChanged.listen((result) {
      _updateStatus(result);
    });
  }

  // Cambiamos el tipo a dynamic para evitar conflictos con Flutter Web o versiones del paquete
  void _updateStatus(dynamic result) {
    bool isConnected = true;

    // Evaluamos si el resultado llega como una Lista (versiones nuevas) o como un item único (versiones antiguas)
    if (result is List) {
      isConnected = !result.contains(ConnectivityResult.none);
    } else {
      isConnected = result != ConnectivityResult.none;
    }

    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      notifyListeners();
    }
  }
}
