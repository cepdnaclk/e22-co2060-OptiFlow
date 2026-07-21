import 'package:supabase_flutter/supabase_flutter.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SupabaseService — direct Supabase query layer for ALL read operations.
///
/// Key design:
///  • fetchDashboardStats() runs 3 sub-queries in PARALLEL (Future.wait) not
///    sequentially, cutting load time by ~3×.
///  • Results are cached for 60 seconds so multiple widget calls (Dashboard,
///    LiveAlerts, RecentActivity) reuse the same response instead of firing
///    9 separate network requests.
///  • nullsFirst removed — not supported in supabase_flutter ^2.5.x.
/// ─────────────────────────────────────────────────────────────────────────────
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ── Simple 60-second in-memory cache for dashboard stats ──────────────────
  Map<String, dynamic>? _statsCache;
  DateTime? _statsCacheTime;

  void invalidateCache() {
    _statsCache = null;
    _statsCacheTime = null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // RESOURCES / MACHINES
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchResources() async {
    try {
      final res = await _db.from('resources').select('*').order('name');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchResources: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchMachines() async {
    try {
      final res = await _db
          .from('resources')
          .select('*')
          .eq('type', 'MACHINE')
          .order('name');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchMachines: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchHumanResources() async {
    try {
      final res = await _db
          .from('resources')
          .select('*')
          .eq('type', 'HUMAN')
          .order('name');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchHumanResources: $e');
      return [];
    }
  }

  /// Update a machine (or any resource) directly in Supabase.
  Future<void> updateMachine({
    required String id,
    required String name,
    required String type,
    required String status,
  }) async {
    await _db.from('resources').update({
      'name': name,
      'type': type,
      'status': status,
    }).eq('id', id);
    invalidateCache();
  }

  /// Delete a machine (resource) directly from Supabase.
  Future<void> deleteMachine(String id) async {
    await _db.from('resources').delete().eq('id', id);
    invalidateCache();
  }

  /// Update a human resource (team member) name/role in Supabase.
  Future<void> updateTeamMember({
    required String id,
    required String name,
    required String status,
  }) async {
    await _db.from('resources').update({
      'name': name,
      'status': status,
    }).eq('id', id);
    invalidateCache();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // JOBS
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchJobs() async {
    try {
      final res = await _db
          .from('jobs')
          .select('id, title, client_name, total_quantity, status, deadline, created_at')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchJobs: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchJobsWithTasks() async {
    try {
      final res = await _db
          .from('jobs')
          .select('''
            id, title, client_name, total_quantity, status, deadline, created_at,
            tasks (
              id, name, status, quantity_to_process, show_in_mobile,
              scheduled_start_time, scheduled_end_time,
              operation_type_id,
              operation_types ( name ),
              resources ( name )
            )
          ''')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchJobsWithTasks: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TASKS
  // ──────────────────────────────────────────────────────────────────────────

  /// All tasks joined with job title, resource name, and operation type.
  Future<List<Map<String, dynamic>>> fetchAllTasks() async {
    try {
      final res = await _db
          .from('tasks')
          .select('''
            id, name, status, quantity_to_process, show_in_mobile,
            scheduled_start_time, scheduled_end_time,
            operation_type_id,
            jobs ( id, title, client_name, deadline ),
            resources ( id, name ),
            operation_types ( id, name )
          ''');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchAllTasks: $e');
      return [];
    }
  }

  /// Toggle task mobile visibility
  Future<void> toggleTaskMobileVisibility(String taskId, bool isVisible) async {
    try {
      await _db.from('tasks').update({
        'show_in_mobile': isVisible,
      }).eq('id', taskId);
      invalidateCache();
    } catch (e) {
      print('[SupabaseService] toggleTaskMobileVisibility: $e');
      rethrow;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OPERATION TYPES
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchOperationTypes() async {
    try {
      final res = await _db.from('operation_types').select('*').order('name');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchOperationTypes: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // CAPABILITIES (Skills Matrix)
  // ──────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchCapabilities() async {
    try {
      final res = await _db
          .from('resource_capabilities')
          .select('''
            id,
            processing_rate_per_hr,
            setup_time_minutes,
            cost_per_hour,
            resources ( id, name, type, status ),
            operation_types ( id, name )
          ''');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      print('[SupabaseService] fetchCapabilities: $e');
      return [];
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DASHBOARD STATS — parallel queries + 60-second cache
  // ──────────────────────────────────────────────────────────────────────────

  /// Fetches and computes all dashboard metrics.
  ///
  /// Uses a 60-second cache so the three widgets that call this
  /// (DashboardScreen, LiveAlerts, RecentActivity) share one response instead
  /// of firing 9 separate Supabase requests on startup.
  Future<Map<String, dynamic>> fetchDashboardStats() async {
    // Return cache if fresh
    if (_statsCache != null &&
        _statsCacheTime != null &&
        DateTime.now().difference(_statsCacheTime!).inSeconds < 60) {
      return _statsCache!;
    }

    try {
      // Fire all three queries in PARALLEL — not sequentially
      final results = await Future.wait([
        fetchMachines(),
        fetchJobs(),
        fetchAllTasks(),
      ]);

      final machines = results[0];
      final jobs     = results[1];
      final tasks    = results[2];

      final activeM  = machines.where((m) => m['status'] == 'ACTIVE').toList();
      final idleM    = machines.where((m) => m['status'] == 'IDLE').toList();
      final offlineM = machines.where((m) => m['status'] == 'OFFLINE').toList();

      final pendingTasks    = tasks.where((t) => t['status'] == 'PENDING').toList();
      final inProgressTasks = tasks.where((t) => t['status'] == 'IN_PROGRESS').toList();
      final completedTasks  = tasks.where((t) => t['status'] == 'COMPLETED').toList();

      // Group tasks by operation type name (for chart)
      final Map<String, int> tasksByOpType = {};
      for (final t in tasks) {
        final opName = (t['operation_types'] as Map?)?['name'] as String? ?? 'Other';
        tasksByOpType[opName] = (tasksByOpType[opName] ?? 0) + 1;
      }

      // Overdue jobs
      final now = DateTime.now();
      final overdueJobs = jobs.where((j) {
        if (j['status'] == 'COMPLETED') return false;
        final dl = j['deadline'];
        if (dl == null) return false;
        try {
          return DateTime.parse(dl.toString()).isBefore(now);
        } catch (_) {
          return false;
        }
      }).toList();

      final stats = {
        'active_machines':   activeM.length,
        'idle_machines':     idleM.length,
        'offline_machines':  offlineM,
        'total_machines':    machines.length,
        'total_jobs':        jobs.length,
        'total_tasks':       tasks.length,
        'pending_tasks':     pendingTasks.length,
        'in_progress_tasks': inProgressTasks.length,
        'completed_tasks':   completedTasks.length,
        'tasks_by_op_type':  tasksByOpType,
        'recent_tasks':      tasks.take(5).toList(),
        'new_jobs':          jobs.take(5).toList(),
        'overdue_jobs':      overdueJobs,
        'uptime_pct': machines.isEmpty
            ? 0.0
            : (activeM.length / machines.length * 100.0),
      };

      // Store in cache
      _statsCache = stats;
      _statsCacheTime = DateTime.now();
      return stats;
    } catch (e) {
      print('[SupabaseService] fetchDashboardStats: $e');
      return {};
    }
  }
}
