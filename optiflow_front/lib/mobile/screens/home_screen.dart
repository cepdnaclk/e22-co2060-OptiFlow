import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';
import '../core/app_theme.dart';
import '../core/auth_service.dart';
import '../models/task_model.dart';
import '../widgets/shimmer_card.dart';
import '../widgets/task_card.dart';
import '../widgets/task_bottom_sheet.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// HomeScreen — "My Tasks" execution hub.
///
/// Layout:
///  • SliverAppBar  — "Good Morning, [Name]"
///  • ACTIVE NOW    — horizontal carousel of IN_PROGRESS tasks
///  • UP NEXT       — vertical SliverList of SCHEDULED tasks
///  • Empty state   — no tasks today
/// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TaskModel> _tasks = [];
  bool _loading = true;
  String? _error;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });

    try {
      // Fetch all tasks from Supabase directly — works without FastAPI.
      // For MVP: shows the whole factory floor view (all tasks, all machines).
      final raw = await SupabaseService.instance.fetchAllTasks();
      final tasks = raw.map((json) {
        // Remap Supabase join shape → TaskModel.fromJson expected shape
        return TaskModel.fromJson({
          ...json,
          'job_title': (json['jobs'] as Map?)?['title'],
          'resource_name': (json['resources'] as Map?)?['name'],
          'operation_type_id': (json['operation_types'] as Map?)?['name'] ?? json['operation_type_id'],
        });
      }).toList();

      // Sort: IN_PROGRESS first, then PENDING, then SCHEDULED, then COMPLETED
      tasks.sort((a, b) {
        const order = {'IN_PROGRESS': 0, 'PENDING': 1, 'SCHEDULED': 2, 'COMPLETED': 3};
        return (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
      });
      if (mounted) setState(() { _tasks = tasks; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openTaskSheet(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskBottomSheet(
        task: task,
        onStatusChanged: _loadTasks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.instance.displayName;
    final inProgress = _tasks.where((t) => t.status == 'IN_PROGRESS').toList();
    // Show PENDING and SCHEDULED tasks together in the UP NEXT section
    final pending = _tasks.where((t) => t.status == 'PENDING' || t.status == 'SCHEDULED').toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── SliverAppBar ─────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 130,
              pinned: true,
              backgroundColor: AppColors.background,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                expandedTitleScale: 1.4,
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.12),
                    radius: 18,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'W',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Loading state ────────────────────────────────────────────────
            if (_loading) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text('ACTIVE NOW',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textDisabled)),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: const [
                      Padding(
                        padding: EdgeInsets.only(right: 16),
                        child: ShimmerCard(width: 260, height: 200),
                      ),
                      ShimmerCard(width: 260, height: 200),
                    ],
                  ),
                ),
              ),
              const ShimmerList(count: 3),
            ]

            // ── Error state ──────────────────────────────────────────────────
            else if (_error != null)
              SliverFillRemaining(
                child: _errorState(),
              )

            // ── Empty state ──────────────────────────────────────────────────
            else if (_tasks.isEmpty)
              SliverFillRemaining(
                child: _emptyState(),
              )

            // ── Content ──────────────────────────────────────────────────────
            else ...[
              // "Active Now" carousel
              if (inProgress.isNotEmpty) ...[
                _sectionHeader('ACTIVE NOW'),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 220,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      physics: const BouncingScrollPhysics(),
                      itemCount: inProgress.length,
                      itemBuilder: (_, i) => TaskCard(
                        task: inProgress[i],
                        isCarousel: true,
                        onTap: () => _openTaskSheet(inProgress[i]),
                      ),
                    ),
                  ),
                ),
              ],

              // "Up Next" list — PENDING + SCHEDULED
              if (pending.isNotEmpty) ...[
                _sectionHeader('UP NEXT — ${pending.length} TASK${pending.length > 1 ? 'S' : ''}'),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => TaskCard(
                        task: pending[i],
                        onTap: () => _openTaskSheet(pending[i]),
                      ),
                      childCount: pending.length,
                    ),
                  ),
                ),
              ],

              // Completed today (optional - collapsed summary)
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: AppColors.textDisabled,
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppColors.completed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.done_all_rounded,
                  size: 44, color: AppColors.completed),
            ),
            const SizedBox(height: 24),
            const Text(
              'All caught up!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have no tasks assigned for today.\nCheck back later or explore the Job Market.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppColors.offline.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 44, color: AppColors.offline),
            ),
            const SizedBox(height: 24),
            const Text('Connection Error',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              _error!.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () { HapticFeedback.lightImpact(); _loadTasks(); },
              style: AppTheme.pillButtonStyle(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
