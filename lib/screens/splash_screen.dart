import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../core/theme/app_theme.dart';
import '../core/firebase/analytics_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    try { AnalyticsService.instance.logAppOpen(); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => CalcwiseSplash(
    appName:     'Rental',
    appSuffix:   'Pro',
    tagline:     'Track every rental dollar',
    chips:       const ['ROI', 'Tax Deductions', 'Cash Flow'],
    badgeSymbol: r'$-',
    badgeIcon: Icons.receipt_long_rounded,
    backgroundColor: AppTheme.primary,
    onComplete: () => Navigator.of(context).pushReplacementNamed('/home'),
  );
}
