import 'package:equatable/equatable.dart';

class PointsState extends Equatable {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isClaimingCheckin;
  final bool isPlayingMiniGame;
  final bool isPreparingBoxes;
  final bool boxesRoundReady;
  final bool showBoxesPreviewValues;
  final bool hasMoreMovements;

  final String? profileId;
  final int currentBalance;
  final int currentStreak;
  final bool hasTodayCheckin;
  final DateTime? lastCheckinDate;

  final int boxesPlaysToday;
  final int memoramaPlaysToday;
  final int catcherPlaysToday;
  final int pinataPlaysToday;
  final int superSaltoPlaysToday;
  final int clawPlaysToday;
  final int stackPlaysToday;
  final int dodgePlaysToday;

  final int? lastBoxesReward;
  final int boxesShuffleSeed;
  final List<int> miniGamePreviewBoxes;
  final List<int> miniGameBoxes;

  final int baseCheckinReward;
  final int streakStepReward;
  final int nextCheckinReward;

  final List<Map<String, dynamic>> movements;
  final String? errorMessage;

  const PointsState({
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isClaimingCheckin = false,
    this.isPlayingMiniGame = false,
    this.isPreparingBoxes = false,
    this.boxesRoundReady = false,
    this.showBoxesPreviewValues = false,
    this.hasMoreMovements = true,
    this.profileId,
    this.currentBalance = 0,
    this.currentStreak = 0,
    this.hasTodayCheckin = false,
    this.lastCheckinDate,
    this.boxesPlaysToday = 0,
    this.memoramaPlaysToday = 0,
    this.catcherPlaysToday = 0,
    this.pinataPlaysToday = 0,
    this.superSaltoPlaysToday = 0,
    this.clawPlaysToday = 0,
    this.stackPlaysToday = 0,
    this.dodgePlaysToday = 0,
    this.lastBoxesReward,
    this.boxesShuffleSeed = 0,
    this.miniGamePreviewBoxes = const [],
    this.miniGameBoxes = const [],
    this.baseCheckinReward = 20,
    this.streakStepReward = 10,
    this.nextCheckinReward = 20,
    this.movements = const [],
    this.errorMessage,
  });

  PointsState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isClaimingCheckin,
    bool? isPlayingMiniGame,
    bool? isPreparingBoxes,
    bool? boxesRoundReady,
    bool? showBoxesPreviewValues,
    bool? hasMoreMovements,
    String? profileId,
    int? currentBalance,
    int? currentStreak,
    bool? hasTodayCheckin,
    DateTime? lastCheckinDate,
    int? boxesPlaysToday,
    int? memoramaPlaysToday,
    int? catcherPlaysToday,
    int? pinataPlaysToday,
    int? superSaltoPlaysToday,
    int? clawPlaysToday,
    int? stackPlaysToday,
    int? dodgePlaysToday,
    int? lastBoxesReward,
    int? boxesShuffleSeed,
    List<int>? miniGamePreviewBoxes,
    List<int>? miniGameBoxes,
    int? baseCheckinReward,
    int? streakStepReward,
    int? nextCheckinReward,
    List<Map<String, dynamic>>? movements,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PointsState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isClaimingCheckin: isClaimingCheckin ?? this.isClaimingCheckin,
      isPlayingMiniGame: isPlayingMiniGame ?? this.isPlayingMiniGame,
      isPreparingBoxes: isPreparingBoxes ?? this.isPreparingBoxes,
      boxesRoundReady: boxesRoundReady ?? this.boxesRoundReady,
      showBoxesPreviewValues: showBoxesPreviewValues ?? this.showBoxesPreviewValues,
      hasMoreMovements: hasMoreMovements ?? this.hasMoreMovements,
      profileId: profileId ?? this.profileId,
      currentBalance: currentBalance ?? this.currentBalance,
      currentStreak: currentStreak ?? this.currentStreak,
      hasTodayCheckin: hasTodayCheckin ?? this.hasTodayCheckin,
      lastCheckinDate: lastCheckinDate ?? this.lastCheckinDate,
      boxesPlaysToday: boxesPlaysToday ?? this.boxesPlaysToday,
      memoramaPlaysToday: memoramaPlaysToday ?? this.memoramaPlaysToday,
      catcherPlaysToday: catcherPlaysToday ?? this.catcherPlaysToday,
      pinataPlaysToday: pinataPlaysToday ?? this.pinataPlaysToday,
      superSaltoPlaysToday: superSaltoPlaysToday ?? this.superSaltoPlaysToday,
      clawPlaysToday: clawPlaysToday ?? this.clawPlaysToday,
      stackPlaysToday: stackPlaysToday ?? this.stackPlaysToday,
      dodgePlaysToday: dodgePlaysToday ?? this.dodgePlaysToday,
      lastBoxesReward: lastBoxesReward ?? this.lastBoxesReward,
      boxesShuffleSeed: boxesShuffleSeed ?? this.boxesShuffleSeed,
      miniGamePreviewBoxes: miniGamePreviewBoxes ?? this.miniGamePreviewBoxes,
      miniGameBoxes: miniGameBoxes ?? this.miniGameBoxes,
      baseCheckinReward: baseCheckinReward ?? this.baseCheckinReward,
      streakStepReward: streakStepReward ?? this.streakStepReward,
      nextCheckinReward: nextCheckinReward ?? this.nextCheckinReward,
      movements: movements ?? this.movements,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        isLoading, isLoadingMore, isClaimingCheckin, isPlayingMiniGame,
        isPreparingBoxes, boxesRoundReady, showBoxesPreviewValues, hasMoreMovements,
        profileId, currentBalance, currentStreak, hasTodayCheckin, lastCheckinDate,
        boxesPlaysToday, memoramaPlaysToday, catcherPlaysToday, pinataPlaysToday,
        superSaltoPlaysToday, clawPlaysToday, stackPlaysToday, dodgePlaysToday,
        lastBoxesReward, boxesShuffleSeed, miniGamePreviewBoxes, miniGameBoxes,
        baseCheckinReward, streakStepReward, nextCheckinReward, movements, errorMessage,
      ];
}
