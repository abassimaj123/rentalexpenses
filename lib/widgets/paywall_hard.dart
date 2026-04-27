import 'package:flutter/material.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/ads/ad_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';

class PaywallHard extends StatelessWidget {
  const PaywallHard({super.key});

  static Future<void> show(BuildContext context) {
    AnalyticsService.instance.logPaywallShown(type: 'hard');
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PaywallHard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final title = isSpanish
            ? 'Desbloquea el seguimiento completo de gastos'
            : 'Unlock complete expense tracking';
        final sub = isSpanish
            ? 'Premium revela exactamente cuánto ganas en cada propiedad'
            : 'Premium shows exactly how much you profit from each property';
        final features = isSpanish
            ? [
                '🏠 Guarda propiedades ilimitadas',
                '📉 Desglose detallado de gastos mensuales',
                '📊 Historial ilimitado y flujo de caja',
                '🚫 Sin anuncios — nunca',
              ]
            : [
                '🏠 Save unlimited rental properties',
                '📉 Detailed monthly expense breakdown',
                '📊 Unlimited history & cash flow tracking',
                '🚫 Zero ads — ever',
              ];
        const price = r'$2.99';
        const savings = r'(know your true profit)';
        const savingsEs = r'(conoce tu ganancia real)';
        final btnPrimary = isSpanish
            ? 'Empezar ahora\n$price $savingsEs'
            : 'Start tracking now\n$price $savings';
        final btnReward =
            isSpanish ? 'Ver anuncio (60 min gratis)' : 'Watch ad (60 min free)';
        final btnSecondary = isSpanish ? 'Más tarde' : 'Maybe later';

        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      color: Colors.orange, size: 32),
                ),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
                const SizedBox(height: 6),
                Text(sub,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.labelGray)),
                const SizedBox(height: 18),
                ...features.map((f) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        const SizedBox(width: 8),
                        Expanded(
                            child:
                                Text(f, style: const TextStyle(fontSize: 14))),
                      ]),
                    )),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      IAPService.instance.buy();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(btnPrimary,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, height: 1.4)),
                  ),
                ),
                const SizedBox(height: 8),
                if (AdService.instance.isRewardedReady)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        AdService.instance.showRewarded().then((earned) {
                          if (earned) freemiumService.activateRewarded();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        side: const BorderSide(color: AppTheme.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child:
                          Text(btnReward, style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    AnalyticsService.instance.logPaywallDismissed();
                    Navigator.pop(context);
                  },
                  child: Text(btnSecondary,
                      style: const TextStyle(
                          color: AppTheme.labelGray, fontSize: 13)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
