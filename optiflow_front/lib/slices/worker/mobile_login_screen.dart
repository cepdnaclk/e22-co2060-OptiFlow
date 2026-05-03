import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mobile_dashboard_screen.dart';

class MobileLoginScreen extends StatefulWidget {
  const MobileLoginScreen({super.key});

  @override
  State<MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<MobileLoginScreen> {
  // Hardcoded resources for demo purposes
  final List<Map<String, String>> _resources = [
    {'id': '1e9d1f7e-1234-4a5b-8c6d-9e8f7a6b5c4d', 'name': 'Machine Operator A', 'role': 'Folding'},
    {'id': '2f8e2a6d-2345-5b6c-9d7e-0f1e2a3b4c5d', 'name': 'Printer B', 'role': 'Printing'},
    {'id': '3a7d3b5c-3456-6c7d-0e8f-1f2e3a4b5c6e', 'name': 'Cutter C', 'role': 'Cutting'},
  ];

  void _selectResource(String resourceId) {
    HapticFeedback.lightImpact();
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MobileDashboardScreen(resourceId: resourceId),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2B2B),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.layers_rounded, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Welcome to\nOptiFlow',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2B2B2B),
                  letterSpacing: -1,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select your station to view your shift.',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: ListView.separated(
                  itemCount: _resources.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final resource = _resources[index];
                    return _buildResourceCard(
                      name: resource['name']!,
                      role: resource['role']!,
                      onTap: () => _selectResource(resource['id']!),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceCard({required String name, required String role, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFF2B2B2B)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    role,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
