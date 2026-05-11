import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized Firebase Analytics wrapper for RentalExpenses.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final _fa = FirebaseAnalytics.instance;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> logAppOpen() => _log('app_open');

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> logTabChanged(String tabName) => _log('tab_changed', {
    'tab': tabName, // overview|income|expenses|reports
  });

  // ── Calculator ────────────────────────────────────────────────────────────

  Future<void> logCalculation({
    required double monthlyRent,
    required int    expenseCount,
    required double netIncome,
  }) => _log('calculate', {
    'rent_bucket':    _rentBucket(monthlyRent),
    'expense_count':  expenseCount,
    'net_positive':   netIncome >= 0 ? 'yes' : 'no',
  });

  // ── Paywall ───────────────────────────────────────────────────────────────

  Future<void> logPaywallShown(String type) => _log('paywall_shown', {'type': type});
  Future<void> logPurchaseStarted()         => _log('purchase_started');

  Future<void> logPurchaseCompleted() async {
    await _log('purchase_completed');
    await _fa.logEvent(name: 'purchase', parameters: {
      'currency': 'USD',
      'value':    3.99,
      'items':    'premium_rental_expenses',
    });
  }

  Future<void> logPurchaseRestored()   => _log('purchase_restored');
  Future<void> logPurchaseFailed()     => _log('purchase_failed');
  Future<void> logRewardedAdWatched()  => _log('rewarded_ad_watched');

  // ── Features ─────────────────────────────────────────────────────────────

  Future<void> logPdfExported()       => _log('pdf_exported');
  Future<void> logExpenseAdded()      => _log('expense_added');
  Future<void> logReportGenerated()   => _log('report_generated');
  Future<void> logHistorySaved()      => _log('history_saved');

  // ── User property ─────────────────────────────────────────────────────────

  Future<void> setUserPremium(bool isPremium) =>
      _fa.setUserProperty(name: 'is_premium', value: isPremium ? 'true' : 'false');

  // ── Error & limit tracking ────────────────────────────────────────────────

  Future<void> logRewardedAdFailed() => _log('rewarded_ad_failed');
  Future<void> logPaywallDismissed() => _log('paywall_dismissed');
  Future<void> logBannerFailed()     => _log('banner_ad_failed');

  // ── Internals ─────────────────────────────────────────────────────────────

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    final merged = <String, Object>{'app_name': 'RentalExpenses', ...?params};
    if (kDebugMode) {
      debugPrint('[Analytics] $name $merged');
      return;
    }
    await _fa.logEvent(name: name, parameters: merged);
  }

  String _rentBucket(double rent) {
    if (rent < 1000)  return '<1k';
    if (rent < 2500)  return '1-2.5k';
    if (rent < 5000)  return '2.5-5k';
    return '>5k';
  }
}
