import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:optiflow_scheduler/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    // 1. Safely mock required Supabase dependencies to prevent StateError
    // SharedPreferences is required by Supabase for local session storage.
    SharedPreferences.setMockInitialValues({});

    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
    } catch (e) {
      // Ignore if already initialized in another test
    }
  });

  testWidgets('OptiFlow smoke test - Renders Mobile Login Screen', (WidgetTester tester) async {
    // We set a mobile screen size to force LayoutBuilder to render MobileEntry
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    // 2. Render the OptiFlow application
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Pump frames to allow UI to settle
    await tester.pumpAndSettle();

    // 3. Verify an OptiFlow-specific widget or label
    // The MobileEntry should route to LoginScreen because the mock session is empty.
    expect(find.byType(TextField), findsWidgets); // Email and Password fields

    // Reset view properties
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
