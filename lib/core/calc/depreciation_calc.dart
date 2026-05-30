/// US residential rental property depreciation calculator.
///
/// Tax basis: MACRS GDS, 27.5-year straight-line recovery period for
/// residential rental real estate (IRS Pub. 527). The IRS **mid-month
/// convention** applies to real property: property is treated as placed in
/// service (and disposed of) in the middle of the month, regardless of the
/// actual day.
///
/// First-year fraction (mid-month convention):
///   monthsInService = 12 - inServiceMonth + 1   (Jan = 12, ... , Dec = 1)
///   firstYearFraction = (monthsInService - 0.5) / 12
///
/// This matches IRS Table A-6 percentages, e.g.:
///   placed in service January   → 3.485% of basis  ((12 - 0.5)/12 / 27.5)
///   placed in service July      → 1.970%
///   placed in service December  → 0.152%
///
/// Disclaimer: this is an estimate. Land is not depreciable. Consult a tax
/// professional before filing.
class DepreciationCalc {
  DepreciationCalc._();

  /// Residential rental recovery period, in years (MACRS GDS).
  static const double recoveryYears = 27.5;

  /// Depreciable basis = (purchase price − land value) + capital improvements.
  /// Returns 0 if land value ≥ purchase price (non-negative basis).
  static double depreciableBasis({
    required double purchasePrice,
    required double landValue,
    double improvements = 0,
  }) {
    final building = purchasePrice - landValue;
    final basis = building + improvements;
    return basis > 0 ? basis : 0;
  }

  /// Full annual straight-line depreciation = basis / 27.5.
  static double annualDepreciation({
    required double purchasePrice,
    required double landValue,
    double improvements = 0,
  }) {
    final basis = depreciableBasis(
      purchasePrice: purchasePrice,
      landValue: landValue,
      improvements: improvements,
    );
    return basis / recoveryYears;
  }

  /// First-year fraction under the IRS mid-month convention.
  /// [inServiceMonth] is 1 (January) … 12 (December).
  static double firstYearFraction(int inServiceMonth) {
    final m = inServiceMonth.clamp(1, 12);
    final monthsInService = 12 - m + 1; // Jan→12 … Dec→1
    return (monthsInService - 0.5) / 12.0;
  }

  /// First-year depreciation = annual × mid-month fraction.
  static double firstYearDepreciation({
    required double purchasePrice,
    required double landValue,
    required int inServiceMonth,
    double improvements = 0,
  }) {
    final annual = annualDepreciation(
      purchasePrice: purchasePrice,
      landValue: landValue,
      improvements: improvements,
    );
    return annual * firstYearFraction(inServiceMonth);
  }
}
