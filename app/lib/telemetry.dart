// Model telemetry dan config RTDB; ALERT_EMPTY_CUP/MISSING_CUP dipetakan ke ALERT_REFILL.

// Diselaraskan dengan SmartHydrationCoaster/config.h.
const double kCupOffThresholdG = 25.0;
const double kCupOnThresholdG = 35.0;
const int kMinManualIntervalMin = 1;
const int kMaxManualIntervalMin = 180;
const int kDeviceStaleSeconds = 25;

class Telemetry {
  final double weightG;
  final double waterMl;
  final double tempC;
  final double humidityPct;
  final int remainingSec;
  final double targetIntervalMin;
  final double totalMl;
  final int drinkCount;
  final int refillCount;
  final int cheatCount;
  final bool muted;

  /// True saat sesi ditutup (berat tetap terkirim, siklus dan alarm nonaktif).
  final bool standby;

  final String rawState;

  /// Counter push firmware untuk membedakan alat diam dari alat mati.
  final int heartbeat;

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
    required this.standby,
    required this.rawState,
    required this.heartbeat,
  });

  factory Telemetry.fromJson(Map<String, dynamic> t) => Telemetry(
        weightG: _num(t['weight_g']),
        waterMl: _num(t['water_ml']),
        tempC: _num(t['temp_c']),
        humidityPct: _num(t['humidity_pct']),
        remainingSec: _int(t['remaining_sec']),
        targetIntervalMin: _num(t['target_interval_min']),
        totalMl: _num(t['total_ml']),
        drinkCount: _int(t['drink_count']),
        refillCount: _int(t['refill_count']),
        cheatCount: _int(t['cheat_count']),
        muted: t['muted'] == true,
        standby: t['standby'] == true,
        rawState: (t['fsm_state'] as String?) ?? 'IDLE',
        heartbeat: _int(t['hb']),
      );

  bool get cupPresent => weightG >= kCupOffThresholdG;

  String get canonicalState =>
      (rawState == 'ALERT_EMPTY_CUP' || rawState == 'ALERT_MISSING_CUP')
          ? 'ALERT_REFILL'
          : rawState;

  bool get missingCup => rawState == 'ALERT_MISSING_CUP';
  bool get emptyCup => rawState == 'ALERT_EMPTY_CUP';
  bool get isAlert => canonicalState.startsWith('ALERT_');

  /// Label ringkas badge state; alasan ditampilkan terpisah.
  String get stateName {
    switch (canonicalState) {
      case 'ALERT_REFILL':
        return 'REFILL';
      case 'ALERT_CHEAT':
        return 'CHEAT';
      default:
        return canonicalState.replaceAll('_', ' ');
    }
  }

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
  final String timerMode; // DEMO | AUTO_DHT | MANUAL
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
        manualIntervalMin: _int(j['manual_interval_min'], 30),
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
