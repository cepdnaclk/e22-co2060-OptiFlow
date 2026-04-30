import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:optiflow_scheduler/slices/engine/dashboard/dashboard_screen.dart';
import 'package:optiflow_scheduler/slices/worker/mobile_login_screen.dart';

class DesktopEntry extends StatelessWidget {
  const DesktopEntry({super.key});
  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

class MobileEntry extends StatelessWidget {
  const MobileEntry({super.key});
  @override
  Widget build(BuildContext context) => const MobileLoginScreen();
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OptiFlow',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return const DesktopEntry();
          } else {
            return const MobileEntry();
          }
        },
      ),
    );
  }
}
