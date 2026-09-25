import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/api_service.dart';
import '../core/app_theme.dart';
import '../core/auth_service.dart';
import '../models/machine_model.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MachineCard — Grid card with pulsing status dot.
/// ─────────────────────────────────────────────────────────────────────────────
class MachineCard extends StatelessWidget {
  final MachineModel machine;
  final VoidCallback onTap;

  const MachineCard({super.key, required this.machine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image / Icon area ─────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusCard)),
              child: Container(
                height: 90,
                color: const Color(0xFFF0F0F0),
                child: machine.imageUrl != null
                    ? Image.network(
                        machine.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) =>
                            _placeholder(machine.isOnline),
                      )
                    : _placeholder(machine.isOnline),
              ),
            ),

            // ── Info ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PulsingDot(
                        color: machine.isOnline
                            ? AppColors.completed
                            : AppColors.offline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        machine.isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: machine.isOnline
                              ? AppColors.completed
                              : AppColors.offline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    machine.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (machine.pricePerHour != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '\$${machine.pricePerHour!.toStringAsFixed(0)}/hr',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isOnline) {
    return Center(
      child: Icon(
        Icons.precision_manufacturing_rounded,
        size: 40,
        color: isOnline ? AppColors.textDisabled : AppColors.offline.withOpacity(0.4),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MachineBookingSheet — date/time picker + Report Issue
// ─────────────────────────────────────────────────────────────────────────────
class MachineBookingSheet extends StatefulWidget {
  final MachineModel machine;
  final VoidCallback onBookingDone;

  const MachineBookingSheet({
    super.key,
    required this.machine,
    required this.onBookingDone,
  });

  @override
  State<MachineBookingSheet> createState() => _MachineBookingSheetState();
}

class _MachineBookingSheetState extends State<MachineBookingSheet> {
  DateTime? _startDt;
  DateTime? _endDt;
  bool _booking = false;
  bool _reporting = false;

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;

    final dt = DateTime(
        date.year, date.month, date.day, time.hour, time.minute);
    setState(() {
      if (isStart) {
        _startDt = dt;
      } else {
        _endDt = dt;
      }
    });
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return 'Tap to select';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Future<void> _book() async {
    if (_startDt == null || _endDt == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select both start and end times.'),
        backgroundColor: AppColors.offline,
      ));
      return;
    }
    if (_endDt!.isBefore(_startDt!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('End time must be after start time.'),
        backgroundColor: AppColors.offline,
      ));
      return;
    }
    HapticFeedback.lightImpact();
    setState(() => _booking = true);
    try {
      await ApiService.instance.bookMachine(
        machineId: widget.machine.id,
        userName: AuthService.instance.displayName,
        startTime: _startDt!.toIso8601String(),
        endTime: _endDt!.toIso8601String(),
      );
      if (mounted) {
        widget.onBookingDone();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Machine booked! ✓',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF222222),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.offline,
        ));
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  Future<void> _reportIssue() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: const Text('Report Machine Issue',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.offline)),
        content: Text(
          'This will mark "${widget.machine.name}" as OFFLINE '
          'and notify the maintenance team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.offline,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Report Offline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();
    setState(() => _reporting = true);
    try {
      await ApiService.instance.reportMachineOffline(widget.machine.id);
      if (mounted) {
        widget.onBookingDone(); // Refresh machine list
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Machine reported as offline.',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.offline,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.offline,
        ));
      }
    } finally {
      if (mounted) setState(() => _reporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.machine;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const SizedBox(height: 16),

          // ── Header ───────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        PulsingDot(
                          color: m.isOnline
                              ? AppColors.completed
                              : AppColors.offline,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          m.isOnline ? 'Available' : 'Offline',
                          style: TextStyle(
                            color: m.isOnline
                                ? AppColors.completed
                                : AppColors.offline,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!m.isOnline)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.offline.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.warning_rounded,
                      color: AppColors.offline, size: 24),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Date pickers ─────────────────────────────────────────────────
          _timePicker(
            label: 'Start Time',
            value: _fmt(_startDt),
            onTap: () => _pickDateTime(isStart: true),
          ),
          const SizedBox(height: 12),
          _timePicker(
            label: 'End Time',
            value: _fmt(_endDt),
            onTap: () => _pickDateTime(isStart: false),
          ),
          const SizedBox(height: 28),

          // ── Book button ──────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: (_booking || !m.isOnline) ? null : _book,
              style: AppTheme.pillButtonStyle(
                bg: m.isOnline ? const Color(0xFF222222) : Colors.grey,
              ),
              child: _booking
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : const Text('Reserve This Machine'),
            ),
          ),

          // ── Report issue ─────────────────────────────────────────────────
          const SizedBox(height: 16),
          Center(
            child: _reporting
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: AppColors.offline, strokeWidth: 2.5))
                : TextButton.icon(
                    onPressed: _reportIssue,
                    icon: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.offline, size: 18),
                    label: const Text(
                      'Report Machine Issue',
                      style: TextStyle(
                        color: AppColors.offline,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded,
                color: AppColors.textDisabled, size: 20),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textDisabled,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
