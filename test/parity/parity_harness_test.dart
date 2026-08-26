import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:network_image_mock/network_image_mock.dart';

import 'package:flutter_swipes/src/features/auth/presentation/screens/access_code_gate_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/welcome_screen.dart';
import 'package:flutter_swipes/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:flutter_swipes/src/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:flutter_swipes/src/features/swipes/presentation/screens/client_swipe_container.dart';

import 'package:flutter_swipes/src/features/auth/data/auth_repository.dart';
import 'package:flutter_swipes/src/features/auth/presentation/providers/auth_provider.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
  });

  Widget buildTestedWidget(Widget child) {
    return ProviderScope(
      overrides: [
        // Deterministic mocks will go here in later prompts
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Plus Jakarta Sans',
        ),
        home: Material(
          color: Colors.black,
          child: TickerMode(
            enabled: false,
            child: child,
          ),
        ),
      ),
    );
  }

  group('Visual Parity Goldens', () {
    final devices = [
      Device.phone.copyWith(name: 'mobile', size: const Size(390, 844)),
      const Device(name: 'desktop', size: const Size(1440, 900)),
    ];

    testGoldens('access_code_gate_parity', (tester) async {
      await mockNetworkImagesFor(() async {
        final builder = DeviceBuilder()
          ..overrideDevicesForAllScenarios(devices: devices)
          ..addScenario(
            widget: buildTestedWidget(const AccessCodeGateScreen()),
            name: 'default',
          );
        
        await tester.pumpDeviceBuilder(builder);
        await screenMatchesGolden(tester, 'access_code_gate');
      });
    });

    testGoldens('welcome_parity', (tester) async {
      await mockNetworkImagesFor(() async {
        final builder = DeviceBuilder()
          ..overrideDevicesForAllScenarios(devices: devices)
          ..addScenario(
            widget: buildTestedWidget(const WelcomeScreen()),
            name: 'default',
          );
        
        await tester.pumpDeviceBuilder(builder);
        await screenMatchesGolden(tester, 'welcome');
      });
    });

    testGoldens('auth_parity', (tester) async {
      await mockNetworkImagesFor(() async {
        final builder = DeviceBuilder()
          ..overrideDevicesForAllScenarios(devices: devices)
          ..addScenario(
            widget: buildTestedWidget(const AuthScreen()),
            name: 'default',
          );
        
        await tester.pumpDeviceBuilder(builder);
        await screenMatchesGolden(tester, 'auth');
      });
    });

    testGoldens('dashboard_parity', (tester) async {
      await mockNetworkImagesFor(() async {
        final builder = DeviceBuilder()
          ..overrideDevicesForAllScenarios(devices: devices)
          ..addScenario(
            widget: buildTestedWidget(const DashboardShell(child: SizedBox())),
            name: 'default',
          );
        
        await tester.pumpDeviceBuilder(builder);
        await screenMatchesGolden(tester, 'dashboard');
      });
    });

    testGoldens('swipe_parity', (tester) async {
      await mockNetworkImagesFor(() async {
        final builder = DeviceBuilder()
          ..overrideDevicesForAllScenarios(devices: devices)
          ..addScenario(
            widget: buildTestedWidget(const ClientSwipeContainer(
              categoryId: 'properties',
              categoryTitle: 'Properties',
            )),
            name: 'default',
          );
        
        await tester.pumpDeviceBuilder(builder);
        await screenMatchesGolden(tester, 'swipe');
      });
    });
  });
}
