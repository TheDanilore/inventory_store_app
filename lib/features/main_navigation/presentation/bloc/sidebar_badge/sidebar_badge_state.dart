import 'package:equatable/equatable.dart';

abstract class SidebarBadgeState extends Equatable {
  final int? cachedCount;
  const SidebarBadgeState({this.cachedCount});

  @override
  List<Object?> get props => [cachedCount];
}

class SidebarBadgeLoading extends SidebarBadgeState {
  const SidebarBadgeLoading({super.cachedCount});
}

class SidebarBadgeLoaded extends SidebarBadgeState {
  final int count;

  const SidebarBadgeLoaded(this.count) : super(cachedCount: count);

  @override
  List<Object?> get props => [count, cachedCount];
}

class SidebarBadgeError extends SidebarBadgeState {
  final String message;

  const SidebarBadgeError(this.message, {super.cachedCount});

  @override
  List<Object?> get props => [message, cachedCount];
}
