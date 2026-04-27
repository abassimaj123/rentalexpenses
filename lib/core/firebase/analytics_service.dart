import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final _a = FirebaseAnalytics.instance;

  Future<void> logPropertyAdded() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'property_added');
  }

  Future<void> logExpenseTracked(String category) async {
    if (kDebugMode) return;
    await _a.logEvent(
      name: 'expense_tracked',
      parameters: {'category': category},
    );
  }

  Future<void> logReportViewed() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'report_viewed');
  }

  Future<void> logPropertiesCompared() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'properties_compared');
  }

  Future<void> logPdfExported() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'pdf_exported');
  }

  Future<void> logRewardedAdWatched() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'rewarded_ad_watched');
  }

  Future<void> logPurchased() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'premium_purchased');
  }

  Future<void> logRestored() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'premium_restored');
  }

  Future<void> logPaywallShown({required String type}) async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'paywall_shown', parameters: {'type': type});
  }

  Future<void> logPaywallDismissed() async {
    if (kDebugMode) return;
    await _a.logEvent(name: 'paywall_dismissed');
  }
}
