import 'package:flutter/material.dart';

enum SettingFormat { number, percent, currency, integer }

class SettingItemConfig {
  final String key;
  final double fallback;
  final String description;
  final SettingFormat format;
  final IconData? icon;

  const SettingItemConfig({
    required this.key,
    required this.fallback,
    required this.description,
    this.format = SettingFormat.number,
    this.icon,
  });
}

/// Catálogo canónico de claves y configuraciones de fidelización y gamificación en el ERP.
class LoyaltySettingsKeys {
  const LoyaltySettingsKeys._();

  // Sistema y Ratio
  static const String earningRate = 'points_earning_rate';
  static const String pointsRatio = 'points_to_soles_ratio';
  static const String checkinReward = 'checkin_reward';
  static const String checkinStreakStep = 'checkin_streak_step';

  // Límites Diarios
  static const String boxesDailyLimit = 'boxes_daily_limit';
  static const String memoramaDailyLimit = 'memorama_daily_limit';
  static const String catcherDailyLimit = 'catcher_daily_limit';
  static const String pinataDailyLimit = 'pinata_daily_limit';
  static const String jumpDailyLimit = 'jump_daily_limit';
  static const String clawDailyLimit = 'claw_daily_limit';
  static const String stackDailyLimit = 'stack_daily_limit';
  static const String dodgeDailyLimit = 'dodge_daily_limit';

  // Premios
  static const String boxesPrize1 = 'boxes_prize_1';
  static const String boxesPrize2 = 'boxes_prize_2';
  static const String boxesPrize3 = 'boxes_prize_3';
  static const String pinataGrandPrize = 'pinata_grand_prize';
  static const String pinataConsolationPrize = 'pinata_consolation_prize';
  static const String memoramaMatchReward = 'memorama_match_reward';
  static const String catcherCoinReward = 'catcher_coin_reward';
  static const String catcherGiftReward = 'catcher_gift_reward';
  static const String catcherBombPenalty = 'catcher_bomb_penalty';

  static const String clawPrize1 = 'claw_prize_1';
  static const String clawPrize2 = 'claw_prize_2';
  static const String clawPrize3 = 'claw_prize_3';
  static const String clawPrize4 = 'claw_prize_4';
  static const String clawPrize5 = 'claw_prize_5';

  static const List<SettingItemConfig> allDefinitions = [
    // Sistema y Ratio
    SettingItemConfig(
      key: earningRate,
      fallback: 0.03,
      description: 'Tasa de acumulación',
      format: SettingFormat.percent,
    ),
    SettingItemConfig(
      key: pointsRatio,
      fallback: 0.01,
      description: 'Valor por punto',
      format: SettingFormat.currency,
    ),
    SettingItemConfig(
      key: checkinReward,
      fallback: 20,
      description: 'Premio Check-in día 1',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: checkinStreakStep,
      fallback: 10,
      description: 'Bono por racha',
      format: SettingFormat.integer,
    ),

    // Límites Diarios
    SettingItemConfig(
      key: boxesDailyLimit,
      fallback: 1,
      description: 'Cajitas Misteriosas',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: memoramaDailyLimit,
      fallback: 1,
      description: 'Memorama',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: catcherDailyLimit,
      fallback: 1,
      description: 'Lluvia de Monedas',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: pinataDailyLimit,
      fallback: 1,
      description: 'Piñata',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: jumpDailyLimit,
      fallback: 1,
      description: 'Salto',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: clawDailyLimit,
      fallback: 1,
      description: 'Máquina de Garra',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: stackDailyLimit,
      fallback: 1,
      description: 'Apilador',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: dodgeDailyLimit,
      fallback: 1,
      description: 'Esquiva',
      format: SettingFormat.integer,
    ),

    // Premios
    SettingItemConfig(
      key: boxesPrize1,
      fallback: 10,
      description: 'Premio 1',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: boxesPrize2,
      fallback: 20,
      description: 'Premio 2',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: boxesPrize3,
      fallback: 30,
      description: 'Premio 3',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: pinataGrandPrize,
      fallback: 50,
      description: 'Mayor (>= 50)',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: pinataConsolationPrize,
      fallback: 5,
      description: 'Consolación',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: memoramaMatchReward,
      fallback: 5,
      description: 'Pts por pareja',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: catcherCoinReward,
      fallback: 1,
      description: 'Pts por moneda',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: catcherGiftReward,
      fallback: 5,
      description: 'Pts por regalo',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: catcherBombPenalty,
      fallback: -3,
      description: 'Penalidad bomba',
      format: SettingFormat.integer,
      icon: Icons.warning_rounded,
    ),
    SettingItemConfig(
      key: clawPrize1,
      fallback: 5,
      description: 'P1 (Izq)',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: clawPrize2,
      fallback: 20,
      description: 'P2',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: clawPrize3,
      fallback: 50,
      description: 'P3 (Centro)',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: clawPrize4,
      fallback: 10,
      description: 'P4',
      format: SettingFormat.integer,
    ),
    SettingItemConfig(
      key: clawPrize5,
      fallback: 5,
      description: 'P5 (Der)',
      format: SettingFormat.integer,
    ),
  ];

  static const List<String> systemKeys = [
    earningRate,
    pointsRatio,
    checkinReward,
    checkinStreakStep,
  ];

  static const List<String> limitsKeys = [
    boxesDailyLimit,
    memoramaDailyLimit,
    catcherDailyLimit,
    pinataDailyLimit,
    jumpDailyLimit,
    clawDailyLimit,
    stackDailyLimit,
    dodgeDailyLimit,
  ];

  static const List<String> prizesKeys = [
    boxesPrize1,
    boxesPrize2,
    boxesPrize3,
    pinataGrandPrize,
    pinataConsolationPrize,
    catcherCoinReward,
    catcherGiftReward,
    catcherBombPenalty,
    memoramaMatchReward,
    clawPrize1,
    clawPrize2,
    clawPrize3,
    clawPrize4,
    clawPrize5,
  ];
}
