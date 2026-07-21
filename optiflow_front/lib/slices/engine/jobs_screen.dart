import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:optiflow_scheduler/core/services/api_service.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/new_job_order.dart';

/// Jobs screen — two-pane layout:
///   Left: Existing jobs from Supabase (expandable, with tasks + Optimize button)
///   Right: New Job Order form
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  final Set<String> _expanded = {};
  final Map<String, bool> _optimizing = {};

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    final jobs = await SupabaseService.instance.fetchJobsWithTasks();
    if (mounted) setState(() { _jobs = jobs; _isLoading = false; });
  }

  Future<void> _optimizeJob(String jobId, List tasks) async {
    // Guard: cannot optimize a job with no tasks
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one task before optimizing.'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _optimizing[jobId] = true);
    try {
      final resp = await http.post(
        Uri.parse('${ApiService.baseUrl}/optimize/$jobId'),
      );
      if (!mounted) return;

      if (resp.statusCode == 200) {
        // Parse the rich response to show quality + makespan
        Map<String, dynamic> body = {};
        try { body = json.decode(resp.body) as Map<String, dynamic>; } catch (_) {}
        final quality  = body['quality']?.toString() ?? 'optimal';
        final makespan = body['makespan_minutes'];
        final skipped  = body['skipped_tasks'] as int? ?? 0;

        String msg = '✅ Schedule ${quality == 'optimal' ? 'optimally' : 'feasibly'} computed';
        if (makespan != null) msg += ' — makespan: ${makespan} min';
        if (skipped > 0)      msg += ' ($skipped task(s) skipped)';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: quality == 'optimal' ? AppColors.success : AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchJobs();
      } else {
        // Show the exact error detail from the backend, not just the status code
        String detail = 'Optimization failed (${resp.statusCode})';
        try {
          final body = json.decode(resp.body) as Map<String, dynamic>;
          detail = body['detail']?.toString() ?? detail;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(detail),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backend offline — start FastAPI to optimize.'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _optimizing[jobId] = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              // Two-pane on wide screens, single column on narrow
              if (constraints.maxWidth > 1000) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: _buildJobsList()),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 6,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: NewJobOrder(onJobCreated: _fetchJobs),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  _buildJobsList(),
                  const SizedBox(height: 32),
                  NewJobOrder(onJobCreated: _fetchJobs),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Jobs",
          style: TextStyle(
            fontSize: 36, fontWeight: FontWeight.w800,
            color: AppColors.textPrimary, letterSpacing: -1,
          ),
        ),
        SizedBox(height: 8),
        Text(
          "View existing print jobs, their tasks, and create new orders.",
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildJobsList() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Existing Jobs (${_jobs.length})",
                  style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  tooltip: 'Refresh',
                  onPressed: _fetchJobs,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.surfaceLight.withOpacity(0.5)),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_jobs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48,
                        color: AppColors.textSecondary.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      'No jobs yet.\nCreate your first job order on the right.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.7),
                        fontStyle: FontStyle.italic, fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _jobs.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AppColors.surfaceLight.withOpacity(0.3)),
              itemBuilder: (_, i) => _buildJobTile(_jobs[i]),
            ),
        ],
      ),
    );
  }

  Widget _buildJobTile(Map<String, dynamic> job) {
    final jobId = job['id']?.toString() ?? '';
    final isExpanded = _expanded.contains(jobId);
    final tasks = (job['tasks'] as List?) ?? [];
    final isOptimizing = _optimizing[jobId] == true;

    final status = job['status']?.toString() ?? 'DRAFT';
    final deadline = _formatDeadline(job['deadline']);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) _expanded.remove(jobId);
              else _expanded.add(jobId);
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                // Status dot
                Container(
                  width: 10, height: 10,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(status),
                  ),
                ),
                // Title & client
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job['title']?.toString() ?? 'Untitled',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${job['client_name'] ?? 'Unknown'} · ${_formatQty(job['total_quantity'])} units',
                        style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Deadline
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _statusBadge(status),
                    const SizedBox(height: 4),
                    Text(
                      deadline,
                      style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Expand chevron
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),

        // Expanded task list + optimize button
        if (isExpanded)
          Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceLight.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tasks header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tasks (${tasks.length})',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    // Optimize button — disabled for COMPLETED jobs
                    Builder(builder: (ctx) {
                      final isCompleted = status == 'COMPLETED';
                      final canOptimize = !isOptimizing && !isCompleted;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: canOptimize ? AppColors.primaryGradient : null,
                          color: canOptimize ? null : AppColors.surfaceLight.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: canOptimize ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8, offset: const Offset(0, 4),
                            ),
                          ] : null,
                        ),
                        child: Tooltip(
                          message: isCompleted
                              ? 'Job is already completed'
                              : tasks.isEmpty
                                  ? 'Add tasks before optimizing'
                                  : 'Run CP-SAT optimizer',
                          child: ElevatedButton.icon(
                            onPressed: canOptimize ? () => _optimizeJob(jobId, tasks) : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: isOptimizing
                                ? const SizedBox(
                                    width: 14, height: 14,
                                    child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isCompleted ? Icons.check_circle_outline : Icons.auto_fix_high,
                                    color: canOptimize ? Colors.white : AppColors.textSecondary,
                                    size: 16,
                                  ),
                            label: Text(
                              isOptimizing ? 'Optimizing…' : isCompleted ? 'Completed' : 'Optimize',
                              style: TextStyle(
                                color: canOptimize ? Colors.white : AppColors.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  ],
                ),
                const SizedBox(height: 12),
                if (tasks.isEmpty)
                  Text(
                    'No tasks defined for this job.',
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.6),
                      fontStyle: FontStyle.italic, fontSize: 13,
                    ),
                  )
                else
                  ...tasks.map<Widget>((task) => _buildTaskRow(task)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task) {
    final opTypeName =
        (task['operation_types'] as Map?)?['name']?.toString() ?? task['operation_type_id']?.toString() ?? '—';
    final resourceName = (task['resources'] as Map?)?['name']?.toString() ?? 'Unassigned';
    final taskStatus = task['status']?.toString() ?? 'PENDING';
    final qty = task['quantity_to_process'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.subdirectory_arrow_right_rounded,
              size: 16, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['name']?.toString() ?? 'Unnamed Task',
                  style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$opTypeName · $qty units · $resourceName',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.8), fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _taskStatusBadge(taskStatus),
          const SizedBox(width: 8),
          Builder(
            builder: (ctx) {
              final isVisible = task['show_in_mobile'] == true;
              return Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isVisible ? AppColors.primary.withOpacity(0.15) : AppColors.surfaceLight.withOpacity(0.3),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: isVisible ? 'Hide from Mobile App' : 'Show in Mobile App',
                  icon: Icon(
                    isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                    size: 16,
                    color: isVisible ? AppColors.primary : AppColors.textSecondary.withOpacity(0.5),
                  ),
                  onPressed: () async {
                    try {
                      await SupabaseService.instance.toggleTaskMobileVisibility(
                        task['id'].toString(),
                        !isVisible,
                      );
                      _fetchJobs();
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Failed to update visibility')),
                        );
                      }
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _taskStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'COMPLETED':   color = AppColors.success; break;
      case 'IN_PROGRESS': color = AppColors.info; break;
      case 'SCHEDULED':   color = AppColors.secondary; break;
      default:            color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':   return AppColors.success;
      case 'IN_PROGRESS':
      case 'SCHEDULED':   return AppColors.info;
      case 'OPEN':        return AppColors.secondary;
      default:            return AppColors.textSecondary; // DRAFT
    }
  }

  String _formatDeadline(dynamic raw) {
    if (raw == null) return 'No deadline';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return 'Due ${DateFormat('MMM d, yyyy').format(dt)}';
    } catch (_) { return 'No deadline'; }
  }

  String _formatQty(dynamic qty) {
    if (qty == null) return '0';
    final n = int.tryParse(qty.toString()) ?? 0;
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}
