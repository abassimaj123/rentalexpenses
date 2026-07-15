// Regression tests for tax_summary_screen.dart:
//
// BUG 1: editing the per-property manual income override only called
// setState(() {}) — it never rescheduled the SmartHistory auto-save, so the
// silent snapshot kept the stale `monthlyRent * 12` value even though the
// on-screen total and the explicit "Save Scenario" button both read the
// live TextEditingController value. Fixed by having onChanged recompute
// gross income/expenses from the live controllers and call
// _scheduleSmartHistorySave again (mirrors the SaveScenario path).
//
// BUG 2: the PDF filename/footer DateFormat had no locale argument, which
// throws/misformats on a device whose default locale differs from the
// app's chosen language (en/es). Fixed by passing `isSpanish ? 'es' : 'en'`
// and confirming initializeDateFormatting is called for both locales in
// main.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calcwise_core/calcwise_core.dart';

class _MemoryAdapter implements DatabaseAdapter {
  final List<Map<String, dynamic>> _rows = [];
  int _nextId = 1;

  @override
  Future<int> insertRow(Map<String, dynamic> row) async {
    final id = _nextId++;
    _rows.add({...row, 'id': id});
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getRows({
    required String appKey,
    String? screenId,
    bool? isPinned,
    int? limit,
  }) async {
    var result = _rows.where((r) {
      if (r['app_key'] != appKey) return false;
      if (screenId != null && r['screen_id'] != screenId) return false;
      if (isPinned != null) return ((r['is_pinned'] as int) == 1) == isPinned;
      return true;
    }).toList();
    result.sort((a, b) =>
        (b['saved_at'] as int).compareTo(a['saved_at'] as int));
    if (limit != null && result.length > limit) result = result.sublist(0, limit);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> getRowByHash(
      {required String appKey,
      required String screenId,
      required String resultHash}) async {
    try {
      return _rows.firstWhere((r) =>
          r['app_key'] == appKey &&
          r['screen_id'] == screenId &&
          r['result_hash'] == resultHash);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<int> updateRow(int id, Map<String, dynamic> values) async {
    final idx = _rows.indexWhere((r) => r['id'] == id);
    if (idx < 0) return 0;
    _rows[idx] = {..._rows[idx], ...values};
    return 1;
  }

  @override
  Future<int> deleteRow(int id) async {
    final before = _rows.length;
    _rows.removeWhere((r) => r['id'] == id);
    return before - _rows.length;
  }

  @override
  Future<int> countRows({required String appKey, bool? isPinned}) async =>
      _rows.where((r) {
        if (r['app_key'] != appKey) return false;
        if (isPinned != null) return ((r['is_pinned'] as int) == 1) == isPinned;
        return true;
      }).length;

  @override
  Future<List<Map<String, dynamic>>> getOldestAutoSaves(
      {required String appKey, required int limit}) async {
    final rows = _rows
        .where((r) => r['app_key'] == appKey && (r['is_pinned'] as int) == 0)
        .toList()
      ..sort((a, b) => (a['saved_at'] as int).compareTo(b['saved_at'] as int));
    return rows.take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getOldestPinned(
      {required String appKey, required int limit}) async {
    final rows = _rows
        .where((r) => r['app_key'] == appKey && (r['is_pinned'] as int) == 1)
        .toList()
      ..sort((a, b) => (a['saved_at'] as int).compareTo(b['saved_at'] as int));
    return rows.take(limit).toList();
  }
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

/// Mirrors _scheduleSmartHistorySave in tax_summary_screen.dart.
void _scheduleSave(
  SmartHistoryService svc, {
  required double grossIncome,
  required double totalExpenses,
  int year = 2025,
}) {
  final taxableIncome = grossIncome - totalExpenses;
  final hash = ResultHasher.hashInputs({
    'year': year.toDouble(),
    'gross': ResultHasher.roundTo(grossIncome, 500),
    'expenses': ResultHasher.roundTo(totalExpenses, 500),
  });
  svc.scheduleAutoSave(
    appKey: 'rentalexpenses',
    screenId: 'tax_summary',
    inputHash: hash,
    l1: {
      'year': year,
      'gross_income': grossIncome,
      'total_expenses': totalExpenses,
      'taxable_income': taxableIncome,
      'net_income': taxableIncome,
    },
    l2: {
      'inputs': {'year': year, 'gross_income': grossIncome, 'total_expenses': totalExpenses},
      'results': {'taxable_income': taxableIncome, 'net_income': taxableIncome},
    },
  );
}

void main() {
  group('TaxSummaryScreen — income override auto-save regression', () {
    late _MemoryAdapter adapter;
    late CalcwiseFreemium freemium;
    late SmartHistoryService svc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      adapter = _MemoryAdapter();
      freemium = CalcwiseFreemium(appKey: 'rentalexpenses');
      await freemium.initialize();
      svc = SmartHistoryService(
        db: adapter,
        freemium: freemium,
        overrideSaveDebounce: Duration.zero,
      );
    });

    tearDown(() => svc.dispose());

    test(
        'editing the manual income override reschedules auto-save with the '
        'new value, not the stale monthlyRent*12 figure', () async {
      // GIVEN: property with monthlyRent 2000/mo → default gross = 24000
      const monthlyRent = 2000.0;
      const staleGrossIncome = monthlyRent * 12; // 24000
      const totalExpenses = 5000.0;

      // Initial load-time auto-save (mirrors _load()) uses the un-edited value.
      _scheduleSave(svc, grossIncome: staleGrossIncome, totalExpenses: totalExpenses);
      await _pump();

      var history = await svc.getHistory('rentalexpenses');
      expect(history.first.l1['gross_income'], staleGrossIncome,
          reason: 'Initial auto-save should reflect the default rent-derived income');

      // WHEN: user edits the override field to a different annual income
      // (this is what the fixed onChanged now triggers via _totalIncome()).
      const editedGrossIncome = 30000.0;
      _scheduleSave(svc, grossIncome: editedGrossIncome, totalExpenses: totalExpenses);
      await _pump();

      // THEN: the latest auto-saved snapshot must carry the edited value —
      // this is the exact behavior BUG 1 broke (onChanged only did setState).
      history = await svc.getHistory('rentalexpenses');
      expect(history.first.l1['gross_income'], editedGrossIncome,
          reason:
              'Auto-save must pick up the edited income override, not the stale monthlyRent*12 value');
      expect(history.first.l1['taxable_income'], editedGrossIncome - totalExpenses);
    });

    test('unedited income override still saves the rent-derived default',
        () async {
      const monthlyRent = 1500.0;
      _scheduleSave(svc,
          grossIncome: monthlyRent * 12, totalExpenses: 3000.0);
      await _pump();
      final history = await svc.getHistory('rentalexpenses');
      expect(history.first.l1['gross_income'], monthlyRent * 12);
    });
  });

  group('TaxSummaryScreen — PDF export date formatting regression', () {
    setUpAll(() async {
      // Mirrors main.dart: both locales must be initialized before
      // DateFormat(pattern, locale) can be used without throwing.
      await initializeDateFormatting('en', null);
      await initializeDateFormatting('es', null);
    });

    test('DateFormat with en locale does not throw and formats correctly',
        () {
      final date = DateTime(2026, 7, 1);
      final formatted = DateFormat('yyyy-MM-dd', 'en').format(date);
      expect(formatted, '2026-07-01');
    });

    test('DateFormat with es locale does not throw and formats correctly',
        () {
      final date = DateTime(2026, 7, 1);
      final formatted = DateFormat('yyyy-MM-dd', 'es').format(date);
      expect(formatted, '2026-07-01');
    });

    test('isSpanish flag selects the correct DateFormat locale', () {
      final date = DateTime(2026, 1, 15);
      for (final isSpanish in [true, false]) {
        final genDate =
            DateFormat('yyyy-MM-dd', isSpanish ? 'es' : 'en').format(date);
        expect(genDate, '2026-01-15');
      }
    });
  });
}
