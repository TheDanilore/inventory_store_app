import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/network/presentation/bloc/network_state.dart';

class NetworkCubit extends Cubit<NetworkState> {
  StreamSubscription? _connectivitySubscription;

  NetworkCubit() : super(NetworkInitial()) {
    _initNetworkCheck();
  }

  bool get isOnline => state is NetworkConnected;

  Future<void> _initNetworkCheck() async {
    final result = await Connectivity().checkConnectivity();
    _updateStatus(result);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateStatus(result);
    });
  }

  void _updateStatus(dynamic result) {
    bool isConnected = true;
    if (result is List) {
      isConnected = !result.contains(ConnectivityResult.none);
    } else {
      isConnected = result != ConnectivityResult.none;
    }

    if (isConnected) {
      emit(const NetworkConnected());
    } else {
      emit(const NetworkDisconnected());
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
