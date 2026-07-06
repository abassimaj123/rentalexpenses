/// IRS standard mileage rates for business use (USD per mile).
///
/// Update this map each year when the IRS publishes the new rate.
/// Source: IRS standard mileage rates (business).
///   2026 = $0.700/mile (IRS Rev. Proc. 2025-35)
///   2025 = $0.700/mile (IRS Rev. Proc. 2024-57)
///   2024 = $0.670/mile (IRS Notice 2024-8)
///   2023 = $0.655/mile (IRS Notice 2023-3)
class MileageRates {
  MileageRates._();

  /// Business standard mileage rate (USD per mile) by tax year.
  static const Map<int, double> businessRatePerMile = {
    2023: 0.655,
    2024: 0.67,
    2025: 0.700,
    2026: 0.700,
  };

  /// Most recent known rate, used as a fallback for years not in the map.
  static const double latestRate = 0.700;

  /// Returns the business rate for [year], falling back to the closest
  /// earlier known year, or [latestRate] if none.
  static double rateForYear(int year) {
    if (businessRatePerMile.containsKey(year)) {
      return businessRatePerMile[year]!;
    }
    // Fall back to the highest known year ≤ requested year.
    final earlier = businessRatePerMile.keys.where((y) => y <= year).toList()
      ..sort();
    if (earlier.isNotEmpty) return businessRatePerMile[earlier.last]!;
    return latestRate;
  }
}
