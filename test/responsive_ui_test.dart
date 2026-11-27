import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unity/app/theme/app_theme.dart';
import 'package:unity/core/firebase/firebase_providers.dart';
import 'package:unity/core/responsive/responsive.dart';
import 'package:unity/features/auth/data/repositories/auth_repository.dart';
import 'package:unity/features/auth/presentation/screens/login_screen.dart';
import 'package:unity/features/auth/presentation/screens/splash_screen.dart';
import 'package:unity/features/employee_dashboard/presentation/shell/employee_top_bar.dart';
import 'package:unity/features/processes/presentation/widgets/unity_process_flow_chart_widget.dart';
import 'package:unity/features/production/data/models/order_process_model.dart';
import 'package:unity/features/production/data/models/production_order_model.dart';
import 'package:unity/features/production/presentation/widgets/process_stage_actions_dialog.dart';
import 'package:unity/features/reports/presentation/widgets/csv_export_modal.dart';
import 'package:unity/features/tasks/data/models/process_task_model.dart';
import 'package:unity/features/tasks/presentation/widgets/process_task_card.dart';

class MockAuthRepo extends Mock implements AuthRepository {}

void main() {
  group('Centralized Responsive Breakpoints & Utilities Unit Tests', () {
    test('DeviceScreenType classification across all breakpoint ranges', () {
      expect(ResponsiveBreakpoints.fromWidth(300), equals(DeviceScreenType.smallMobile));
      expect(ResponsiveBreakpoints.fromWidth(359.9), equals(DeviceScreenType.smallMobile));

      expect(ResponsiveBreakpoints.fromWidth(360), equals(DeviceScreenType.standardMobile));
      expect(ResponsiveBreakpoints.fromWidth(599.9), equals(DeviceScreenType.standardMobile));

      expect(ResponsiveBreakpoints.fromWidth(600), equals(DeviceScreenType.tablet));
      expect(ResponsiveBreakpoints.fromWidth(899.9), equals(DeviceScreenType.tablet));

      expect(ResponsiveBreakpoints.fromWidth(900), equals(DeviceScreenType.smallDesktop));
      expect(ResponsiveBreakpoints.fromWidth(1199.9), equals(DeviceScreenType.smallDesktop));

      expect(ResponsiveBreakpoints.fromWidth(1200), equals(DeviceScreenType.desktop));
      expect(ResponsiveBreakpoints.fromWidth(1599.9), equals(DeviceScreenType.desktop));

      expect(ResponsiveBreakpoints.fromWidth(1600), equals(DeviceScreenType.largeDesktop));
      expect(ResponsiveBreakpoints.fromWidth(2560), equals(DeviceScreenType.largeDesktop));
    });

    test('Helper booleans on ResponsiveBreakpoints', () {
      expect(ResponsiveBreakpoints.isSmallMobileWidth(320), isTrue);
      expect(ResponsiveBreakpoints.isSmallMobileWidth(400), isFalse);

      expect(ResponsiveBreakpoints.isMobileWidth(320), isTrue);
      expect(ResponsiveBreakpoints.isMobileWidth(500), isTrue);
      expect(ResponsiveBreakpoints.isMobileWidth(600), isFalse);

      expect(ResponsiveBreakpoints.isTabletWidth(700), isTrue);
      expect(ResponsiveBreakpoints.isTabletWidth(900), isFalse);

      expect(ResponsiveBreakpoints.isSmallDesktopWidth(1000), isTrue);
      expect(ResponsiveBreakpoints.isDesktopWidth(1300), isTrue);
      expect(ResponsiveBreakpoints.isLargeDesktopWidth(1920), isTrue);
    });

    test('ResponsiveBreakpoints.valueFromWidth resolves correctly', () {
      String resolve(double width) => ResponsiveBreakpoints.valueFromWidth<String>(
            width: width,
            mobile: 'mobile',
            tablet: 'tablet',
            desktop: 'desktop',
          );

      expect(resolve(320), equals('mobile'));
      expect(resolve(480), equals('mobile'));
      expect(resolve(720), equals('tablet'));
      expect(resolve(1024), equals('desktop'));
      expect(resolve(1440), equals('desktop'));
    });

    test('ResponsiveHelper gridColumnsFromWidth and dialog constraints', () {
      expect(ResponsiveHelper.gridColumnsFromWidth(320), equals(1));
      expect(ResponsiveHelper.gridColumnsFromWidth(480), equals(1));
      expect(ResponsiveHelper.gridColumnsFromWidth(720), equals(2));
      expect(ResponsiveHelper.gridColumnsFromWidth(1000), equals(3));
      expect(ResponsiveHelper.gridColumnsFromWidth(1400), equals(4));

      expect(ResponsiveHelper.dialogMaxWidthFromWidth(320, desktopMax: 600), equals(320 - 24));
      expect(ResponsiveHelper.dialogMaxWidthFromWidth(1000, desktopMax: 600), equals(600));
    });
  });

  const deviceConfigurations = <String, Size>{
    'Small Mobile (320x568)': Size(320, 568),
    'Standard Mobile (360x800)': Size(360, 800),
    'Pixel Mobile (412x915)': Size(412, 915),
    'Android Tablet (600x960)': Size(600, 960),
    'iPad / Large Tablet (768x1024)': Size(768, 1024),
    'Small Desktop (1024x768)': Size(1024, 768),
    'Standard Desktop (1440x900)': Size(1440, 900),
    'Large Desktop 1080p (1920x1080)': Size(1920, 1080),
    'Mobile Landscape (800x360)': Size(800, 360),
  };

  group('Universal Device Responsiveness & Layout Tests Across All Breakpoints', () {
    for (final entry in deviceConfigurations.entries) {
      final deviceName = entry.key;
      final size = entry.value;

      testWidgets('SplashScreen layout on $deviceName (normal & scaled fonts)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockAuthRepo();
        final controller = StreamController<dynamic>.broadcast();
        when(() => mockRepo.authStateChanges).thenAnswer((_) => controller.stream.cast());
        addTearDown(controller.close);

        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWithValue(mockRepo),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: const SplashScreen(),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('UNITY'), findsOneWidget);
        }
      });

      testWidgets('LoginScreen layout on $deviceName (normal & scaled fonts)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockAuthRepo();
        final controller = StreamController<dynamic>.broadcast();
        when(() => mockRepo.authStateChanges).thenAnswer((_) => controller.stream.cast());
        addTearDown(controller.close);

        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWithValue(mockRepo),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: const LoginScreen(),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Unity Technologies'), findsOneWidget);
          expect(find.text('Sign In'), findsOneWidget);
        }
      });

      testWidgets('UnityProcessFlowChartWidget layout on $deviceName (normal & scaled fonts)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: const Scaffold(
                  body: SingleChildScrollView(
                    child: UnityProcessFlowChartWidget(
                      showHeader: true,
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('UNITY ENGINEERS'), findsOneWidget);
          expect(find.text('PROCESS FLOW CHART PLAN:-'), findsOneWidget);
        }
      });

      testWidgets('ProcessTaskCard layout on $deviceName (normal & scaled fonts)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final task = ProcessTask(
          id: 'task-101',
          workOrder: 'WO-2026-9081',
          title: 'Precision CNC Turning & Facing of Hex Spindles',
          stage: 'Sub-Assembly Inspection & Quality Clearance Stage',
          assignedToName: 'Rajesh Kumar Chandrasekharan',
          assignedToUid: 'user-101',
          priority: 'urgent',
          status: 'in_progress',
          notes: 'Ensure concentricity tolerance within ±0.005mm per technical drawing',
        );

        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            ProviderScope(
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: Scaffold(
                    body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ProcessTaskCard(task: task),
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('WO-2026-9081'), findsOneWidget);
          expect(find.text('URGENT'), findsOneWidget);
        }
      });

      testWidgets('EmployeeTopBar layout on $deviceName (normal & scaled fonts)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockAuthRepo();
        final controller = StreamController<dynamic>.broadcast();
        when(() => mockRepo.authStateChanges).thenAnswer((_) => controller.stream.cast());
        addTearDown(controller.close);

        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWithValue(mockRepo),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  theme: AppTheme.lightTheme,
                  home: const Scaffold(
                    appBar: EmployeeTopBar(showDrawerButton: true),
                    body: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.byType(EmployeeTopBar), findsOneWidget);
        }
      });

      testWidgets('CsvExportModal layout on $deviceName (normal & scaled fonts)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: const MaterialApp(
                home: Scaffold(
                  body: CsvExportModal(
                    title: 'Workforce Directory Audit Report 2026',
                    filename: 'employee_directory_enterprise_audit_export_20261103.csv',
                    csvContent: 'id,name,role,status\n1,Rajesh Kumar,Operator,Active\n2,Priya Sharma,Admin,Active',
                    recordCount: 2,
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Workforce Directory Audit Report 2026'), findsOneWidget);
        }
      });

      testWidgets('ProcessStageActionsDialog layout on $deviceName (normal & scaled fonts)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockRepo = MockAuthRepo();
        final controller = StreamController<dynamic>.broadcast();
        when(() => mockRepo.authStateChanges).thenAnswer((_) => controller.stream.cast());
        addTearDown(controller.close);

        for (final scale in [1.0, 1.3]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                authRepositoryProvider.overrideWithValue(mockRepo),
              ],
              child: MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: const MaterialApp(
                  home: Scaffold(
                    body: ProcessStageActionsDialog(
                      order: ProductionOrder(
                        id: 'order_test_1',
                        orderNumber: 'WO-336939',
                        productName: 'Stainless Steel Mounting Bracket',
                        targetQuantity: 100,
                        completedQuantity: 0,
                        unit: 'PCS',
                        status: 'in_production',
                        priority: 'normal',
                      ),
                      process: OrderProcessModel(
                        id: 'stage_test_3',
                        orderId: 'order_test_1',
                        templateStepId: 'step_3',
                        name: 'Quotation',
                        sequence: 3,
                        targetQty: 100,
                        completedQty: 0,
                        status: 'NOT_STARTED',
                        assignedEmployeeUid: '',
                        assignedEmployeeName: 'Unassigned',
                      ),
                      allStageStatuses: {
                        1: 'COMPLETED',
                        2: 'IN_PROGRESS',
                        3: 'NOT_STARTED',
                      },
                    ),
                  ),
                ),
              ),
            ),
          );

          expect(tester.takeException(), isNull);
          expect(find.text('Quotation'), findsOneWidget);
        }
      });
    }
  });
}
