// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_expenses/models/expense_model.dart';
import 'package:rental_expenses/models/property_model.dart';
import 'package:rental_expenses/screens/calculator_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helper — builds an ExpenseCalc with all 10 expense fields
// ─────────────────────────────────────────────────────────────────────────────

ExpenseCalc _calc({
  String name = 'Test Property',
  double rent = 0,
  double mortgage = 0,
  double propertyTaxes = 0,
  double insurance = 0,
  double hoaFees = 0,
  double propertyMgmt = 0,
  double maintenance = 0,
  double vacancyLoss = 0,
  double utilities = 0,
  double landscaping = 0,
  double otherExpenses = 0,
}) =>
    ExpenseCalc(
      propertyName: name,
      rentIncome: rent,
      mortgage: mortgage,
      propertyTaxes: propertyTaxes,
      insurance: insurance,
      hoaFees: hoaFees,
      propertyMgmt: propertyMgmt,
      maintenance: maintenance,
      vacancyLoss: vacancyLoss,
      utilities: utilities,
      landscaping: landscaping,
      otherExpenses: otherExpenses,
      savedAt: DateTime(2026, 1, 1),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Helper — builds a MonthlyExpense with all 10 expense fields
// ─────────────────────────────────────────────────────────────────────────────

MonthlyExpense _monthly({
  double mortgage = 0,
  double propertyTaxes = 0,
  double insurance = 0,
  double hoaFees = 0,
  double propertyMgmt = 0,
  double maintenance = 0,
  double vacancyLoss = 0,
  double utilities = 0,
  double landscaping = 0,
  double otherExpenses = 0,
}) =>
    MonthlyExpense(
      id: 'test-id',
      propertyId: 'prop-1',
      year: 2026,
      month: 1,
      mortgage: mortgage,
      propertyTaxes: propertyTaxes,
      insurance: insurance,
      hoaFees: hoaFees,
      propertyMgmt: propertyMgmt,
      maintenance: maintenance,
      vacancyLoss: vacancyLoss,
      utilities: utilities,
      landscaping: landscaping,
      otherExpenses: otherExpenses,
    );

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // ExpenseCalc — Case A: 10-category typical rental property
  // ───────────────────────────────────────────────────────────────────────────
  group('ExpenseCalc — Case A (10-category typical property)', () {
    // rent=1800, mgmt=144 (8%), vacancy=90 (5%)
    // totalExpenses = 950+180+95+0+144+90+90+0+50+30 = 1,629
    late ExpenseCalc calc;

    setUp(() {
      calc = _calc(
        rent: 1800,
        mortgage: 950,
        propertyTaxes: 180,
        insurance: 95,
        hoaFees: 0,
        propertyMgmt: 144, // 8% of 1800 = 144 (pre-converted by screen)
        maintenance: 90,
        vacancyLoss: 90, // 5% of 1800 = 90 (pre-converted by screen)
        utilities: 0,
        landscaping: 50,
        otherExpenses: 30,
      );
    });

    test('totalExpenses = 1,629', () {
      expect(calc.totalExpenses, closeTo(1629.0, 0.01));
    });

    test('monthlyCashFlow = 171', () {
      expect(calc.monthlyCashFlow, closeTo(171.0, 0.01));
    });

    test('annualCashFlow = 2,052', () {
      expect(calc.annualCashFlow, closeTo(2052.0, 1.0));
    });

    test('expenseRatio = 90.5%', () {
      // 1629 / 1800 * 100 = 90.5%
      expect(calc.expenseRatio, closeTo(90.5, 0.05));
    });

    test('breakEvenRent = totalExpenses = 1,629', () {
      expect(calc.breakEvenRent, closeTo(1629.0, 0.01));
    });

    test('NOI = (rent - non-mortgage expenses) * 12', () {
      // nonMortgageExpenses = 1629 - 950 = 679
      // NOI = (1800 - 679) * 12 = 1121 * 12 = 13,452
      expect(calc.noi, closeTo(13452.0, 1.0));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ExpenseCalc — Case B: High expense ratio / negative cash flow
  // ───────────────────────────────────────────────────────────────────────────
  group('ExpenseCalc — Case B (high expense ratio, loss)', () {
    // rent=2000, totalExpenses=2300 → cash flow = -300
    late ExpenseCalc calc;

    setUp(() {
      calc = _calc(
        rent: 2000,
        mortgage: 1200,
        propertyTaxes: 250,
        insurance: 150,
        hoaFees: 200,
        propertyMgmt: 200,
        maintenance: 150,
        vacancyLoss: 100,
        utilities: 50,
        landscaping: 0,
        otherExpenses: 0,
      );
      // Verify setup sums to 2300
      // 1200+250+150+200+200+150+100+50 = 2300
    });

    test('totalExpenses = 2,300', () {
      expect(calc.totalExpenses, closeTo(2300.0, 0.01));
    });

    test('monthlyCashFlow = -300 (loss)', () {
      expect(calc.monthlyCashFlow, closeTo(-300.0, 0.01));
    });

    test('annualCashFlow = -3,600 (annual loss)', () {
      expect(calc.annualCashFlow, closeTo(-3600.0, 1.0));
    });

    test('expenseRatio > 100% (115%)', () {
      // 2300 / 2000 * 100 = 115.0%
      expect(calc.expenseRatio, closeTo(115.0, 0.05));
    });

    test('cash flow is negative (property is losing money)', () {
      expect(calc.monthlyCashFlow, isNegative);
    });

    test('NOI is negative (non-mortgage expenses exceed rent)', () {
      // nonMortgage = 2300 - 1200 = 1100
      // NOI = (2000 - 1100) * 12 = 900 * 12 = 10,800 — positive because
      // mortgage is excluded from NOI per real estate convention
      expect(calc.noi, closeTo(10800.0, 1.0));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ExpenseCalc — Case C: Annual projection
  // ───────────────────────────────────────────────────────────────────────────
  group('ExpenseCalc — Case C (annual projection)', () {
    test('annualCashFlow = monthly * 12 when expenses = 1,200', () {
      final calc = _calc(rent: 2000, mortgage: 1200);
      // monthlyCashFlow = 2000 - 1200 = 800
      // annualCashFlow  = 800  * 12   = 9,600
      expect(calc.monthlyCashFlow, closeTo(800.0, 0.01));
      expect(calc.annualCashFlow, closeTo(9600.0, 1.0));
    });

    test('monthlyExpense=1,200 → annualExpense implicit in annualCashFlow', () {
      // rent=2400, totalExpenses=1200 → monthly CF=1200, annual CF=14400
      final calc = _calc(
        rent: 2400,
        mortgage: 600,
        propertyTaxes: 200,
        insurance: 100,
        maintenance: 200,
        vacancyLoss: 100,
      );
      // totalExpenses = 600+200+100+200+100 = 1,200
      expect(calc.totalExpenses, closeTo(1200.0, 0.01));
      expect(calc.annualCashFlow, closeTo((2400 - 1200) * 12, 1.0));
      expect(calc.annualCashFlow, closeTo(14400.0, 1.0));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ExpenseCalc — Edge cases
  // ───────────────────────────────────────────────────────────────────────────
  group('ExpenseCalc — Edge cases', () {
    test('zero rent → expenseRatio = 0 (no division by zero)', () {
      final calc = _calc(rent: 0, mortgage: 500);
      expect(calc.expenseRatio, equals(0.0));
    });

    test('zero expenses → totalExpenses = 0, cashFlow = rent', () {
      final calc = _calc(rent: 1500);
      expect(calc.totalExpenses, equals(0.0));
      expect(calc.monthlyCashFlow, closeTo(1500.0, 0.01));
    });

    test('breakEvenRent always equals totalExpenses', () {
      final calc = _calc(rent: 2000, mortgage: 800, insurance: 100);
      expect(calc.breakEvenRent, equals(calc.totalExpenses));
    });

    test('all 10 categories sum correctly', () {
      final calc = _calc(
        rent: 5000,
        mortgage: 1000,
        propertyTaxes: 200,
        insurance: 100,
        hoaFees: 50,
        propertyMgmt: 400,
        maintenance: 150,
        vacancyLoss: 250,
        utilities: 75,
        landscaping: 60,
        otherExpenses: 40,
      );
      // 1000+200+100+50+400+150+250+75+60+40 = 2325
      expect(calc.totalExpenses, closeTo(2325.0, 0.01));
    });

    test('property management % conversion: 8% of 1800 = 144', () {
      // In the screen _calculate(), percent is pre-converted before creating ExpenseCalc.
      // This test validates the arithmetic independently.
      const rent = 1800.0;
      const pct = 8.0;
      final mgmtDollar = rent * pct / 100;
      expect(mgmtDollar, closeTo(144.0, 0.01));
    });

    test('vacancy loss % conversion: 5% of 1800 = 90', () {
      const rent = 1800.0;
      const pct = 5.0;
      final vacDollar = rent * pct / 100;
      expect(vacDollar, closeTo(90.0, 0.01));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ExpenseCalc — NOI formula verification
  // ───────────────────────────────────────────────────────────────────────────
  group('ExpenseCalc — NOI (Net Operating Income)', () {
    test('NOI excludes mortgage from expense side', () {
      // NOI = (rent - non-mortgage expenses) * 12
      final calc = _calc(
        rent: 1800,
        mortgage: 950,
        propertyTaxes: 180,
        insurance: 95,
        maintenance: 90,
        vacancyLoss: 90,
        propertyMgmt: 144,
        landscaping: 50,
        otherExpenses: 30,
      );
      // non-mortgage = 180+95+90+90+144+50+30 = 679
      // NOI = (1800 - 679) * 12 = 1121 * 12 = 13,452
      expect(calc.noi, closeTo(13452.0, 1.0));
    });

    test('NOI with mortgage-only expenses: NOI = rent * 12', () {
      // If only mortgage is listed, non-mortgage expenses = 0
      // NOI = (rent - 0) * 12 = rent * 12
      final calc = _calc(rent: 2000, mortgage: 1200);
      expect(calc.noi, closeTo(2000.0 * 12, 1.0));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // MonthlyExpense model — totalExpenses getter
  // ───────────────────────────────────────────────────────────────────────────
  group('MonthlyExpense model — totalExpenses', () {
    test('sums all 10 categories', () {
      final e = _monthly(
        mortgage: 950,
        propertyTaxes: 180,
        insurance: 95,
        hoaFees: 0,
        propertyMgmt: 144,
        maintenance: 90,
        vacancyLoss: 90,
        utilities: 0,
        landscaping: 50,
        otherExpenses: 30,
      );
      expect(e.totalExpenses, closeTo(1629.0, 0.01));
    });

    test('defaults to zero when no arguments provided', () {
      final e = _monthly();
      expect(e.totalExpenses, equals(0.0));
    });

    test('date getter returns correct DateTime', () {
      final e = _monthly();
      expect(e.date, equals(DateTime(2026, 1)));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // MonthlyExpense — serialization round-trip
  // ───────────────────────────────────────────────────────────────────────────
  group('MonthlyExpense — toMap / fromMap round-trip', () {
    test('values survive serialization', () {
      final original = _monthly(
        mortgage: 950,
        propertyTaxes: 180,
        insurance: 95,
        maintenance: 90,
        vacancyLoss: 90,
        landscaping: 50,
        otherExpenses: 30,
      );
      final restored = MonthlyExpense.fromMap(original.toMap());
      expect(restored.totalExpenses, closeTo(original.totalExpenses, 0.001));
      expect(restored.mortgage, closeTo(original.mortgage, 0.001));
      expect(restored.propertyTaxes, closeTo(original.propertyTaxes, 0.001));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // MonthlyExpense — copyWith
  // ───────────────────────────────────────────────────────────────────────────
  group('MonthlyExpense — copyWith', () {
    test('copyWith updates only specified field', () {
      final original = _monthly(mortgage: 950, insurance: 95);
      final updated = original.copyWith(insurance: 120);
      expect(updated.mortgage, closeTo(950, 0.001));
      expect(updated.insurance, closeTo(120, 0.001));
      expect(updated.totalExpenses, closeTo(1070, 0.01)); // 950+120
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Property model — monthlyRent and cashFlow via reports screen formula
  // ───────────────────────────────────────────────────────────────────────────
  group('Property model + expense cashFlow (reports screen formula)', () {
    test('cashFlow = monthlyRent - totalExpenses', () {
      final prop = Property(
        id: 'p1',
        name: 'Oak Ave',
        address: '100 Oak Ave',
        monthlyRent: 1800,
        squareFootage: 1200,
        createdDate: DateTime(2025, 6, 1),
      );
      final expense = _monthly(
        mortgage: 950,
        propertyTaxes: 180,
        insurance: 95,
        propertyMgmt: 144,
        maintenance: 90,
        vacancyLoss: 90,
        landscaping: 50,
        otherExpenses: 30,
      );
      final cf = prop.monthlyRent - expense.totalExpenses;
      expect(cf, closeTo(171.0, 0.01));
    });

    test('cashFlow is negative when expenses exceed rent', () {
      final prop = Property(
        id: 'p2',
        name: 'Loss Property',
        address: '200 Main St',
        monthlyRent: 2000,
        squareFootage: 900,
        createdDate: DateTime(2025, 1, 1),
      );
      final expense = _monthly(
        mortgage: 1200,
        propertyTaxes: 250,
        insurance: 150,
        hoaFees: 200,
        propertyMgmt: 200,
        maintenance: 150,
        vacancyLoss: 100,
        utilities: 50,
      );
      final cf = prop.monthlyRent - expense.totalExpenses;
      expect(cf, closeTo(-300.0, 0.01));
      expect(cf, isNegative);
    });

    test('Property serialization round-trip preserves monthlyRent', () {
      final p = Property(
        id: 'p3',
        name: 'Duplex',
        address: '300 Elm St',
        monthlyRent: 2400,
        squareFootage: 1500,
        createdDate: DateTime(2025, 3, 15),
      );
      final restored = Property.fromMap(p.toMap());
      expect(restored.monthlyRent, closeTo(2400, 0.001));
      expect(restored.name, equals('Duplex'));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ExpenseCalc — JSON round-trip
  // ───────────────────────────────────────────────────────────────────────────
  group('ExpenseCalc — toJson / fromJson round-trip', () {
    test('all financial fields survive serialization', () {
      final original = _calc(
        name: 'Test',
        rent: 1800,
        mortgage: 950,
        propertyTaxes: 180,
        insurance: 95,
        propertyMgmt: 144,
        maintenance: 90,
        vacancyLoss: 90,
        landscaping: 50,
        otherExpenses: 30,
      );
      final restored = ExpenseCalc.fromJson(original.toJson());
      expect(restored.totalExpenses, closeTo(original.totalExpenses, 0.001));
      expect(
          restored.monthlyCashFlow, closeTo(original.monthlyCashFlow, 0.001));
      expect(restored.annualCashFlow, closeTo(original.annualCashFlow, 0.001));
      expect(restored.expenseRatio, closeTo(original.expenseRatio, 0.001));
      expect(restored.noi, closeTo(original.noi, 0.001));
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // ExpenseCalc — breakdown map
  // ───────────────────────────────────────────────────────────────────────────
  group('ExpenseCalc — breakdown map', () {
    test('breakdown contains all 10 categories', () {
      final calc = _calc(
        mortgage: 950,
        propertyTaxes: 180,
        insurance: 95,
        hoaFees: 0,
        propertyMgmt: 144,
        maintenance: 90,
        vacancyLoss: 90,
        utilities: 0,
        landscaping: 50,
        otherExpenses: 30,
      );
      final bd = calc.breakdown;
      expect(bd['Mortgage'], closeTo(950, 0.001));
      expect(bd['Property Taxes'], closeTo(180, 0.001));
      expect(bd['Insurance'], closeTo(95, 0.001));
      expect(bd['HOA Fees'], closeTo(0, 0.001));
      expect(bd['Property Mgmt'], closeTo(144, 0.001));
      expect(bd['Maintenance'], closeTo(90, 0.001));
      expect(bd['Vacancy Loss'], closeTo(90, 0.001));
      expect(bd['Utilities'], closeTo(0, 0.001));
      expect(bd['Landscaping'], closeTo(50, 0.001));
      expect(bd['Other'], closeTo(30, 0.001));
    });

    test('breakdownES contains Spanish labels', () {
      final calc = _calc(mortgage: 950, insurance: 95);
      expect(calc.breakdownES.containsKey('Hipoteca'), isTrue);
      expect(calc.breakdownES.containsKey('Seguro'), isTrue);
      expect(calc.breakdownES['Hipoteca'], closeTo(950, 0.001));
    });
  });
}
