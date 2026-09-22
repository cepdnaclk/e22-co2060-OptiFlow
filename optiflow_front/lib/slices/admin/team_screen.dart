import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';
import 'package:optiflow_scheduler/core/services/api_service.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeam();
  }

  /// Extracts role from name format "Name (Role)" — falls back to "Team Member"
  String _extractRole(String name) {
    final match = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (match != null) return match.group(1) ?? 'Team Member';
    return 'Team Member';
  }

  /// Returns display name without the role suffix "(Role)"
  String _displayName(String rawName) {
    return rawName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  }

  Future<void> _fetchTeam() async {
    final resources = await SupabaseService.instance.fetchHumanResources();

    final mapped = resources.map((r) {
      final rawName = r['name']?.toString() ?? 'Unknown';
      final displayName = _displayName(rawName);
      final nameParts = displayName.split(' ');
      final initials = nameParts.length > 1
          ? '${nameParts[0][0]}${nameParts[1][0]}'
          : (nameParts.isNotEmpty ? nameParts[0][0] : 'U');

      final emailParts = displayName.split(' ');
      final email = emailParts.length > 1
          ? '${emailParts[0].toLowerCase()}.${emailParts[1].toLowerCase()}@optiflow.com'
          : '${displayName.toLowerCase().replaceAll(' ', '')}@optiflow.com';

      final colors = [
        Colors.blue,
        Colors.purple,
        Colors.teal,
        Colors.orange,
        Colors.green,
      ];
      final color = colors[rawName.length % colors.length];

      return {
        "id": r['id'],
        "name": rawName,
        "role": _extractRole(rawName),
        "status": r['status'] == "ACTIVE"
            ? "Active"
            : r['status'] == "OFFLINE"
            ? "Offline"
            : "Idle",
        "email": email,
        "avatar": initials.toUpperCase(),
        "color": color,
      };
    }).toList();

    if (mounted) {
      setState(() {
        _teamMembers = mapped;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          if (_teamMembers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(64.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: AppColors.textSecondary.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "No team members yet.\nClick \"Add Member\" to get started.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildTeamGrid(),
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
              "Team Management",
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -1,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Manage your workforce, assign roles, and track status.",
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () => _showAddMemberDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  "Add Member",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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

  void _showAddMemberDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    String selectedRole = 'Operator';
    bool isSubmitting = false;
    final List<String> roles = [
      'Operator',
      'Supervisor',
      'Technician',
      'Machine Operator',
      'Quality Inspector',
      'Logistics',
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: AppColors.surfaceLight.withOpacity(0.5),
                ),
              ),
              title: const Text(
                "Add New Team Member",
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Full Name",
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: "e.g. Sarah Chen",
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
                    const Text(
                      "Role",
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
                          value: selectedRole,
                          dropdownColor: AppColors.surfaceLight,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                          ),
                          items: roles
                              .map(
                                (r) => DropdownMenuItem<String>(
                                  value: r,
                                  child: Text(r),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
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
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please enter a name"),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            setDialogState(() => isSubmitting = true);

                            // Store role embedded in name: "Name (Role)"
                            final storedName =
                                "${nameController.text.trim()} ($selectedRole)";
                            try {
                              final url = Uri.parse(
                                "${ApiService.baseUrl}/resources",
                              );
                              final response = await http.post(
                                url,
                                headers: {"Content-Type": "application/json"},
                                body: json.encode({
                                  "name": storedName,
                                  "type": "HUMAN",
                                  "status": "ACTIVE",
                                }),
                              );

                              if (response.statusCode == 200 ||
                                  response.statusCode == 201) {
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                _fetchTeam();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Team member added successfully!",
                                    ),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              } else {
                                final body = json.decode(response.body);
                                throw Exception(
                                  body['detail'] ??
                                      "Failed: ${response.statusCode}",
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: $e"),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              setDialogState(() => isSubmitting = false);
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
                            "Add Member",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTeamGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 3;
        if (constraints.maxWidth < 900) crossAxisCount = 2;
        if (constraints.maxWidth < 600) crossAxisCount = 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 2.5,
          ),
          itemCount: _teamMembers.length,
          itemBuilder: (context, index) {
            return _buildMemberCard(_teamMembers[index]);
          },
        );
      },
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    Color statusColor;
    switch (member["status"]) {
      case "Active":
        statusColor = AppColors.success;
        break;
      case "Idle":
        statusColor = AppColors.warning;
        break;
      case "Offline":
        statusColor = AppColors.textSecondary;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceLight.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: (member["color"] as Color).withOpacity(0.2),
            child: Text(
              member["avatar"],
              style: TextStyle(
                color: member["color"] as Color,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _displayName(member["name"]),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  member["role"],
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      member["status"],
                      style: TextStyle(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onPressed: () => _showEditMemberDialog(context, member),
          ),
        ],
      ),
    );
  }

  // ── Edit member dialog ───────────────────────────────────────────────────
  void _showEditMemberDialog(
    BuildContext context,
    Map<String, dynamic> member,
  ) {
    final nameCtrl = TextEditingController(text: _displayName(member['name']));
    final roles = [
      'Operator',
      'Supervisor',
      'Technician',
      'Machine Operator',
      'Quality Inspector',
      'Logistics',
    ];
    String selectedRole = member['role'] as String;
    String selectedStatus = member['status'] as String;
    if (!roles.contains(selectedRole)) selectedRole = 'Operator';
    bool isSubmitting = false;

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
                'Edit Team Member',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Full Name',
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
                    hintText: 'e.g. Sarah Chen',
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
                const Text(
                  'Role',
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
                      value: selectedRole,
                      dropdownColor: AppColors.surfaceLight,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                      items: roles
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDialogState(() => selectedRole = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                  children: ['Active', 'Idle', 'Offline'].map((s) {
                    final isSel = selectedStatus == s;
                    final c = s == 'Active'
                        ? AppColors.success
                        : s == 'Idle'
                        ? AppColors.warning
                        : AppColors.textSecondary;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedStatus = s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSel
                              ? c.withOpacity(0.2)
                              : AppColors.surfaceLight.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSel
                                ? c
                                : AppColors.surfaceLight.withOpacity(0.4),
                            width: isSel ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            color: isSel ? c : AppColors.textSecondary,
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
            // Delete button
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _showDeleteMemberConfirm(context, member);
              },
              child: const Text(
                'Remove',
                style: TextStyle(color: AppColors.error),
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
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        setDialogState(() => isSubmitting = true);
                        // Store role embedded: "Name (Role)"
                        final storedName = '$name ($selectedRole)';
                        // Map display status to DB status
                        final dbStatus = selectedStatus == 'Active'
                            ? 'ACTIVE'
                            : selectedStatus == 'Idle'
                            ? 'IDLE'
                            : 'OFFLINE';
                        try {
                          await SupabaseService.instance.updateTeamMember(
                            id: member['id'].toString(),
                            name: storedName,
                            status: dbStatus,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          _fetchTeam();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Team member updated!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
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

  void _showDeleteMemberConfirm(
    BuildContext context,
    Map<String, dynamic> member,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Remove Member?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Remove "${_displayName(member['name'] as String)}" from the team? This cannot be undone.',
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
                await SupabaseService.instance.deleteMachine(
                  member['id'].toString(),
                );
                _fetchTeam();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Member removed.'),
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
}
