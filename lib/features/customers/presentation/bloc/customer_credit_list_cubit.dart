import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_ucs.dart';

abstract class CustomerCreditListState {}

class CustomerCreditListInitial extends CustomerCreditListState {}

class CustomerCreditListLoading extends CustomerCreditListState {}

class CustomerCreditListLoaded extends CustomerCreditListState {
  final List<CustomerCreditEntity> accounts;
  final int currentPage;
  final int totalPages;
  final String? query;
  final bool showOnlyWithDebt;

  CustomerCreditListLoaded({
    required this.accounts,
    this.currentPage = 1,
    this.totalPages = 1,
    this.query,
    this.showOnlyWithDebt = false,
  });

  CustomerCreditListLoaded copyWith({
    List<CustomerCreditEntity>? accounts,
    int? currentPage,
    int? totalPages,
    String? query,
    bool? showOnlyWithDebt,
  }) {
    return CustomerCreditListLoaded(
      accounts: accounts ?? this.accounts,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      query: query ?? this.query,
      showOnlyWithDebt: showOnlyWithDebt ?? this.showOnlyWithDebt,
    );
  }
}

class CustomerCreditListError extends CustomerCreditListState {
  final String message;
  CustomerCreditListError(this.message);
}

@injectable
class CustomerCreditListCubit extends Cubit<CustomerCreditListState> {
  final GetCreditAccountsUseCase _getCreditAccountsUseCase;
  static const int _limit = 20;

  CustomerCreditListCubit(this._getCreditAccountsUseCase) : super(CustomerCreditListInitial());

  Future<void> loadAccounts({String? query, bool showOnlyWithDebt = false, int page = 1}) async {
    emit(CustomerCreditListLoading());
    try {
      final offset = (page - 1) * _limit;
      final accounts = await _getCreditAccountsUseCase(
        limit: _limit,
        offset: offset,
        query: query,
        showOnlyWithDebt: showOnlyWithDebt,
      );
      // Asumimos que totalPages es 1 por ahora o se calcula con un count que no tenemos
      emit(CustomerCreditListLoaded(
        accounts: accounts,
        currentPage: page,
        totalPages: accounts.length == _limit ? page + 1 : page, // simple pagination logic
        query: query,
        showOnlyWithDebt: showOnlyWithDebt,
      ));
    } catch (e) {
      emit(CustomerCreditListError(e.toString()));
    }
  }

  void setPage(int page) {
    if (state is CustomerCreditListLoaded) {
      final s = state as CustomerCreditListLoaded;
      loadAccounts(query: s.query, showOnlyWithDebt: s.showOnlyWithDebt, page: page);
    }
  }

  void search(String query) {
    if (state is CustomerCreditListLoaded) {
      final s = state as CustomerCreditListLoaded;
      loadAccounts(query: query, showOnlyWithDebt: s.showOnlyWithDebt, page: 1);
    } else {
      loadAccounts(query: query, page: 1);
    }
  }

  void setTab(int index) {
    bool onlyDebt = index == 0;
    if (state is CustomerCreditListLoaded) {
      final s = state as CustomerCreditListLoaded;
      if (s.showOnlyWithDebt != onlyDebt) {
        loadAccounts(query: s.query, showOnlyWithDebt: onlyDebt, page: 1);
      }
    } else {
      loadAccounts(showOnlyWithDebt: onlyDebt, page: 1);
    }
  }
}
