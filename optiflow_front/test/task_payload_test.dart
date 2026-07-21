// Task-level payload and scheduling logic unit tests.
// These tests do NOT call the real Supabase database.

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helper: simulates the conversion logic from new_job_order.dart _submitOrder
// ---------------------------------------------------------------------------
Map<String, dynamic> buildTaskPayload({
  required String name,
  required String operationTypeId,
  required int quantityToProcess,
  required int hours,
  required int minutes,
  String? restrictedResourceId,
  bool breakEnabled = false,
  int breakDurationMinutes = 0,
}) {
  final processingTimeMinutes = hours * 60 + minutes;
  final effectiveBreakDuration = breakEnabled ? breakDurationMinutes : 0;
  return {
    'name': name,
    'operation_type_id': operationTypeId,
    'quantity_to_process': quantityToProcess,
    'processing_time_minutes': processingTimeMinutes,
    'restricted_resource_id': restrictedResourceId, // null = no restriction
    'break_enabled': breakEnabled,
    'break_type': breakEnabled ? 'MACHINE' : null,
    'break_duration_minutes': effectiveBreakDuration,
  };
}

void main() {
  // ── Test 1: 2 hours 0 minutes → processing_time_minutes == 120 ──────────
  test('2 hours and 0 minutes produces processing_time_minutes == 120', () {
    final payload = buildTaskPayload(
      name: 'Print Cover',
      operationTypeId: 'op-uuid-1',
      quantityToProcess: 500,
      hours: 2,
      minutes: 0,
    );

    expect(payload['processing_time_minutes'], equals(120));
  });

  // ── Test 2: separate hours/minutes are NOT sent to the API ───────────────
  test('payload does not contain separate hours or minutes fields', () {
    final payload = buildTaskPayload(
      name: 'Fold',
      operationTypeId: 'op-uuid-2',
      quantityToProcess: 100,
      hours: 1,
      minutes: 30,
    );

    expect(payload.containsKey('hours'), isFalse,
        reason: 'hours should NOT be a top-level field in the API payload');
    expect(payload.containsKey('minutes'), isFalse,
        reason: 'minutes should NOT be a top-level field in the API payload');
    expect(payload['processing_time_minutes'], equals(90));
  });

  // ── Test 3: No Resource Restriction sends null ───────────────────────────
  test('"No Resource Restriction" sends null for restricted_resource_id', () {
    final payload = buildTaskPayload(
      name: 'Bind',
      operationTypeId: 'op-uuid-3',
      quantityToProcess: 200,
      hours: 1,
      minutes: 0,
      restrictedResourceId: null, // explicit no-restriction
    );

    expect(payload['restricted_resource_id'], isNull);
  });

  // ── Test 4: A selected resource sends its real UUID ──────────────────────
  test('A selected resource sends its real database UUID', () {
    const realId = 'res-uuid-abc123';
    final payload = buildTaskPayload(
      name: 'Print',
      operationTypeId: 'op-uuid-1',
      quantityToProcess: 500,
      hours: 2,
      minutes: 0,
      restrictedResourceId: realId,
    );

    expect(payload['restricted_resource_id'], equals(realId));
  });

  // ── Test 5: break disabled → break_type null, duration 0 ────────────────
  test('When break is disabled, break_type is null and duration is 0', () {
    final payload = buildTaskPayload(
      name: 'Trim',
      operationTypeId: 'op-uuid-4',
      quantityToProcess: 100,
      hours: 0,
      minutes: 45,
      breakEnabled: false,
      breakDurationMinutes: 30, // should be ignored when disabled
    );

    expect(payload['break_enabled'], isFalse);
    expect(payload['break_type'], isNull);
    expect(payload['break_duration_minutes'], equals(0));
  });

  // ── Test 6: break enabled → break_type is "MACHINE" ─────────────────────
  test('When break is enabled, break_type is "MACHINE" (uppercase)', () {
    final payload = buildTaskPayload(
      name: 'Laminate',
      operationTypeId: 'op-uuid-5',
      quantityToProcess: 100,
      hours: 1,
      minutes: 0,
      breakEnabled: true,
      breakDurationMinutes: 5,
    );

    expect(payload['break_enabled'], isTrue);
    expect(payload['break_type'], equals('MACHINE'));
    expect(payload['break_duration_minutes'], equals(5));
  });

  // ── Test 7: hours * 60 + minutes conversion correctness ─────────────────
  group('hours × 60 + minutes conversion', () {
    final cases = [
      [0, 30, 30],
      [1, 0, 60],
      [1, 30, 90],
      [2, 0, 120],
      [3, 15, 195],
      [8, 0, 480],
    ];

    for (final c in cases) {
      test('${c[0]}h ${c[1]}m = ${c[2]} minutes', () {
        final payload = buildTaskPayload(
          name: 'Task',
          operationTypeId: 'op',
          quantityToProcess: 1,
          hours: c[0],
          minutes: c[1],
        );
        expect(payload['processing_time_minutes'], equals(c[2]));
      });
    }
  });

  // ── Test 8: duration zero is invalid (hours=0, minutes=0) ───────────────
  test('Duration of 0 h 0 m produces processing_time_minutes == 0 (caller must reject)', () {
    final payload = buildTaskPayload(
      name: 'Zero',
      operationTypeId: 'op',
      quantityToProcess: 1,
      hours: 0,
      minutes: 0,
    );
    // The UI guards against this before calling buildTaskPayload,
    // but we verify the math returns 0 (which the UI then rejects).
    expect(payload['processing_time_minutes'], equals(0));
  });

  // ── Test 9: minutes 0-59 boundary ────────────────────────────────────────
  test('minutes=59 is valid → 0h 59m = 59 min', () {
    final payload = buildTaskPayload(
      name: 'Quick',
      operationTypeId: 'op',
      quantityToProcess: 1,
      hours: 0,
      minutes: 59,
    );
    expect(payload['processing_time_minutes'], equals(59));
  });

  // ── Test 10: break duration 1–480 ────────────────────────────────────────
  test('break_duration_minutes of 480 is accepted', () {
    final payload = buildTaskPayload(
      name: 'Long',
      operationTypeId: 'op',
      quantityToProcess: 1,
      hours: 4,
      minutes: 0,
      breakEnabled: true,
      breakDurationMinutes: 480,
    );
    expect(payload['break_duration_minutes'], equals(480));
    expect(payload['break_type'], equals('MACHINE'));
  });
}
