import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'providers.dart';
import 'mobile_jobs_screen.dart'; // The UI with the dynamic calendar
import 'mobile_calendar_screen.dart';
import 'mobile_not_implemented_screen.dart';

class MobileDashboardScreen extends ConsumerWidget {
  const MobileDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(bottomNavIndexProvider);

    // Navigation logic: maps indices to specific screen files
    final List<Widget> screens = [
      const MobileNotImplementedScreen(title: 'Settings'),
      const MobileJobsScreen(), // This is where the core UI lives
      const MobileCalendarScreen(),
      const MobileNotImplementedScreen(title: 'Vacancy'),
      const MobileNotImplementedScreen(title: 'Comments'),
    ];

    return Scaffold(
      backgroundColor: MobileTheme.bgColor,
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: MobileTheme.surfaceColor,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.0),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            ref.read(bottomNavIndexProvider.notifier).state = index;
          },
          backgroundColor: MobileTheme.surfaceColor,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: MobileTheme.neonBlue,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
            BottomNavigationBarItem(icon: Icon(Icons.chair_alt), label: 'Vacancy'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Comments'),
          ],
        ),
      ),
    );
  }
}
