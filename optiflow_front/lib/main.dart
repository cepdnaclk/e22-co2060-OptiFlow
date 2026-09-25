import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Desktop entry (unchanged) ───────────────────────────────────────────────
import 'package:optiflow_scheduler/slices/engine/dashboard/dashboard_screen.dart';

// ── New Mobile entry (complete rebuild) ─────────────────────────────────────
import 'mobile/core/app_theme.dart';
import 'mobile/core/auth_service.dart';
import 'mobile/screens/login_screen.dart';
import 'mobile/screens/main_hub.dart';

// ─────────────────────────────────────────────────────────────────────────────
// App entry point — initialises Supabase before runApp.
// ─────────────────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase (used for Auth ONLY — not for CRUD).
  await Supabase.initialize(
    url: 'https://rtqgwssnrqjjmgpnttgq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0cWd3c3NucnFqam1ncG50dGdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk2MTg2MDMsImV4cCI6MjA4NTE5NDYwM30.9xXUA7MxrLgPMi2P9GmcyAnbU242xRgvbmenNLg8iE4',
  );

  runApp(const ProviderScope(child: MyApp()));
}

// ─────────────────────────────────────────────────────────────────────────────
// Desktop entry widget (unchanged — routes to the existing engine dashboard)
// ─────────────────────────────────────────────────────────────────────────────
class DesktopEntry extends StatelessWidget {
  const DesktopEntry({super.key});
  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile entry widget — checks Supabase session and routes accordingly.
// ─────────────────────────────────────────────────────────────────────────────
class MobileEntry extends StatelessWidget {
  const MobileEntry({super.key});

  @override
  Widget build(BuildContext context) {
    // If there's already a valid session, skip login and go straight to hub.
    return AuthService.instance.isAuthenticated
        ? const MainHub()
        : const LoginScreen();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root App — LayoutBuilder gatekeeper.
// < 600px width → mobile (phone/tablet in portrait)
// ≥ 600px width → desktop (web, large tablet, Windows)
// ─────────────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Command Center / Precision SaaS dark theme — applied to the desktop shell.
    final desktopTheme = ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF141518),
      colorScheme: const ColorScheme.dark(
        primary:   Color(0xFF5E6AD2),
        secondary: Color(0xFF8B75D7),
        surface:   Color(0xFF1A1B1E),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(const Color(0xFF2C2C2E)),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OptiFlow',
      theme:      AppTheme.theme,
      darkTheme:  desktopTheme,
      themeMode:  ThemeMode.dark,
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
