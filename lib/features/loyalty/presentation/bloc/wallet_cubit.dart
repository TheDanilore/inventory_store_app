import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/loyalty/domain/usecases/get_wallet_balance_uc.dart';

class WalletState {
  final int? balance;
  final bool isLoading;
  final String? error;

  const WalletState({
    this.balance,
    this.isLoading = false,
    this.error,
  });

  bool get hasBalance => balance != null;

  WalletState copyWith({
    int? balance,
    bool? isLoading,
    String? error,
    bool clearBalance = false,
    bool clearError = false,
  }) {
    return WalletState(
      balance: clearBalance ? null : (balance ?? this.balance),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@injectable
class WalletCubit extends Cubit<WalletState> {
  final GetWalletBalanceUC getWalletBalanceUC;
  final SupabaseClient _supabase;
  StreamSubscription<AuthState>? _authSub;
  RealtimeChannel? _walletChannel;

  WalletCubit({
    required this.getWalletBalanceUC,
    required SupabaseClient supabase,
  })  : _supabase = supabase,
        super(const WalletState()) {
    _init();

    _authSub = _supabase.auth.onAuthStateChange.listen((event) {
      if (isClosed) return;
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.tokenRefreshed) {
        _init();
      } else if (event.event == AuthChangeEvent.signedOut) {
        _clear();
      }
    });
  }

  Future<void> _init() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _clear();
      return;
    }

    if (isClosed) return;
    emit(state.copyWith(isLoading: true, clearError: true));

    final result = await getWalletBalanceUC(user.id);
    result.fold(
      (failure) {
        if (isClosed) return;
        emit(state.copyWith(
          isLoading: false,
          error: 'No se pudo cargar el saldo.',
          balance: state.balance ?? 0,
        ));
      },
      (balance) {
        if (isClosed) return;
        emit(state.copyWith(isLoading: false, balance: balance));
        _listenToWalletChanges(user.id);
      },
    );
  }

  void _clear() {
    _walletChannel?.unsubscribe();
    _walletChannel = null;
    if (!isClosed) {
      emit(state.copyWith(clearBalance: true, isLoading: false, clearError: true));
    }
  }

  void _listenToWalletChanges(String userId) {
    _walletChannel?.unsubscribe();
    _walletChannel = _supabase
        .channel('public:profiles_wallet_$userId')
        .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'profiles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'auth_user_id',
              value: userId,
            ),
            callback: (payload) {
              final newRow = payload.newRecord;
              if (newRow.isNotEmpty && !isClosed) {
                 final newBalance = (newRow['wallet_balance'] as num?)?.toInt() ?? 0;
                 if (state.balance != newBalance) {
                   emit(state.copyWith(balance: newBalance));
                 }
              }
            })
        .subscribe();
  }

  @override
  Future<void> close() {
    _authSub?.cancel();
    _walletChannel?.unsubscribe();
    return super.close();
  }
}
