import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:optiflow_scheduler/core/models/machine.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';
import 'package:optiflow_scheduler/core/services/api_service.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';
import 'package:optiflow_scheduler/slices/engine/dashboard/widgets/machine_card.dart';
import 'package:optiflow_scheduler/slices/admin/add_machine_screen.dart';

class MachinesScreen extends StatefulWidget {
  const MachinesScreen({super.key});

  @override
  State<MachinesScreen> createState() => _MachinesScreenState();
}

class _MachinesScreenState extends State<MachinesScreen> {
  List<Machine> _machines = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    setState(() => _isLoading = true);
    final raw = await SupabaseService.instance.fetchMachines();
    final machines = raw.map((json) => Machine.fromJson(json)).toList();
    if (mounted)
      setState(() {
        _machines = machines;
        _isLoading = false;
      });
  }

  List<Machine> get _filtered {
    if (_searchQuery.isEmpty) return _machines;
    final q = _searchQuery.toLowerCase();
    return _machines
        .where(
          (m) =>
              m.name.toLowerCase().contains(q) ||
              m.status.toLowerCase().contains(q) ||
              m.type.toLowerCase().contains(q),
        )
        .toList();
  }

  // ── Edit Machine dialog ──────────────────────────────────────────────────

  void _showEditDialog(BuildContext context, Machine machine) {
    final nameCtrl = TextEditingController(text: machine.name);
    String selectedStatus = machine.status;
    String selectedType = machine.type;
    bool isSubmitting = false;

    const statuses = ['ACTIVE', 'IDLE', 'MAINTENANCE', 'OFFLINE'];
    const machineTypes = [
      'Offset Press',
      'Digital Press',
      'Large Format',
      'Bindery',
      'Cutting',
      'Finishing',
      'Other',
    ];

    // Ensure current values are in the lists
    if (!statuses.contains(selectedStatus)) selectedStatus = 'ACTIVE';
    if (!machineTypes.contains(selectedType)) selectedType = 'Other';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.surfaceLight.withOpacity(0.5)),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Edit Machine',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                const Text(
                  'Machine Name',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Heidelberg Speedmaster',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLight.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Type
                const Text(
                  'Machine Type',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedType,
                      dropdownColor: AppColors.surfaceLight,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                      items: machineTypes
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedType = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Status
                const Text(
                  'Status',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: statuses.map((s) {
                    final isSelected = selectedStatus == s;
                    Color c;
                    switch (s) {
                      case 'ACTIVE':
                        c = AppColors.success;
                        break;
                      case 'IDLE':
                        c = AppColors.warning;
                        break;
                      case 'MAINTENANCE':
                        c = AppColors.info;
                        break;
                      default:
                        c = AppColors.error;
                    }
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedStatus = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? c.withOpacity(0.2)
                              : AppColors.surfaceLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? c
                                : AppColors.surfaceLight.withOpacity(0.4),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            color: isSelected ? c : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (nameCtrl.text.trim().isEmpty) return;
                        setDialogState(() => isSubmitting = true);
                        try {
                          final url = Uri.parse(
                            '${ApiService.baseUrl}/resources/${machine.id}',
                          );
                          final resp = await http.patch(
                            url,
                            headers: {'Content-Type': 'application/json'},
                            body: json.encode({
                              'name': nameCtrl.text.trim(),
                              'type': 'MACHINE',
                              'status': selectedStatus,
                            }),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (resp.statusCode == 200 ||
                              resp.statusCode == 201 ||
                              resp.statusCode == 204) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Machine updated!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          } else {
                            // Fallback: update directly via Supabase if FastAPI not running
                            await SupabaseService.instance.updateMachine(
                              id: machine.id,
                              name: nameCtrl.text.trim(),
                              type: 'MACHINE',
                              status: selectedStatus,
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Machine updated via Supabase!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                          _fetchMachines();
                        } catch (e) {
                          // Try Supabase direct update
                          try {
                            await SupabaseService.instance.updateMachine(
                              id: machine.id,
                              name: nameCtrl.text.trim(),
                              type: 'MACHINE',
                              status: selectedStatus,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Machine updated!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                            _fetchMachines();
                          } catch (e2) {
                            setDialogState(() => isSubmitting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e2'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete confirmation ──────────────────────────────────────────────────

  void _showDeleteConfirm(BuildContext context, Machine machine) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Machine?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${machine.name}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await SupabaseService.instance.deleteMachine(machine.id);
                _fetchMachines();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Machine removed.'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final filtered = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildSearchBar(),
          const SizedBox(height: 32),
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  children: [
                    Icon(
                      Icons.precision_manufacturing_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No machines added yet.'
                          : 'No machines match "$_searchQuery".',
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.6),
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 1100
                    ? 3
                    : (constraints.maxWidth > 700 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return MachineCard(
                      machine: filtered[index],
                      onEdit: () => _showEditDialog(context, filtered[index]),
                      onDelete: () =>
                          _showDeleteConfirm(context, filtered[index]),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Machines',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Manage and monitor all print shop equipment',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
        GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMachineScreen()),
            );
            if (result == true) _fetchMachines();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(Icons.add, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Add Machine',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.surfaceLight.withOpacity(0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search machines...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                    ),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
