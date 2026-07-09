import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';

/// Command Center machine utilization — replaces the basic pie chart
/// with an animated neon arc meter and status row indicators.
class UtilizationChart extends StatefulWidget {
  final int activeMachines;
  final int idleMachines;
  final int offlineMachines;

  const UtilizationChart({
    super.key,
    required this.activeMachines,
    required this.idleMachines,
    required this.offlineMachines,
  });

  @override
  State<UtilizationChart> createState() => _UtilizationChartState();
}

class _UtilizationChartState extends State<UtilizationChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.activeMachines + widget.idleMachines + widget.offlineMachines;
    final activePct = total == 0 ? 0.0 : widget.activeMachines / total;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.matteBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.precision_manufacturing_rounded,
                    color: AppColors.matteBlue, size: 14),
              ),
              const SizedBox(width: 10),
              const Text(
                'Machine Utilization',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Arc meter
          Expanded(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => CustomPaint(
                painter: _ArcMeterPainter(
                  activePct: activePct * _anim.value,
                  idlePct: total == 0
                      ? 0
                      : (widget.idleMachines / total) * _anim.value,
                  offlinePct: total == 0
                      ? 0
                      : (widget.offlineMachines / total) * _anim.value,
                  textPct: activePct,
                  total: total,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildRow(AppColors.matteGreen,  'Active',  '${widget.activeMachines}/$total'),
          const SizedBox(height: 8),
          _buildRow(AppColors.matteAmber, 'Idle',    '${widget.idleMachines}'),
          const SizedBox(height: 8),
          _buildRow(AppColors.matteRed,   'Offline', '${widget.offlineMachines}'),
        ],
      ),
    );
  }

  Widget _buildRow(Color color, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      ],
    );
  }
}

class _ArcMeterPainter extends CustomPainter {
  final double activePct;
  final double idlePct;
  final double offlinePct;
  final double textPct;
  final int total;

  _ArcMeterPainter({
    required this.activePct,
    required this.idlePct,
    required this.offlinePct,
    required this.textPct,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.58;
    final r  = math.min(cx, cy) * 0.82;
    const startAngle = math.pi;
    const sweepTotal = math.pi; // Half circle

    final trackPaint = Paint()
      ..color = AppColors.surfaceLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      startAngle,
      sweepTotal,
      false,
      trackPaint,
    );

    // Active (green)
    _drawArc(canvas, cx, cy, r, startAngle, sweepTotal * activePct,
        AppColors.matteGreen);
    // Idle (amber)
    _drawArc(canvas, cx, cy, r, startAngle + sweepTotal * activePct,
        sweepTotal * idlePct, AppColors.matteAmber);
    // Offline (red)
    _drawArc(
        canvas,
        cx,
        cy,
        r,
        startAngle + sweepTotal * activePct + sweepTotal * idlePct,
        sweepTotal * offlinePct,
        AppColors.matteRed);

    // Centre text
    final pct = (textPct * 100).toStringAsFixed(0);
    _drawCentreText(canvas, Offset(cx, cy - 6), '$pct%',
        const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ));
    _drawCentreText(canvas, Offset(cx, cy + 22), 'uptime',
        const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ));
  }

  void _drawArc(Canvas canvas, double cx, double cy, double r,
      double start, double sweep, Color color) {
    if (sweep <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..color = color;
    
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep, false, paint);
  }

  void _drawCentreText(
      Canvas canvas, Offset offset, String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ArcMeterPainter old) =>
      old.activePct != activePct ||
      old.idlePct != idlePct ||
      old.offlinePct != offlinePct;
}
