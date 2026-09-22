import 'package:flutter/material.dart';
import 'package:optiflow_scheduler/core/utils/app_colors.dart';
import 'package:optiflow_scheduler/core/services/api_service.dart';
import 'package:optiflow_scheduler/core/services/supabase_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _apiService = ApiService();
  int _selectedTabIndex = 0;
  bool _isLoading = true;
  String _userName = "Loading...";
  String _userEmail = "loading@optiflow.com";
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final List<String> _tabs = [
    "Profile",
    "Notifications",
    "Security",
    "Preferences",
    "Operations", // Skills Matrix — real Supabase data
  ];

  List<Map<String, dynamic>> _capabilities = [];
  bool _capsLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    // Capabilities are loaded lazily when the Operations tab is first opened.
  }

  Future<void> _fetchCapabilities() async {
    if (!_capsLoading) return; // Already loaded
    final caps = await SupabaseService.instance.fetchCapabilities();
    if (mounted)
      setState(() {
        _capabilities = caps;
        _capsLoading = false;
      });
  }

  Future<void> _fetchProfile() async {
    try {
      final resources = await _apiService.fetchHumanResources();
      if (resources.isNotEmpty) {
        final user = resources.first; // Mock logged-in user as the first human
        final name = user['name']?.toString() ?? "Admin User";
        final email = "${name.toLowerCase().replaceAll(' ', '.')}@optiflow.com";

        if (mounted) {
          setState(() {
            _userName = name;
            _userEmail = email;
            _nameController.text = _userName;
            _emailController.text = _userEmail;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = "Admin User";
            _userEmail = "admin@optiflow.com";
            _nameController.text = _userName;
            _emailController.text = _userEmail;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = "Admin User";
          _userEmail = "admin@optiflow.com";
          _nameController.text = _userName;
          _emailController.text = _userEmail;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.surfaceLight.withOpacity(0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar Tabs
                  Container(
                    width: 250,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: AppColors.surfaceLight.withOpacity(0.5),
                        ),
                      ),
                    ),
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: _tabs.length,
                      itemBuilder: (context, index) {
                        final isSelected = _selectedTabIndex == index;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedTabIndex = index;
                            });
                            // Lazy-load capabilities only when Operations tab is first opened
                            if (index == 4 && _capsLoading) {
                              _fetchCapabilities();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.primary.withOpacity(0.15),
                                        Colors.transparent,
                                      ],
                                      begin: Alignment.centerRight,
                                      end: Alignment.centerLeft,
                                    )
                                  : null,
                            ),
                            child: Text(
                              _tabs[index],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Content Area
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(20),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40.0),
                        child: _buildTabContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Settings & Preferences",
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Manage your account settings, notifications, and security.",
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildProfileTab();
      case 1:
        return _buildNotificationsTab();
      case 2:
        return _buildSecurityTab();
      case 3:
        return _buildPreferencesTab();
      case 4:
        return _buildOperationsTab();
      default:
        return _buildProfileTab();
    }
  }

  Widget _buildProfileTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Profile Information",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Update your photo and personal details here.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceLight,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: AppColors.textSecondary.withOpacity(0.2),
                  ),
                ),
              ),
              child: const Text(
                "Change Avatar",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text(
                "Remove",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        _buildTextField("Full Name", _userName, controller: _nameController),
        const SizedBox(height: 24),
        _buildTextField(
          "Email Address",
          _userEmail,
          controller: _emailController,
        ),
        const SizedBox(height: 24),
        _buildTextField("Role", "Administrator", enabled: false),
        const SizedBox(height: 48),
        Row(children: [const Spacer(), _buildSaveButton()]),
      ],
    );
  }

  Widget _buildNotificationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Notification Preferences",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Choose what we should notify you about.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),
        _buildSwitchTile(
          "Email Notifications",
          "Receive updates via email",
          true,
        ),
        _buildSwitchTile(
          "Push Notifications",
          "Receive alerts on desktop",
          true,
        ),
        _buildSwitchTile(
          "Weekly Reports",
          "Get a summary of weekly stats",
          false,
        ),
        _buildSwitchTile(
          "Machine Alerts",
          "Notify when a machine goes offline",
          true,
        ),
        const SizedBox(height: 48),
        Row(children: [const Spacer(), _buildSaveButton()]),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Security & Password",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Manage your password and security settings.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),
        _buildTextField("Current Password", "********", obscureText: true),
        const SizedBox(height: 24),
        _buildTextField("New Password", "", obscureText: true),
        const SizedBox(height: 24),
        _buildTextField("Confirm New Password", "", obscureText: true),
        const SizedBox(height: 48),
        Row(children: [const Spacer(), _buildSaveButton()]),
      ],
    );
  }

  Widget _buildPreferencesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "App Preferences",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Customize your experience.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 32),
        _buildDropdown("Language", ["English", "Spanish", "French"]),
        const SizedBox(height: 24),
        _buildDropdown("Timezone", ["UTC", "PST", "EST", "GMT"]),
        const SizedBox(height: 24),
        _buildDropdown("Theme", ["System Default", "Light", "Dark"]),
        const SizedBox(height: 48),
        Row(children: [const Spacer(), _buildSaveButton()]),
      ],
    );
  }

  Widget _buildOperationsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Skills Matrix",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "What each machine can do, its throughput, and operating costs.",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 24),
        if (_capsLoading)
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          )
        else if (_capabilities.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No capabilities found.',
                style: TextStyle(
                  color: AppColors.textSecondary.withOpacity(0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else ...[
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Machine',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Operation Type',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Rate / hr',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Setup (min)',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Cost / hr',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withOpacity(0.1),
              border: Border.all(
                color: AppColors.surfaceLight.withOpacity(0.4),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _capabilities.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.surfaceLight.withOpacity(0.4),
              ),
              itemBuilder: (_, i) {
                final cap = _capabilities[i];
                final machineName =
                    (cap['resources'] as Map?)?['name']?.toString() ?? '—';
                final opName =
                    (cap['operation_types'] as Map?)?['name']?.toString() ??
                    '—';
                final rate = cap['processing_rate_per_hr'];
                final setup = cap['setup_time_minutes'];
                final cost = cap['cost_per_hour'];

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.success,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                machineName,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            opName,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          rate != null
                              ? '${rate.toStringAsFixed(0)} units'
                              : '—',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          setup != null ? '$setup min' : '—',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          cost != null
                              ? '\$${cost.toStringAsFixed(2)}/hr'
                              : '—',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(
    String label,
    String hint, {
    bool obscureText = false,
    bool enabled = true,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          enabled: enabled,
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textSecondary,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            hintText: controller == null ? hint : null,
            hintStyle: TextStyle(
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            filled: true,
            fillColor: enabled
                ? AppColors.surfaceLight.withOpacity(0.3)
                : AppColors.surfaceLight.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.textSecondary.withOpacity(0.1),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool initialValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: initialValue,
            onChanged: (val) {},
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.3),
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.surfaceLight,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items[0],
              dropdownColor: AppColors.surfaceLight,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: (_) {},
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Settings saved successfully!"),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          "Save Changes",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
