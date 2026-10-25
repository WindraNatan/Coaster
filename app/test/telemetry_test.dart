// Uji kontrak telemetry/config: parsing field cloud, pemetaan state turunan
// (CLAUDE.md §3), dan formatter countdown. Jalankan: flutter test
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_coaster/telemetry.dart';

void main() {
  group('Telemetry.fromJson', () {
    test('parses int dan double numerik RTDB', () {
      final t = Telemetry.fromJson({
        'weight_g': 315,
        'water_ml': 185.5,
        'temp_c': 27,
        'humidity_pct': 61.2,
        'remaining_sec': 423,
        'target_interval_min': 45,
        'total_ml': 750,
        'drink_count': 3,
        'refill_count': 1,
        'cheat_count': 2,
        'muted': true,
        'fsm_state': 'TIMING',
      });
      expect(t.weightG, 315.0);
      expect(t.waterMl, 185.5);
      expect(t.tempC, 27.0);
      expect(t.remainingSec, 423);
      expect(t.targetIntervalMin, 45.0);
      expect(t.totalMl, 750);
      expect(t.drinkCount, 3);
      expect(t.refillCount, 1);
      expect(t.cheatCount, 2);
      expect(t.muted, isTrue);
      expect(t.rawState, 'TIMING');
      expect(t.canonicalState, 'TIMING');
      expect(t.isAlert, isFalse);
      expect(t.cupPresent, isTrue);
    });

    test('field kosong tidak melempar exception', () {
      final t = Telemetry.fromJson({'fsm_state': 'IDLE'});
      expect(t.weightG, 0.0);
      expect(t.remainingSec, 0);
      expect(t.muted, isFalse);
      expect(t.cupPresent, isFalse);
      expect(t.reason, 'taruh gelas untuk mulai');
    });

    test('ALERT_MISSING_CUP -> ALERT_REFILL + flag missing', () {
      final t = Telemetry.fromJson({'fsm_state': 'ALERT_MISSING_CUP'});
      expect(t.canonicalState, 'ALERT_REFILL');
      expect(t.missingCup, isTrue);
      expect(t.emptyCup, isFalse);
      expect(t.isAlert, isTrue);
      expect(t.reason, 'gelas belum kembali ke tatakan');
    });

    test('ALERT_EMPTY_CUP -> ALERT_REFILL tanpa flag missing', () {
      final t = Telemetry.fromJson({'fsm_state': 'ALERT_EMPTY_CUP'});
      expect(t.canonicalState, 'ALERT_REFILL');
      expect(t.missingCup, isFalse);
      expect(t.emptyCup, isTrue);
      expect(t.reason, 'gelas kosong, silakan isi ulang');
    });

    test('state 7-state lain tetap apa adanya', () {
      for (final s in [
        'IDLE',
        'STABLE',
        'TIMING',
        'LIFTED',
        'ALERT_DRINK',
        'ALERT_CHEAT',
        'ALERT_REFILL'
      ]) {
        final t = Telemetry.fromJson({'fsm_state': s});
        expect(t.canonicalState, s);
        expect(t.missingCup || t.emptyCup, isFalse);
      }
      expect(Telemetry.fromJson({'fsm_state': 'ALERT_CHEAT'}).reason,
          'berat kembali tanpa minum cukup (< 20 g)');
      expect(Telemetry.fromJson({'fsm_state': 'ALERT_DRINK'}).reason,
          'saatnya minum air!');
    });
  });

  group('mmss', () {
    test('format mm:ss dengan padding', () {
      expect(Telemetry.mmss(0), '00:00');
      expect(Telemetry.mmss(5), '00:05');
      expect(Telemetry.mmss(65), '01:05');
      expect(Telemetry.mmss(423), '07:03');
      expect(Telemetry.mmss(3599), '59:59');
    });

    test('nilai negatif di-clamp ke 00:00', () {
      expect(Telemetry.mmss(-10), '00:00');
    });
  });

  group('CloudConfig', () {
    test('default saat node config belum ada', () {
      final c = CloudConfig.fromJson({});
      expect(c.timerMode, 'AUTO_DHT');
      expect(c.manualIntervalMin, 30);
      expect(c.muted, isFalse);
    });

    test('parsing dan toPatch round-trip', () {
      final c = CloudConfig.fromJson({
        'timer_mode': 'MANUAL',
        'manual_interval_min': 90,
        'empty_cup_weight_g': 132,
        'muted': true,
      });
      expect(c.timerMode, 'MANUAL');
      expect(c.manualIntervalMin, 90);
      expect(c.emptyCupWeightG, 132.0);
      expect(c.toPatch(), {
        'timer_mode': 'MANUAL',
        'manual_interval_min': 90,
        'empty_cup_weight_g': 132.0,
        'muted': true,
      });
    });

    test('copyWith hanya mengubah field yang diminta', () {
      const c = CloudConfig(
          timerMode: 'AUTO_DHT',
          manualIntervalMin: 30,
          emptyCupWeightG: 130,
          muted: false);
      final m = c.copyWith(muted: true, timerMode: 'MANUAL');
      expect(m.muted, isTrue);
      expect(m.timerMode, 'MANUAL');
      expect(m.manualIntervalMin, 30);
      expect(m.emptyCupWeightG, 130);
    });
  });

  group('batas interval manual', () {
    test('konstanta sesuai config.h', () {
      expect(kMinManualIntervalMin, 1);
      expect(kMaxManualIntervalMin, 180);
    });
  });
}
