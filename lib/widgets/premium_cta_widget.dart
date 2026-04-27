import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';

class PremiumCtaWidget extends StatelessWidget {
  final String feature;
  const PremiumCtaWidget({super.key, required this.feature});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.lock_outline, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSpanish
                    ? 'Desbloquea $feature con Premium'
                    : 'Unlock $feature with Premium',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
          ]),
        );
      },
    );
  }
}
