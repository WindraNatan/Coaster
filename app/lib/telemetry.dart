// Kontrak telemetry & config cloud Smart Hydration Coaster.
// Nama field dan pemetaan state mencerminkan web/index.html (pollCloudOnce,
// pushCloudConfig) dan firmware cloud_sync.h; semantik state turunan
// ALERT_EMPTY_CUP / ALERT_MISSING_CUP mengikuti CLAUDE.md §3 (flag dari
// ALERT_REFILL, bukan state tersendiri).

const double kCupOffThresholdG = 25.0; // config.h CUP_OFF_THRESHOLD
const double kCupOnThresholdG = 35.0; // config.h CUP_ON_THRESHOLD
const int kMinManualIntervalMin = 1; // config.h MIN_CUSTOM_INTERVAL_MIN
const int kMaxManualIntervalMin = 180; // config.h MAX_CUSTOM_INTERVAL_MIN

class Telemetry {
  final double weightG;
  final double waterMl;
  final double tempC;
  final double humidityPct;
  final int remainingSec;
  final double targetIntervalMin;
  final int totalMl;
  final int drinkCount;
  final int refillCount;
  final int cheatCount;
  final bool muted;

  /// State mentah dari firmware: salah satu dari 7 state FSM, atau string
  /// turunan ALERT_EMPTY_CUP / ALERT_MISSING_CUP.
  final String rawState;

  const Telemetry({
    required this.weightG,
    required this.waterMl,
    required this.tempC,
    required this.humidityPct,
    required this.remainingSec,
    required this.targetIntervalMin,
    required this.totalMl,
    required this.drinkCount,
    required this.refillCount,
    required this.cheatCount,
    required this.muted,
    required this.rawState,
  });

  factory Telemetry.fromJson(Map<String, dynamic> t) => Telemetry(
        weightG: _num(t['weight_g']),
        waterMl: _num(t['water_ml']),
        tempC: _num(t['temp_c']),
        humidityPct: _num(t['humidity_pct']),
        remainingSec: _int(t['remaining_sec']),
        targetIntervalMin: _num(t['target_interval_min']),
        totalMl: _int(t['total_ml']),
        drinkCount: _int(t['drink_count']),
        refillCount: _int(t['refill_count']),
        cheatCount: _int(t['cheat_count']),
        muted: t['muted'] == true,
        rawState: (t['fsm_state'] as String?) ?? 'IDLE',
      );

  bool get cupPresent => weightG >= kCupOffThresholdG;

  /// State kanonik: dua string alert turunan dipetakan ke ALERT_REFILL
  /// (identik dengan web/fsm.js dan firmware).
  String get canonicalState =>
      (rawState == 'ALERT_EMPTY_CUP' || rawState == 'ALERT_MISSING_CUP')
          ? 'ALERT_REFILL'
          : rawState;

  bool get missingCup => rawState == 'ALERT_MISSING_CUP';
  bool get emptyCup => rawState == 'ALERT_EMPTY_CUP';
  bool get isAlert => canonicalState.startsWith('ALERT_');

  String get reason {
    switch (canonicalState) {
      case 'IDLE':
        return 'taruh gelas untuk mulai';
      case 'STABLE':
        return 'menunggu berat stabil 1,5 s';
      case 'TIMING':
        return 'timer minum berjalan';
      case 'LIFTED':
        return 'gelas diangkat';
      case 'ALERT_DRINK':
        return 'saatnya minum air!';
      case 'ALERT_CHEAT':
        return 'berat kembali tanpa minum cukup (< 20 g)';
      case 'ALERT_REFILL':
        return missingCup
            ? 'gelas belum kembali ke tatakan'
            : 'gelas kosong, silakan isi ulang';
      default:
        return '';
    }
  }

  static String mmss(int totalSec) {
    final s = totalSec < 0 ? 0 : totalSec;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

class CloudConfig {
  final String timerMode; // AUTO_DHT | MANUAL
  final int manualIntervalMin;
  final double emptyCupWeightG;
  final bool muted;

  const CloudConfig({
    required this.timerMode,
    required this.manualIntervalMin,
    required this.emptyCupWeightG,
    required this.muted,
  });

  factory CloudConfig.fromJson(Map<String, dynamic> j) => CloudConfig(
        timerMode: (j['timer_mode'] as String?) ?? 'AUTO_DHT',
        manualIntervalMin: _int(j['manual_interval_min'], 30), // BASE_INTERVAL_MS = 30 mnt
        emptyCupWeightG: _num(j['empty_cup_weight_g'], 130.0),
        muted: j['muted'] == true,
      );

  CloudConfig copyWith({
    String? timerMode,
    int? manualIntervalMin,
    double? emptyCupWeightG,
    bool? muted,
  }) =>
      CloudConfig(
        timerMode: timerMode ?? this.timerMode,
        manualIntervalMin: manualIntervalMin ?? this.manualIntervalMin,
        emptyCupWeightG: emptyCupWeightG ?? this.emptyCupWeightG,
        muted: muted ?? this.muted,
      );

  Map<String, dynamic> toPatch() => {
        'timer_mode': timerMode,
        'manual_interval_min': manualIntervalMin,
        'empty_cup_weight_g': emptyCupWeightG,
        'muted': muted,
      };
}

double _num(dynamic v, [double d = 0.0]) => v is num ? v.toDouble() : d;
int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
