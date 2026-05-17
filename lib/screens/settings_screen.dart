import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _setLanguage(bool isSpanish) async {
    isSpanishNotifier.value = isSpanish;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', isSpanish ? 'es' : 'en');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish ? 'Configuración' : 'Settings'),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.isPremiumNotifier,
                builder: (_, isPremium, __) {
                  if (isPremium) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.verified_rounded,
                          color: Colors.amber, size: 22),
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.star_outline, color: Colors.amber),
                    tooltip: isSpanish ? 'Obtener Premium' : 'Go Premium',
                    onPressed: () => IAPService.instance.buy(),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // ── Language ──────────────────────────────────────
                    _SectionHeader(label: isSpanish ? 'Idioma' : 'Language'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.language_rounded,
                                color: AppTheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isSpanish
                                    ? 'Idioma actual'
                                    : 'Current language',
                                style: const TextStyle(
                                    fontSize: AppTextSize.bodyMd),
                              ),
                            ),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('EN')),
                                ButtonSegment(value: true, label: Text('ES')),
                              ],
                              selected: {isSpanish},
                              onSelectionChanged: (s) => _setLanguage(s.first),
                              style: ButtonStyle(
                                backgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppTheme.primary;
                                  }
                                  return null;
                                }),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return null;
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── Theme ────────────────────────────────────────
                    _SectionHeader(label: isSpanish ? 'Tema' : 'Theme'),
                    Card(
                      child: ValueListenableBuilder<ThemeMode>(
                        valueListenable: themeModeService.notifier,
                        builder: (_, mode, __) => ListTile(
                          leading: Icon(themeModeService.icon,
                              color: AppTheme.primary),
                          title: Text(
                              themeModeService.label(isSpanish: isSpanish)),
                          trailing: Icon(Icons.chevron_right_rounded,
                              size: 18,
                              color: CalcwiseTheme.of(context).textSecondary),
                          onTap: () => themeModeService.toggle(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Premium ───────────────────────────────────────
                    _SectionHeader(label: isSpanish ? 'Premium' : 'Premium'),
                    ValueListenableBuilder<bool>(
                      valueListenable: freemiumService.isPremiumNotifier,
                      builder: (_, isPremium, __) {
                        if (isPremium) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.star_rounded,
                                  color: Colors.amber),
                              title: Text(isSpanish
                                  ? '¡Eres Premium!'
                                  : 'You\'re Premium!'),
                              subtitle: Text(isSpanish
                                  ? 'Gracias por tu apoyo'
                                  : 'Thank you for your support'),
                            ),
                          );
                        }
                        return Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.star_outline_rounded,
                                    color: AppTheme.primary),
                                title: Text(isSpanish
                                    ? 'Desbloquear Premium'
                                    : 'Unlock Premium'),
                                subtitle: Text(isSpanish
                                    ? 'Acceso completo — \$2.99'
                                    : 'Full access — \$2.99'),
                                trailing: ElevatedButton(
                                  onPressed: () => IAPService.instance.buy(),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 36),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  child: Text(isSpanish ? 'Comprar' : 'Buy'),
                                ),
                              ),
                              Divider(
                                  height: 1,
                                  color: CalcwiseTheme.of(context).cardBorder),
                              ListTile(
                                leading: Icon(Icons.restore_rounded,
                                    color: CalcwiseTheme.of(context)
                                        .textSecondary),
                                title: Text(isSpanish
                                    ? 'Restaurar compra'
                                    : 'Restore purchase'),
                                onTap: () => IAPService.instance.restore(),
                              ),
                              Divider(
                                  height: 1,
                                  color: CalcwiseTheme.of(context).cardBorder),
                              ListTile(
                                leading: const Icon(Icons.play_circle_outline,
                                    color: AppTheme.primary),
                                title: Text(isSpanish
                                    ? 'Sin anuncios 60 min'
                                    : 'Ad-free for 60 min'),
                                subtitle: Text(isSpanish
                                    ? 'Ver un anuncio para desbloquear'
                                    : 'Watch an ad to unlock'),
                                onTap: () async {
                                  final earned = await adService.showRewarded();
                                  if (earned)
                                    freemiumService.activateRewarded();
                                  if (!earned && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isSpanish
                                            ? 'Anuncio no disponible'
                                            : 'Ad not available'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Support ───────────────────────────────────────
                    _SectionHeader(label: isSpanish ? 'Soporte' : 'Support'),
                    Card(
                      child: Column(
                        children: [
                          CalcwiseRateAppTile(
                              label: isSpanish
                                  ? 'Calificar la app'
                                  : 'Rate the App'),
                          Divider(
                              height: 1,
                              color: CalcwiseTheme.of(context).cardBorder),
                          ListTile(
                            leading: const Icon(Icons.email_rounded,
                                color: AppTheme.primary),
                            title: Text(isSpanish
                                ? 'Contactar soporte'
                                : 'Contact Support'),
                            trailing: Icon(Icons.open_in_new_rounded,
                                size: 18,
                                color: CalcwiseTheme.of(context).textSecondary),
                            onTap: () =>
                                _launchUrl('mailto:support@calqwise.com'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Legal ─────────────────────────────────────────
                    _SectionHeader(label: isSpanish ? 'Legal' : 'Legal'),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.privacy_tip_rounded,
                            color: AppTheme.primary),
                        title: Text(isSpanish
                            ? 'Política de privacidad'
                            : 'Privacy Policy'),
                        trailing: Icon(Icons.open_in_new_rounded,
                            size: 18,
                            color: CalcwiseTheme.of(context).textSecondary),
                        onTap: () => _launchUrl('https://calqwise.com/privacy'),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Privacy ───────────────────────────────────────
                    _SectionHeader(label: isSpanish ? 'Privacidad' : 'Privacy'),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.shield_rounded,
                            color: AppTheme.primary),
                        title: Text(isSpanish
                            ? 'Tus datos permanecen en tu dispositivo'
                            : 'Your data stays on your device'),
                        subtitle: Text(isSpanish
                            ? 'Sin cuenta. Sin sincronización en la nube. 100% offline.'
                            : 'No account. No cloud sync. 100% offline.'),
                        dense: false,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Discover CalqWise ──────────────────────────────
                    _SectionHeader(
                        label: isSpanish
                            ? 'Descubre CalqWise'
                            : 'Discover CalqWise'),
                    Card(
                      child: Column(
                        children: [
                          _AppTile(
                            icon: Icons.home_work_rounded,
                            title: isSpanish
                                ? 'Calculadora de asequibilidad CA'
                                : 'Affordability Calculator CA',
                            onTap: () => _launchUrl(
                                'https://play.google.com/store/apps/details?id=com.affordabilityca.calculator'),
                          ),
                          Divider(
                              height: 1,
                              color: CalcwiseTheme.of(context).cardBorder),
                          _AppTile(
                            icon: Icons.attach_money_rounded,
                            title: isSpanish
                                ? 'Calculadora de asequibilidad US'
                                : 'Affordability Calculator US',
                            onTap: () => _launchUrl(
                                'https://play.google.com/store/apps/details?id=com.affordabilityus.calculator'),
                          ),
                          Divider(
                              height: 1,
                              color: CalcwiseTheme.of(context).cardBorder),
                          _AppTile(
                            icon: Icons.trending_up_rounded,
                            title: isSpanish
                                ? 'ROI de propiedad de alquiler'
                                : 'Rental Property ROI',
                            onTap: () => _launchUrl(
                                'https://play.google.com/store/apps/details?id=com.rentalroi.us.calculator'),
                          ),
                          Divider(
                              height: 1,
                              color: CalcwiseTheme.of(context).cardBorder),
                          _AppTile(
                            icon: Icons.school_rounded,
                            title: isSpanish
                                ? 'Préstamos estudiantiles'
                                : 'Student Loan Calculator',
                            onTap: () => _launchUrl(
                                'https://play.google.com/store/apps/details?id=com.studentloan.calculator'),
                          ),
                          Divider(
                              height: 1,
                              color: CalcwiseTheme.of(context).cardBorder),
                          _AppTile(
                            icon: Icons.grid_view_rounded,
                            title: isSpanish
                                ? 'Más apps de CalqWise'
                                : 'More apps by CalqWise',
                            onTap: () => _launchUrl(
                                'https://play.google.com/store/apps/developer?id=CalqWise'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Disclaimer ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                      child: Text(
                        isSpanish
                            ? 'Solo con fines informativos. No es asesoramiento financiero. Consulte a un profesional antes de tomar decisiones financieras.'
                            : 'For informational purposes only. Not financial advice. Consult a qualified advisor before making financial decisions.',
                        style: TextStyle(
                          fontSize: AppTextSize.xs,
                          fontStyle: FontStyle.italic,
                          color: CalcwiseTheme.of(context).textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── App version ────────────────────────────────────
                    Center(
                      child: Text(
                        'Rental Expenses Tracker v1.0.0\n© 2026 CalqWise',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: AppTextSize.sm,
                            color: CalcwiseTheme.of(context).textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              const CalcwiseAdFooter(),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: TextStyle(
              fontSize: AppTextSize.md,
              fontWeight: FontWeight.bold,
              color: CalcwiseTheme.of(context).textSecondary,
              letterSpacing: 0.5)),
    );
  }
}

class _AppTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _AppTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(title, style: const TextStyle(fontSize: AppTextSize.body)),
      trailing: Icon(Icons.chevron_right_rounded,
          color: CalcwiseTheme.of(context).textSecondary),
      onTap: onTap,
    );
  }
}
