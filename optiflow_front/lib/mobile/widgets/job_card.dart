import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api_service.dart';
import '../core/app_theme.dart';
import '../core/auth_service.dart';
import '../models/job_model.dart';

/// Card for the Job Market feed — shows title, client, quantity badge, deadline.
class JobCard extends StatelessWidget {
  final JobModel job;
  final VoidCallback onTap;

  const JobCard({super.key, required this.job, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                StatusBadge(status: job.status),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    job.formattedDeadline,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              job.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              job.clientName,
              style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 16, color: AppColors.textDisabled),
                const SizedBox(width: 6),
                Text(
                  '${job.totalQuantity} units',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textDisabled),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Job Bottom Sheet — shows details and Claim Job action
// ─────────────────────────────────────────────────────────────────────────────
class JobBottomSheet extends StatefulWidget {
  final JobModel job;
  final VoidCallback onJobClaimed;

  const JobBottomSheet({
    super.key,
    required this.job,
    required this.onJobClaimed,
  });

  @override
  State<JobBottomSheet> createState() => _JobBottomSheetState();
}

class _JobBottomSheetState extends State<JobBottomSheet> {
  bool _loading = false;

  Future<void> _claimJob() async {
    HapticFeedback.lightImpact();
    setState(() => _loading = true);
    try {
      await ApiService.instance.claimJob(
        jobId: widget.job.id,
        workerName: AuthService.instance.displayName,
      );
      if (mounted) {
        widget.onJobClaimed();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Job claimed! Get to work. 💪',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
          content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.offline,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
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

          StatusBadge(status: j.status),
          const SizedBox(height: 12),

          Text(
            j.title,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            j.clientName,
            style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 28),

          _row(Icons.inventory_2_outlined, 'Total Quantity',
              '${j.totalQuantity} units'),
          const SizedBox(height: 14),
          _row(Icons.calendar_today_rounded, 'Deadline', j.formattedDeadline),

          const SizedBox(height: 32),

          if (j.status == 'OPEN')
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _loading ? null : _claimJob,
                style: AppTheme.pillButtonStyle(),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Text('Claim This Job'),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.textDisabled.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              alignment: Alignment.center,
              child: Text(
                'Already Taken',
                style: TextStyle(
                    color: AppColors.textDisabled,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textDisabled,
                    fontWeight: FontWeight.w500)),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }
}
