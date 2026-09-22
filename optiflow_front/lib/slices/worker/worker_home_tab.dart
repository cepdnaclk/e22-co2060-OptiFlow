import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api/mobile_api_service.dart';
import 'models/task_model.dart';
import 'widgets/task_card.dart';

class WorkerHomeTab extends StatefulWidget {
  final String resourceId;
  const WorkerHomeTab({super.key, required this.resourceId});

  @override
  State<WorkerHomeTab> createState() => _WorkerHomeTabState();
}

class _WorkerHomeTabState extends State<WorkerHomeTab> {
  final MobileApiService _apiService = MobileApiService();
  List<WorkerTask> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tasks = await _apiService.fetchTasks(widget.resourceId);
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildShimmer() {
    return const Center(child: CircularProgressIndicator(color: Colors.black));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no tasks assigned right now.\nTake a break!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _fetchTasks,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F9),
        body: _buildShimmer(),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Connection Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _fetchTasks,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B2B2B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Retry Connection'),
              ),
            ],
          ),
        ),
      );
    }

    final inProgressTasks = _tasks
        .where((t) => t.status == 'IN_PROGRESS')
        .toList();
    final scheduledTasks = _tasks
        .where((t) => t.status == 'SCHEDULED')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9), // Soft off-white background
      body: RefreshIndicator(
        onRefresh: _fetchTasks,
        color: Colors.black,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 120.0,
              floating: true,
              pinned: true,
              elevation: 0,
              backgroundColor: const Color(0xFFF7F7F9),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
                title: const Text(
                  'Your Shift',
                  style: TextStyle(
                    color: Color(0xFF2B2B2B),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24, top: 40),
                  child: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    radius: 20,
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (_tasks.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else ...[
              if (inProgressTasks.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(left: 24, top: 16, bottom: 16),
                    child: Text(
                      'ACTIVE NOW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      scrollDirection: Axis.horizontal,
                      itemCount: inProgressTasks.length,
                      itemBuilder: (context, index) {
                        return TaskCard(
                          task: inProgressTasks[index],
                          onTaskUpdated: _fetchTasks,
                        );
                      },
                    ),
                  ),
                ),
              ],
              if (scheduledTasks.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(left: 24, top: 32, bottom: 16),
                    child: Text(
                      'UP NEXT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return TaskCard(
                        task: scheduledTasks[index],
                        onTaskUpdated: _fetchTasks,
                      );
                    }, childCount: scheduledTasks.length),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ],
        ),
      ),
    );
  }
}
