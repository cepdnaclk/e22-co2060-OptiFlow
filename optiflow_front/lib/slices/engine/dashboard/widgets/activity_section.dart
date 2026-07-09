import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LIVE ALERTS — Command Center style
// ─────────────────────────────────────────────────────────────────────────────
class LiveAlerts extends StatefulWidget {
  const LiveAlerts({super.key});

  @override
  State<LiveAlerts> createState() => _LiveAlertsState();
}

class _LiveAlertsState extends State<LiveAlerts> {
  bool _isLoading = true;
  List<dynamic> _offlineMachines = [];
  List<dynamic> _overdueJobs = [];

  @override
  void initState() {
    super.initState();
    _fetchAlerts();
  }

  Future<void> _fetchAlerts() async {
    final stats = await SupabaseService.instance.fetchDashboardStats();
    if (mounted) {
      setState(() {
        _offlineMachines = (stats['offline_machines'] as List?) ?? [];
        _overdueJobs     = (stats['overdue_jobs']     as List?) ?? [];
        _isLoading       = false;
      });
    }
  }

  int get _alertCount => _offlineMachines.length + _overdueJobs.length;

  @override
  Widget build(BuildContext context) {
    return _CommandCard(
      title: 'Live Alerts',
      icon: Icons.notifications_active_rounded,
      iconColor: _alertCount > 0 ? AppColors.matteRed : AppColors.matteGreen,
      trailing: _alertCount > 0
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.matteRed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.matteRed.withOpacity(0.3)),
              ),
              child: Text(
                '$_alertCount',
                style: const TextStyle(
                    color: AppColors.matteRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            )
          : null,
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            )
          : _alertCount == 0
              ? _AlertRow(
                  icon: Icons.check_circle_outline_rounded,
                  title: 'All Clear',
                  subtitle: 'No active alerts.',
                  color: AppColors.matteGreen,
                )
              : Column(
                  children: [
                    ..._offlineMachines.map(
                      (m) => _AlertRow(
                        icon: Icons.power_off_rounded,
                        title: m['name'] as String? ?? 'Machine',
                        subtitle: 'OFFLINE — requires attention',
                        color: AppColors.matteRed,
                      ),
                    ),
                    ..._overdueJobs.map(
                      (j) => _AlertRow(
                        icon: Icons.schedule_rounded,
                        title: j['title'] as String? ?? 'Job',
                        subtitle: 'Deadline exceeded',
                        color: AppColors.matteAmber,
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECENT ACTIVITY — Command Center feed style
// ─────────────────────────────────────────────────────────────────────────────
class RecentActivity extends StatefulWidget {
  const RecentActivity({super.key});

  @override
  State<RecentActivity> createState() => _RecentActivityState();
}

class _RecentActivityState extends State<RecentActivity> {
  bool _isLoading = true;
  List<dynamic> _recentTasks = [];
  List<dynamic> _newJobs     = [];

  @override
  void initState() {
    super.initState();
    _fetchActivity();
  }

  Future<void> _fetchActivity() async {
    final stats = await SupabaseService.instance.fetchDashboardStats();
    if (mounted) {
      setState(() {
        _recentTasks = (stats['recent_tasks'] as List?) ?? [];
        _newJobs     = (stats['new_jobs']     as List?) ?? [];
        _isLoading   = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CommandCard(
      title: 'Activity Feed',
      icon: Icons.timeline_rounded,
      iconColor: AppColors.matteBlue,
      child: _isLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ),
            )
          : (_recentTasks.isEmpty && _newJobs.isEmpty)
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No recent activity.',
                      style: TextStyle(
                          color: AppColors.textMuted.withOpacity(0.7),
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : Column(
                  children: [
                    ..._recentTasks.map((t) {
                      final jobTitle =
                          t['jobs']?['title'] as String? ?? 'Job';
                      final resource =
                          t['resources']?['name'] as String? ?? 'Resource';
                      return _FeedRow(
                        color: AppColors.matteGreen,
                        title: t['name'] as String? ?? 'Task',
                        subtitle: '$jobTitle · $resource',
                        tag: 'COMPLETED',
                        tagColor: AppColors.matteGreen,
                        time: _timeAgo(t['completed_at']),
                      );
                    }),
                    ..._newJobs.map((j) => _FeedRow(
                          color: AppColors.matteBlue,
                          title: j['title'] as String? ?? 'Job',
                          subtitle:
                              'Status: ${j['status'] as String? ?? 'DRAFT'}',
                          tag: 'NEW JOB',
                          tagColor: AppColors.matteBlue,
                          time: _timeAgo(j['created_at']),
                        )),
                  ],
                ),
    );
  }

  String _timeAgo(String? iso) {
    if (iso == null) return '—';
    try {
      final diff = DateTime.now().difference(DateTime.parse(iso).toLocal());
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)  return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '—';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENT: Command Center card shell
// ─────────────────────────────────────────────────────────────────────────────
class _CommandCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final Widget child;

  const _CommandCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENT: Alert row
// ─────────────────────────────────────────────────────────────────────────────
class _AlertRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _AlertRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENT: Activity feed row
// ─────────────────────────────────────────────────────────────────────────────
class _FeedRow extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final String time;

  const _FeedRow({
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline dot + line
          Column(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tagColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: tagColor.withOpacity(0.25)),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        subtitle,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
