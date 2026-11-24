import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

class ChartSlice {
  const ChartSlice({
    required this.id,
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    required this.icon,
  });

  final String id;
  final String label;
  final double value;
  final double percent;
  final Color color;
  final IconData icon;
}

class PercentageDonutChart extends StatelessWidget {
  const PercentageDonutChart({
    super.key,
    required this.slices,
    required this.total,
    required this.centerSubtitle,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ChartSlice> slices;
  final double total;
  final String centerSubtitle;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final selected = slices.where((s) => s.id == selectedId).firstOrNull;
    const double chartSize = 204;

    return GestureDetector(
      onTapDown: (details) {
        if (slices.isEmpty || total <= 0) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.globalPosition);
        final center = Offset(box.size.width / 2, box.size.height / 2);
        final dx = local.dx - center.dx;
        final dy = local.dy - center.dy;
        final dist = math.sqrt(dx * dx + dy * dy);
        final outerRadius = chartSize / 2;
        final innerRadius = outerRadius - 38;
        if (dist < innerRadius || dist > outerRadius + 8) {
          onSelect(null);
          return;
        }
        var angle = math.atan2(dy, dx) + math.pi / 2;
        if (angle < 0) angle += 2 * math.pi;

        double start = 0;
        for (final slice in slices) {
          final sweep = (slice.value / total) * 2 * math.pi;
          if (angle >= start && angle <= start + sweep) {
            onSelect(selectedId == slice.id ? null : slice.id);
            return;
          }
          start += sweep;
        }
      },
      child: SizedBox(
        width: chartSize,
        height: chartSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutCubic,
              builder: (context, progress, _) {
                return CustomPaint(
                  size: const Size(chartSize, chartSize),
                  painter: _DonutPainter(
                    slices: slices,
                    total: total,
                    selectedId: selectedId,
                    progress: progress,
                  ),
                );
              },
            ),
            SizedBox(
              width: chartSize - 76,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    selected != null
                        ? formatPercent(selected.percent)
                        : (total > 0 ? '100%' : '0%'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: selected?.color ?? AppColors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    selected != null ? selected.label : centerSubtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatCurrency(selected != null ? selected.value : total),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.selectedId,
    required this.progress,
  });

  final List<ChartSlice> slices;
  final double total;
  final String? selectedId;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.shortestSide / 2) - 18;

    // Subtle track ring
    final trackPaint = Paint()
      ..color = AppColors.primarySoft
      ..style = PaintingStyle.stroke
      ..strokeWidth = 24;
    canvas.drawCircle(center, baseRadius, trackPaint);

    if (slices.isEmpty || total <= 0) return;

    double startAngle = -math.pi / 2;
    final gapRadians = slices.length > 1 ? 0.032 : 0.0;

    for (final slice in slices) {
      final fraction = slice.value / total;
      final fullSweep = fraction * 2 * math.pi * progress;
      final sweep = math.max(0.0, fullSweep - gapRadians);
      final isSelected = selectedId == slice.id;
      final isDimmed = selectedId != null && !isSelected;

      final paint = Paint()
        ..color = isDimmed ? slice.color.withValues(alpha: 0.35) : slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 30 : 24
        ..strokeCap = StrokeCap.butt;

      final rect = Rect.fromCircle(
        center: center,
        radius: isSelected ? baseRadius + 2 : baseRadius,
      );
      canvas.drawArc(
        rect,
        startAngle + (gapRadians / 2),
        sweep,
        false,
        paint,
      );

      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.total != total ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.progress != progress;
  }
}
