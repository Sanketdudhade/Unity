import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unity/core/utils/csv_exporter.dart';
import 'package:unity/features/process_queries/data/models/process_query_model.dart';
import 'package:unity/features/reports/presentation/providers/report_provider.dart';

void main() {
  group('Phase 5: ProcessQuery Model Tests', () {
    test('ProcessQuery parses valid Firestore document map accurately', () {
      final now = DateTime(2026, 10, 15, 12, 0);
      final rawData = {
        'ticketNumber': 'TK-2026-101',
        'title': 'Laser Cutting Calibration Error',
        'description': 'Axis Y deviation exceeding ±0.05mm tolerance limit on stainless sheet 2mm',
        'workOrder': 'WO-2026-101',
        'stage': 'Laser Cutting',
        'severity': 'high',
        'status': 'in_review',
        'reportedByName': 'Suresh Patel',
        'reportedByUid': 'emp_007',
        'resolutionNotes': 'Investigation in progress with maintenance team',
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      };

      final query = ProcessQuery.fromMap('query_101', rawData);

      expect(query.id, equals('query_101'));
      expect(query.ticketNumber, equals('TK-2026-101'));
      expect(query.title, equals('Laser Cutting Calibration Error'));
      expect(query.workOrder, equals('WO-2026-101'));
      expect(query.stage, equals('Laser Cutting'));
      expect(query.severity, equals('high'));
      expect(query.status, equals('in_review'));
      expect(query.reportedByName, equals('Suresh Patel'));
      expect(query.reportedByUid, equals('emp_007'));
      expect(query.resolutionNotes, contains('Investigation in progress'));
      expect(query.createdAt, equals(now));

      expect(query.isInReview, isTrue);
      expect(query.isOpen, isFalse);
      expect(query.isResolved, isFalse);
    });

    test('ProcessQuery status helper getters evaluate correctly', () {
      const openQuery = ProcessQuery(
        id: 'q1',
        ticketNumber: 'TK-1',
        title: 'Low Nitrogen Pressure',
        description: 'Gas bank pressure below 18 bar',
        severity: 'critical',
        status: 'open',
        reportedByName: 'Operator A',
      );
      expect(openQuery.isOpen, isTrue);
      expect(openQuery.isInReview, isFalse);
      expect(openQuery.isResolved, isFalse);

      const resolvedQuery = ProcessQuery(
        id: 'q2',
        ticketNumber: 'TK-2',
        title: 'Drawing Dimension Clarification',
        description: 'Drawing rev B chamfer note ambiguous',
        severity: 'low',
        status: 'resolved',
        reportedByName: 'Operator B',
        resolutionNotes: 'Engineering confirmed 45° x 1mm chamfer',
      );
      expect(resolvedQuery.isResolved, isTrue);
      expect(resolvedQuery.isOpen, isFalse);
      expect(resolvedQuery.isInReview, isFalse);
    });

    test('ProcessQuery serializes cleanly toMap for Firestore', () {
      const query = ProcessQuery(
        id: 'q3',
        ticketNumber: 'TK-3',
        title: 'Coolant Pump Leak',
        description: 'Minor hydraulic oil seepage on CNC lathe 2',
        workOrder: 'WO-2026-102',
        stage: 'CNC Machining',
        severity: 'medium',
        status: 'open',
        reportedByName: 'Ramesh Sharma',
        reportedByUid: 'emp_008',
      );

      final map = query.toMap();

      expect(map['ticketNumber'], equals('TK-3'));
      expect(map['title'], equals('Coolant Pump Leak'));
      expect(map['workOrder'], equals('WO-2026-102'));
      expect(map['stage'], equals('CNC Machining'));
      expect(map['severity'], equals('medium'));
      expect(map['status'], equals('open'));
      expect(map['reportedByName'], equals('Ramesh Sharma'));
      expect(map['reportedByUid'], equals('emp_008'));
    });
  });

  group('Phase 5: Executive KPI Dashboard Metrics Aggregator', () {
    test('ExecutiveKpiSummary correctly reflects aggregated operational metrics', () {
      const summary = ExecutiveKpiSummary(
        totalEmployees: 25,
        activeEmployees: 24,
        totalInventoryItems: 140,
        lowStockAlerts: 3,
        activeOrders: 12,
        completedOrders: 38,
        openQueries: 2,
      );

      expect(summary.totalEmployees, equals(25));
      expect(summary.activeEmployees, equals(24));
      expect(summary.totalInventoryItems, equals(140));
      expect(summary.lowStockAlerts, equals(3));
      expect(summary.activeOrders, equals(12));
      expect(summary.completedOrders, equals(38));
      expect(summary.openQueries, equals(2));
    });
  });

  group('Phase 5: RFC 4180 CSV Exporter Tests', () {
    test('CsvExporter correctly handles standard headers and rows without special characters', () {
      final headers = ['Order Number', 'Product', 'Target Qty', 'Status'];
      final rows = [
        ['WO-2026-101', 'Enclosure Alpha', 100, 'IN_PRODUCTION'],
        ['WO-2026-102', 'Flanged Valve', 50, 'COMPLETED'],
      ];

      final csv = CsvExporter.generateCsv(headers: headers, rows: rows);

      final lines = csv.trim().split('\n').map((l) => l.trim()).toList();
      expect(lines.length, equals(3));
      expect(lines[0], equals('Order Number,Product,Target Qty,Status'));
      expect(lines[1], equals('WO-2026-101,Enclosure Alpha,100,IN_PRODUCTION'));
      expect(lines[2], equals('WO-2026-102,Flanged Valve,50,COMPLETED'));
    });

    test('CsvExporter strictly escapes cells containing commas, quotes, and newlines according to RFC 4180', () {
      expect(CsvExporter.escapeCell('Normal Text'), equals('Normal Text'));
      expect(CsvExporter.escapeCell('Stainless Steel, 316L'), equals('"Stainless Steel, 316L"'));
      expect(CsvExporter.escapeCell('2" Pipe Flange'), equals('"2"" Pipe Flange"'));
      expect(CsvExporter.escapeCell('Line 1\nLine 2'), equals('"Line 1\nLine 2"'));
      expect(CsvExporter.escapeCell(null), equals(''));
    });

    test('CsvExporter produces fully valid multiline document with quotes and commas', () {
      final headers = ['SKU', 'Description', 'Notes'];
      final rows = [
        ['MAT-01', 'Sheet 2mm, 316L', 'Inspected by QC, "Grade A" approved'],
        ['MAT-02', 'Round Bar 50mm', 'Notes with\nnewline'],
      ];

      final csv = CsvExporter.generateCsv(headers: headers, rows: rows);

      expect(csv, contains('"Sheet 2mm, 316L"'));
      expect(csv, contains('"Inspected by QC, ""Grade A"" approved"'));
      expect(csv, contains('"Notes with\nnewline"'));
    });
  });
}

