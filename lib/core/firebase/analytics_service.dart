import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final _fa = FirebaseAnalytics.instance;

  Future<void> logAppOpen() => _log('app_open');

  Future<void> logPropertyAdded() => _log('property_added');

  Future<void> logExpenseTracked(String category) =>
      _log('expense_tracked', {'category': category});

  Future<void> logReportViewed() => _log('report_viewed');

  Future<void> logPropertiesCompared() => _log('properties_compared');

  Future<void> logPdfExported() => _log('pdf_exported');

  Future<void> logRewardedAdWatched() => _log('rewarded_ad_watched');

  Future<void> logPurchased() => _log('premium_purchased');

  Future<void> logRestored() => _log('premium_restored');

  Future<void> logPaywallShown({required String type}) =>
      _log('paywall_shown', {'type': type});

  Future<void> logPaywallDismissed() => _log('paywall_dismissed');

  // ── Tax & Schedule E ────────────────────────────────────────────────────
  Future<void> logTaxSummaryViewed() => _log('tax_summary_viewed');
  Future<void> logScheduleEExported() => _log('schedule_e_exported');
  Future<void> logTenantAdded() => _log('tenant_added');
  Future<void> logRecurringExpenseCreated() => _log('recurring_expense_created');

  // ── Error & limit tracking ──────────────────────────────────────────────
  Future<void> logRewardedAdFailed() => _log('rewarded_ad_failed');
  Future<void> logRewardedDailyLimit() => _log('rewarded_daily_limit_reached');
  Future<void> logPurchaseFailed() => _log('purchase_failed');
  Future<void> logBannerFailed() => _log('banner_ad_failed');

  // ── Internals ────────────────────────────────────────────────────────────

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (kDebugMode) return;
    final merged = {'app_name': 'RentalExpenses', ...?params};
    try { await _fa.logEvent(name: name, parameters: merged); } catch (_) {}
  }

}
