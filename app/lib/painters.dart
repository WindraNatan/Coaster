import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Visualizer tumbler kaca dan tatakan stoneware dengan bayangan kontak fisik.
class CoasterGlassPainter extends CustomPainter {
  final double fill;
  final bool present;

  const CoasterGlassPainter({
    required this.fill,
    required this.present,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h - 10, w * 0.76, 6),
      const Radius.circular(6),
    );
    final shadowPaint = Paint()
      ..color = ShcPalette.ink.withValues(alpha: present ? 0.16 : 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(shadowRect, shadowPaint);

    final coasterRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h - 15, w * 0.84, 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      coasterRect,
      Paint()
        ..color = present ? ShcPalette.subtle : ShcPalette.subtle.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      coasterRect,
      Paint()
        ..color = present ? ShcPalette.controlBorder : ShcPalette.hairline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    const insetX = 15.0;
    const topY = 10.0;
    final bottomY = h - 18.0;
    final glassRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(insetX, topY, w - insetX, bottomY),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      glassRect,
      Paint()
        ..color = present ? ShcPalette.surface : ShcPalette.canvas
        ..style = PaintingStyle.fill,
    );

    if (present && fill > 0) {
      final totalWaterHeight = (bottomY - topY - 4) * fill.clamp(0.0, 1.0);
      final waterTopY = bottomY - totalWaterHeight;
      final waterRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(insetX + 2, waterTopY, w - insetX - 2, bottomY - 2),
        const Radius.circular(10),
      );

      canvas.save();
      canvas.clipRRect(glassRect);

      final waterPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ShcPalette.waterTop,
            ShcPalette.accent,
          ],
        ).createShader(Rect.fromLTRB(insetX, waterTopY, w - insetX, bottomY));
      canvas.drawRRect(waterRect, waterPaint);

      canvas.drawLine(
        Offset(insetX + 6, waterTopY + 1),
        Offset(w - insetX - 6, waterTopY + 1),
        Paint()
          ..color = ShcPalette.surface.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      if (totalWaterHeight > 12) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(insetX + 5, waterTopY + 4, 3, totalWaterHeight - 8),
            const Radius.circular(2),
          ),
          Paint()
            ..color = ShcPalette.surface.withValues(alpha: 0.24)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.restore();
    }

    canvas.drawRRect(
      glassRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = present ? 2 : 1.5
        ..color = present ? ShcPalette.controlBorder : ShcPalette.hairline,
    );

    if (present) {
      canvas.drawLine(
        Offset(insetX + 4, bottomY - 6),
        Offset(w - insetX - 4, bottomY - 6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = ShcPalette.hairline,
      );

      final tickPaint = Paint()
        ..color = ShcPalette.controlBorder.withValues(alpha: 0.8)
        ..strokeWidth = 1;
      for (final fraction in const [0.25, 0.50, 0.75]) {
        final tickY = bottomY - (bottomY - topY) * fraction;
        canvas.drawLine(
          Offset(w - insetX - 6, tickY),
          Offset(w - insetX - 2, tickY),
          tickPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CoasterGlassPainter old) =>
      old.fill != fill || old.present != present;
}

/// Cincin progres hidrasi harian.
class HydrationRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const HydrationRingPainter({
    required this.progress,
    this.trackColor = const Color(0xFFBCC7C3),
    this.progressColor = ShcPalette.accent,
    this.strokeWidth = 11.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..color = progressColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HydrationRingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor ||
      old.strokeWidth != strokeWidth;
}

/// Daftar batang progres riwayat harian (maksimal 7 hari terakhir).
class HistoryBarsList extends StatelessWidget {
  final List<MapEntry<String, Map<String, dynamic>>> entries;
  final int goalMl;

  const HistoryBarsList({
    super.key,
    required this.entries,
    required this.goalMl,
  });

  @override
  Widget build(BuildContext context) {
    var maxBar = goalMl > 0 ? goalMl.toDouble() : 2000.0;
    for (final e in entries) {
      final ml = (e.value['total_ml'] as num? ?? 0).toDouble();
      if (ml > maxBar) maxBar = ml;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          _HistoryRow(
            dateKey: entries[i].key,
            totalMl: (entries[i].value['total_ml'] as num? ?? 0).toDouble(),
            drinkCount: (entries[i].value['drink_count'] as num?)?.toInt(),
            maxBar: maxBar,
            highlight: i == 0 ||
                (entries[i].value['total_ml'] as num? ?? 0).toDouble() >= goalMl,
            goalMet:
                (entries[i].value['total_ml'] as num? ?? 0).toDouble() >= goalMl,
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String dateKey;
  final double totalMl;
  final int? drinkCount;
  final double maxBar;
  final bool highlight;
  final bool goalMet;

  const _HistoryRow({
    required this.dateKey,
    required this.totalMl,
    required this.drinkCount,
    required this.maxBar,
    required this.highlight,
    required this.goalMet,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxBar > 0 ? (totalMl / maxBar).clamp(0.0, 1.0) : 0.0;
    final mlLabel = '${totalMl.toStringAsFixed(1)} ml';
    final countPart = drinkCount != null ? ', $drinkCount kali minum' : '';
    final goalPart = goalMet ? ', target tercapai' : '';
    final semLabel = '$dateKey: $mlLabel$countPart$goalPart';

    return Semantics(
      label: semLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateKey,
                    style: shcMono(12, color: ShcPalette.ink, weight: FontWeight.w500),
                  ),
                ),
                if (drinkCount != null) ...[
                  Text(
                    '${drinkCount}x',
                    style: shcMono(11, color: ShcPalette.muted),
                  ),
                  const SizedBox(width: 8),
                ],
                if (goalMet) ...[
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: ShcPalette.accent,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  mlLabel,
                  style: shcMono(
                    12,
                    color: highlight ? ShcPalette.accent : ShcPalette.inkSoft,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                color: ShcPalette.subtle,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: ShcPalette.controlBorder.withValues(alpha: 0.45),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio > 0 ? ratio.clamp(0.03, 1.0) : 0.0,
                  minHeight: 7,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(
                    highlight ? ShcPalette.accent : ShcPalette.controlBorder,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
