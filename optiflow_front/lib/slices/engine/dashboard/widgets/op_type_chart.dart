import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';

/// Command Center horizontal bar chart — tasks grouped by operation type.
/// Each bar is a neon-colored animated fill with a glowing tip.
class OpTypeChart extends StatefulWidget {
  final Map<String, int> tasksByOpType;

  const OpTypeChart({super.key, required this.tasksByOpType});

  @override
  State<OpTypeChart> createState() => _OpTypeChartState();
}

class _OpTypeChartState extends State<OpTypeChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  static const _colors = [
    AppColors.matteBlue,
    AppColors.primary,
    AppColors.matteGreen,
    AppColors.matteAmber,
    AppColors.secondary,
    AppColors.matteRed,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
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
    final entries = widget.tasksByOpType.entries.toList();
    final maxVal = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final total = entries.fold(0, (sum, e) => sum + e.value);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.bar_chart_rounded,
                        color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Tasks by Operation Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Text(
                  '$total tasks',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (entries.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 40,
                        color: AppColors.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No task data yet.\nCreate jobs to see distribution.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: AnimatedBuilder(
                animation: _anim,
                builder: (_, __) => Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(entries.length, (i) {
                    final entry = entries[i];
                    final color = _colors[i % _colors.length];
                    final pct = entry.value / maxVal;

                    return _buildBar(
                      label: entry.key,
                      value: entry.value,
                      pct: pct * _anim.value,
                      color: color,
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required int value,
    required double pct,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.length > 18 ? '${label.substring(0, 16)}…' : label,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500),
            ),
            Text(
              '$value',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (ctx, constraints) {
          final maxW = constraints.maxWidth;
          final fillW = (maxW * pct).clamp(4.0, maxW);
          return Stack(
            children: [
              // Track
              Container(
                height: 6,
                width: maxW,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Fill
              Container(
                height: 6,
                width: fillW,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }
}
