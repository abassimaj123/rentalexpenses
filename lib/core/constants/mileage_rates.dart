/// IRS standard mileage rates for business use (USD per mile).
///
/// Update this map each year when the IRS publishes the new rate.
/// Source: IRS standard mileage rates (business).
///   2025 = $0.70/mile
///   2024 = $0.67/mile
///   2023 = $0.655/mile
class MileageRates {
  MileageRates._();

  /// Business standard mileage rate (USD per mile) by tax year.
  static const Map<int, double> businessRatePerMile = {
    2023: 0.655,
    2024: 0.67,
    2025: 0.70,
  };

  /// Most recent known rate, used as a fallback for years not in the map.
  static const double latestRate = 0.70;

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
