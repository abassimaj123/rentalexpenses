// Golden reference tests — RentalExpenses
// Focus: MACRS depreciation accuracy vs IRS Table A-6 (Pub. 527)
//        No rate unit conversion risk here — tests guard against formula drift.
// Sources: IRS Publication 527, Table A-6 (27.5-year residential rental property)

import 'package:flutter_test/flutter_test.dart';
import 'package:rental_expenses/core/calc/depreciation_calc.dart';

void main() {
  void approx(double actual, double expected, {double tol = 1.0}) {
    expect(actual, closeTo(expected, tol),
        reason: 'Expected ~$expected, got $actual');
  }

  // Test basis: $300,000 property, $60,000 land → $240,000 depreciable basis

  // ── depreciableBasis ─────────────────────────────────────────────────────

  group('DepreciationCalc.depreciableBasis', () {
    test('RE-G1: \$300k property / \$60k land → \$240k depreciable basis', () {
      approx(DepreciationCalc.depreciableBasis(
        purchasePrice: 300000,
        landValue: 60000,
      ), 240000, tol: 0.01);
    });

    test('RE-G2: land value ≥ purchase price → \$0 (non-negative basis)', () {
      expect(DepreciationCalc.depreciableBasis(
        purchasePrice: 300000,
        landValue: 350000,
      ), 0.0);
    });

    test('RE-G3: improvements add to basis', () {
      approx(DepreciationCalc.depreciableBasis(
        purchasePrice: 300000,
        landValue: 60000,
        improvements: 20000,
      ), 260000, tol: 0.01);
    });
  });

  // ── annualDepreciation — basis / 27.5 years ──────────────────────────────

  group('DepreciationCalc.annualDepreciation', () {
    test('RE-G4: \$240k basis / 27.5yr → \$8,727.27/yr (IRS constant)', () {
      // Source: IRS Pub 527 — straight-line over 27.5 years
      approx(DepreciationCalc.annualDepreciation(
        purchasePrice: 300000,
        landValue: 60000,
      ), 8727.27, tol: 0.01);
    });
  });

  // ── firstYearFraction — IRS mid-month convention ──────────────────────────

  group('DepreciationCalc.firstYearFraction — IRS mid-month convention', () {
    test('RE-G5: January (month 1) → 11.5/12 = 0.9583', () {
      // IRS Table A-6: Jan → 3.485% = 11.5/(12×27.5) = 11.5/330
      approx(DepreciationCalc.firstYearFraction(1), 11.5 / 12, tol: 0.0001);
    });

    test('RE-G6: July (month 7) → 5.5/12 = 0.4583', () {
      // IRS Table A-6: Jul → 1.667% = 5.5/(12×27.5) = 5.5/330
      approx(DepreciationCalc.firstYearFraction(7), 5.5 / 12, tol: 0.0001);
    });

    test('RE-G7: December (month 12) → 0.5/12 = 0.04167', () {
      // IRS Table A-6: Dec → 0.152% = 0.5/(12×27.5) = 0.5/330
      approx(DepreciationCalc.firstYearFraction(12), 0.5 / 12, tol: 0.0001);
    });
  });

  // ── firstYearDepreciation — IRS Table A-6 golden values ──────────────────

  group('DepreciationCalc.firstYearDepreciation — IRS Table A-6', () {
    test('RE-G8: January service → \$8,363.64 (3.485% × \$240k)', () {
      // IRS Table A-6, Year 1, January: 3.485%
      // 3.485% × $240,000 = $8,364 ≈ 240000 × 11.5/12/27.5 = $8,363.64
      approx(DepreciationCalc.firstYearDepreciation(
        purchasePrice: 300000,
        landValue: 60000,
        inServiceMonth: 1,
      ), 8363.64, tol: 0.10);
    });

    test('RE-G9: July service → \$4,000.00 (1.667% × \$240k)', () {
      // IRS Table A-6, Year 1, July: 1.667%
      // 1.667% × $240,000 = $4,000.80 ≈ 240000 × 5.5/12/27.5 = $4,000.00
      approx(DepreciationCalc.firstYearDepreciation(
        purchasePrice: 300000,
        landValue: 60000,
        inServiceMonth: 7,
      ), 4000.00, tol: 1.0);
    });

    test('RE-G10: January deduction = ~3.485% of basis (IRS Table A-6)', () {
      final deduction = DepreciationCalc.firstYearDepreciation(
        purchasePrice: 300000,
        landValue: 60000,
        inServiceMonth: 1,
      );
      final pct = deduction / 240000 * 100;
      approx(pct, 3.485, tol: 0.001);
    });

    test('RE-G11: later month → lower first-year deduction (monotonic)', () {
      final jan = DepreciationCalc.firstYearDepreciation(
        purchasePrice: 300000, landValue: 60000, inServiceMonth: 1,
      );
      final jul = DepreciationCalc.firstYearDepreciation(
        purchasePrice: 300000, landValue: 60000, inServiceMonth: 7,
      );
      final dec = DepreciationCalc.firstYearDepreciation(
        purchasePrice: 300000, landValue: 60000, inServiceMonth: 12,
      );
      expect(jan, greaterThan(jul));
      expect(jul, greaterThan(dec));
    });
  });
}
