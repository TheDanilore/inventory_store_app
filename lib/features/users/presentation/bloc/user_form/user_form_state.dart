import 'package:equatable/equatable.dart';

abstract class UserFormState extends Equatable {
  const UserFormState();

  @override
  List<Object?> get props => [];
}

class UserFormInitial extends UserFormState {
  const UserFormInitial();
}

class UserFormLoading extends UserFormState {
  const UserFormLoading();
}

class UserFormSuccess extends UserFormState {
  final String message;

  const UserFormSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class UserFormError extends UserFormState {
  final String message;

  const UserFormError(this.message);

  @override
  List<Object?> get props => [message];
}
