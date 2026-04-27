import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work_rounded, size: 72, color: Colors.white),
            const SizedBox(height: 20),
            const Text('Rental Expenses',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            ValueListenableBuilder<bool>(
              valueListenable: isSpanishNotifier,
              builder: (_, isEs, __) => Text(
                isEs ? 'Sin cuenta. Sin nube.' : 'No account. No cloud.',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
