import 'package:flutter_test/flutter_test.dart';
import 'package:rental_expenses/core/calc/depreciation_calc.dart';
import 'package:rental_expenses/core/constants/mileage_rates.dart';

void main() {
  // ───────────────────────────────────────────────────────────────────────────
  // Depreciation — basis
  // ───────────────────────────────────────────────────────────────────────────
  group('DepreciationCalc — depreciable basis', () {
    test('basis = purchase - land', () {
      // 300,000 - 60,000 = 240,000
      expect(
        DepreciationCalc.depreciableBasis(
            purchasePrice: 300000, landValue: 60000),
        closeTo(240000, 0.01),
      );
    });

    test('basis includes capital improvements', () {
      // (300,000 - 60,000) + 20,000 = 260,000
      expect(
        DepreciationCalc.depreciableBasis(
            purchasePrice: 300000, landValue: 60000, improvements: 20000),
        closeTo(260000, 0.01),
      );
    });

    test('land >= purchase → basis clamped to 0', () {
      expect(
        DepreciationCalc.depreciableBasis(
            purchasePrice: 100000, landValue: 100000),
        equals(0),
      );
      expect(
        DepreciationCalc.depreciableBasis(
            purchasePrice: 100000, landValue: 150000),
        equals(0),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Depreciation — annual (÷ 27.5)
  // ───────────────────────────────────────────────────────────────────────────
  group('DepreciationCalc — annual depreciation', () {
    test('annual = basis / 27.5', () {
      // 275,000 / 27.5 = 10,000
      expect(
        DepreciationCalc.annualDepreciation(
            purchasePrice: 335000, landValue: 60000),
        closeTo(10000, 0.01),
      );
    });

    test('240,000 basis → 8,727.27/yr', () {
      // 240,000 / 27.5 = 8,727.2727…
      expect(
        DepreciationCalc.annualDepreciation(
            purchasePrice: 300000, landValue: 60000),
        closeTo(8727.27, 0.01),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Depreciation — mid-month convention (IRS Table A-6)
  // ───────────────────────────────────────────────────────────────────────────
  group('DepreciationCalc — first-year mid-month fraction', () {
    test('January → 11.5/12 of annual', () {
      // (12 - 1 + 1 - 0.5)/12 = 11.5/12
      expect(DepreciationCalc.firstYearFraction(1), closeTo(11.5 / 12, 1e-9));
    });

    test('July → 5.5/12 of annual', () {
      // (12 - 7 + 1 - 0.5)/12 = 5.5/12
      expect(DepreciationCalc.firstYearFraction(7), closeTo(5.5 / 12, 1e-9));
    });

    test('December → 0.5/12 of annual', () {
      expect(DepreciationCalc.firstYearFraction(12), closeTo(0.5 / 12, 1e-9));
    });

    test('January first-year ≈ 3.485% of basis (IRS Table A-6)', () {
      // basis 275,000 placed in Jan: annual=10,000; ×(11.5/12)=9,583.33
      // as % of basis: 9,583.33 / 275,000 = 3.485%
      final firstYear = DepreciationCalc.firstYearDepreciation(
        purchasePrice: 335000,
        landValue: 60000,
        inServiceMonth: 1,
      );
      expect(firstYear, closeTo(9583.33, 0.5));
      expect(firstYear / 275000 * 100, closeTo(3.485, 0.01));
    });

    test('July first-year ≈ 1.667% of basis (IRS Table A-6)', () {
      final firstYear = DepreciationCalc.firstYearDepreciation(
        purchasePrice: 335000,
        landValue: 60000,
        inServiceMonth: 7,
      );
      // 10,000 × 5.5/12 = 4,583.33 → /275,000 = 1.667%
      expect(firstYear / 275000 * 100, closeTo(1.667, 0.01));
    });

    test('zero basis → zero first-year depreciation', () {
      expect(
        DepreciationCalc.firstYearDepreciation(
            purchasePrice: 100000, landValue: 200000, inServiceMonth: 3),
        equals(0),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Mileage rates
  // ───────────────────────────────────────────────────────────────────────────
  group('MileageRates', () {
    test('2025 = \$0.70/mile', () {
      expect(MileageRates.rateForYear(2025), closeTo(0.70, 1e-9));
    });

    test('2024 = \$0.67/mile', () {
      expect(MileageRates.rateForYear(2024), closeTo(0.67, 1e-9));
    });

    test('2026 = \$0.725/mile', () {
      expect(MileageRates.rateForYear(2026), closeTo(0.725, 1e-9));
    });

    test('future year falls back to latest known rate', () {
      expect(MileageRates.rateForYear(2030), closeTo(0.725, 1e-9));
    });

    test('deduction = miles × rate', () {
      const miles = 250.0;
      final deduction = miles * MileageRates.rateForYear(2025);
      expect(deduction, closeTo(175.0, 0.01)); // 250 × 0.70
    });
  });
}
