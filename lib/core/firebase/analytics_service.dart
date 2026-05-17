import 'package:calcwise_core/calcwise_core.dart';

/// Firebase Analytics wrapper for RentalExpenses.
/// Common events inherited from CalcwiseAnalytics.
/// RentalExpenses-specific events (property, expense, tax, tenant) kept here.
class AnalyticsService extends CalcwiseAnalytics {
  AnalyticsService._() : super(appName: 'RentalExpenses');
  static final AnalyticsService instance = AnalyticsService._();

  // ── App-specific features ─────────────────────────────────────────────────

  Future<void> logPropertyAdded() => log('property_added');
  Future<void> logExpenseTracked(String category) =>
      log('expense_tracked', {'category': category});
  Future<void> logReportViewed() => log('report_viewed');
  Future<void> logPropertiesCompared() => log('properties_compared');
  Future<void> logTaxSummaryViewed() => log('tax_summary_viewed');
  Future<void> logScheduleEExported() => log('schedule_e_exported');
  Future<void> logTenantAdded() => log('tenant_added');
  Future<void> logRecurringExpenseCreated() => log('recurring_expense_created');
}
