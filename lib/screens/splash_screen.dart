import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../core/theme/app_theme.dart';
import '../core/firebase/analytics_service.dart';
import '../main.dart' show MainShell, isSpanishNotifier;
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    try {
      AnalyticsService.instance.logAppOpen();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => CalcwiseSplash(
        appName: 'Rental',
        appSuffix: 'Pro',
        tagline: isSpanishNotifier.value ? 'Controla cada dólar de alquiler' : 'Track every rental dollar',
        chips: isSpanishNotifier.value
            ? const ['ROI', 'Deducciones fiscales', 'Flujo de caja']
            : const ['ROI', 'Tax Deductions', 'Cash Flow'],
        badgeSymbol: r'$-',
        badgeIcon: Icons.receipt_long_rounded,
        backgroundColor: AppTheme.primary,
        onComplete: () async {
          final done = await isOnboardingComplete('rentalexpenses');
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(PageRouteBuilder(
            pageBuilder: (_, __, ___) =>
                done ? const MainShell() : const OnboardingScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 250),
          ));
        },
      );
}
