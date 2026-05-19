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

  // ── Universal events (Phase 2) ────────────────────────────────────────────

  Future<void> logScreenView(String screenName) =>
      log('screen_view', {'screen_name': screenName});
  Future<void> logOnboardingComplete() => log('onboarding_complete');
  Future<void> logOnboardingSkipped()  => log('onboarding_skipped');
  Future<void> logFirstCalculate()     => log('first_calculate');
  Future<void> logDarkModeToggled(bool enabled) =>
      log('dark_mode_toggled', {'enabled': '$enabled'});
  Future<void> logLanguageChanged(String lang) =>
      log('language_changed', {'language': lang});
  Future<void> logShareTapped()   => log('share_tapped');
  Future<void> logExportStarted() => log('export_started');
  Future<void> logUpgradeButtonTapped(String source) =>
      log('upgrade_tapped', {'source': source});
  Future<void> logFeatureGated(String feature) =>
      log('feature_gated', {'feature': feature});

  // ── RentalExpenses domain events (Phase 2) ────────────────────────────────

  Future<void> logExpenseLogged()    => log('expense_logged');
  Future<void> logRoiCalculated()    => log('roi_calculated_v2');
}
