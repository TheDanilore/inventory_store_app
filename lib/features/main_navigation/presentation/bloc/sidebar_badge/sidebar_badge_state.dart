import 'package:equatable/equatable.dart';

abstract class SidebarBadgeState extends Equatable {
  const SidebarBadgeState();

  @override
  List<Object?> get props => [];
}

class SidebarBadgeLoading extends SidebarBadgeState {}

class SidebarBadgeLoaded extends SidebarBadgeState {
  final int count;

  const SidebarBadgeLoaded(this.count);

  @override
  List<Object?> get props => [count];
}

class SidebarBadgeError extends SidebarBadgeState {
  final String message;

  const SidebarBadgeError(this.message);

  @override
  List<Object?> get props => [message];
}
