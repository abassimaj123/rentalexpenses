import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calcwise_core/calcwise_core.dart';

class _MemoryAdapter implements DatabaseAdapter {
  final List<Map<String, dynamic>> _rows = [];
  int _nextId = 1;
  int get rowCount => _rows.length;

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
    result.sort((a, b) {
      final aPin = a['is_pinned'] as int;
      final bPin = b['is_pinned'] as int;
      if (aPin != bPin) return bPin.compareTo(aPin);
      return (b['saved_at'] as int).compareTo(a['saved_at'] as int);
    });
    if (limit != null && result.length > limit) result = result.sublist(0, limit);
    return result;
  }

  @override
  Future<Map<String, dynamic>?> getRowByHash({required String appKey, required String resultHash}) async {
    try { return _rows.firstWhere((r) => r['app_key'] == appKey && r['result_hash'] == resultHash); }
    catch (_) { return null; }
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
  Future<List<Map<String, dynamic>>> getOldestAutoSaves({required String appKey, required int limit}) async {
    final rows = _rows.where((r) => r['app_key'] == appKey && (r['is_pinned'] as int) == 0).toList()
      ..sort((a, b) => (a['saved_at'] as int).compareTo(b['saved_at'] as int));
    return rows.take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getOldestPinned({required String appKey, required int limit}) async {
    final rows = _rows.where((r) => r['app_key'] == appKey && (r['is_pinned'] as int) == 1).toList()
      ..sort((a, b) => (a['saved_at'] as int).compareTo(b['saved_at'] as int));
    return rows.take(limit).toList();
  }
}

Future<void> _pump() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
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

  group('RentalExpenses — save → history scenarios', () {
    test('scenario: analyse rental property → entry appears in history', () async {
      // GIVEN: typical rental property inputs (mirrors _buildL1/_buildL2 in calculator_screen.dart)
      const propertyValue = 380000.0;
      const monthlyRent = 2400.0;
      const mortgage = 1800.0;
      const propertyTaxes = 320.0;
      const insurance = 120.0;
      const totalExpenses = 2350.0;
      const monthlyCashFlow = 50.0;
      const capRate = 3.8;

      final inputHash = ResultHasher.hashInputs({
        'rent': ResultHasher.roundTo(monthlyRent, 100),
        'expenses': ResultHasher.roundTo(totalExpenses, 100),
        'prop_value': ResultHasher.roundTo(propertyValue, 5000),
        'cash_invested': ResultHasher.roundTo(76000.0, 5000),
      });

      // WHEN: auto-save triggered (mirrors calculator_screen._scheduleAutoSave)
      var savedCalled = false;
      svc.scheduleAutoSave(
        appKey: 'rentalexpenses',
        screenId: 'expenses',
        inputHash: inputHash,
        l1: {
          'property_value': propertyValue,
          'monthly_rent': monthlyRent,
          'monthly_cashflow': monthlyCashFlow,
          'cap_rate': capRate,
          'coc_return': 0.79,
        },
        l2: {
          'inputs': {
            'property_name': 'My Rental',
            'property_value': propertyValue,
            'cash_invested': 76000.0,
            'monthly_rent': monthlyRent,
            'mortgage': mortgage,
            'property_taxes': propertyTaxes,
            'insurance': insurance,
            'hoa_fees': 0.0,
            'property_mgmt': 0.0,
            'maintenance': 50.0,
            'vacancy_loss': 0.0,
            'utilities': 0.0,
            'landscaping': 0.0,
            'other_expenses': 60.0,
          },
          'results': {
            'total_expenses': totalExpenses,
            'monthly_cashflow': monthlyCashFlow,
            'annual_cashflow': monthlyCashFlow * 12,
          },
        },
        onSaved: () => savedCalled = true,
      );
      await _pump();

      // THEN
      final history = await svc.getHistory('rentalexpenses');
      expect(history, isNotEmpty,
          reason: 'History must contain the rental property entry');
      expect(history.first.l1['property_value'], propertyValue);
      expect(savedCalled, isTrue,
          reason: 'onSaved must fire — anti-regression for history refresh race condition');
    });

    test('scenario: two different properties → both entries in history', () async {
      for (var i = 0; i < 2; i++) {
        final value = 300000.0 + i * 100000;
        svc.scheduleAutoSave(
          appKey: 'rentalexpenses',
          screenId: 'expenses',
          inputHash: 'hash-rental-$i',
          l1: {'property_value': value, 'monthly_rent': 2000.0 + i * 400, 'monthly_cashflow': 100.0},
          l2: {
            'inputs': {'property_value': value, 'monthly_rent': 2000.0 + i * 400},
            'results': {'monthly_cashflow': 100.0},
          },
        );
        await _pump();
      }
      final history = await svc.getHistory('rentalexpenses');
      expect(history.length, 2);
    });

    test('scenario: same property inputs twice → only one history entry', () async {
      const hash = 'same-hash-rentalexpenses';
      for (var i = 0; i < 3; i++) {
        svc.scheduleAutoSave(
          appKey: 'rentalexpenses',
          screenId: 'expenses',
          inputHash: hash,
          l1: {'property_value': 350000.0, 'monthly_rent': 2200.0, 'monthly_cashflow': -50.0},
          l2: {
            'inputs': {'property_value': 350000.0, 'monthly_rent': 2200.0},
            'results': {'monthly_cashflow': -50.0},
          },
        );
        await _pump();
      }
      expect(adapter.rowCount, 1,
          reason: 'Identical inputs must not create duplicates');
    });

    test('scenario: pinned property survives ring buffer eviction', () async {
      await svc.saveScenario(
        appKey: 'rentalexpenses',
        screenId: 'expenses',
        inputHash: 'pinned-rental-scenario',
        l1: {'property_value': 500000.0, 'monthly_rent': 3200.0, 'monthly_cashflow': 350.0, 'cap_rate': 5.9},
        l2: {
          'inputs': {'property_value': 500000.0, 'monthly_rent': 3200.0, 'cash_invested': 100000.0},
          'results': {'monthly_cashflow': 350.0, 'cap_rate': 5.9},
        },
        label: 'Best cashflow property',
      );
      for (var i = 0; i < MonetizationConfig.freeRingBufferSize + 2; i++) {
        svc.scheduleAutoSave(
          appKey: 'rentalexpenses',
          screenId: 'expenses',
          inputHash: 'auto-rental-$i',
          l1: {'property_value': i * 50000.0, 'monthly_rent': i * 200.0},
          l2: {'inputs': {'property_value': i * 50000.0}, 'results': <String, dynamic>{}},
        );
        await _pump();
      }
      final pinned = await svc.getPinned('rentalexpenses');
      expect(pinned, isNotEmpty,
          reason: 'Pinned property must survive ring buffer eviction');
      expect(pinned.first.l1['property_value'], 500000.0);
    });
  });
}
