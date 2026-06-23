import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../widgets/paywall_hard.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../services/rental_notification_service.dart';

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
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        return Scaffold(
          appBar: AppBar(
            title: Text(s.settings),
            actions: [
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.hasFullAccessNotifier,
                builder: (_, isPremium, __) {
                  if (isPremium) {
                    return const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.md),
                      child: Icon(Icons.verified_rounded,
                          color: CalcwiseSemanticColors.warnIcon, size: 22),
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.star_outline,
                        color: CalcwiseSemanticColors.warnIcon),
                    tooltip: s.goPremium,
                    onPressed: () => PaywallHard.show(context),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // ── Premium ───────────────────────────────────────
                    _SectionHeader(label: s.premiumSection),
                    ValueListenableBuilder<bool>(
                      valueListenable: freemiumService.hasFullAccessNotifier,
                      builder: (_, isPremium, __) {
                        if (isPremium) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.star_rounded,
                                  color: CalcwiseSemanticColors.warnIcon),
                              title: Text(s.premiumActive),
                              subtitle: Text(s.premiumSubtitle),
                            ),
                          );
                        }
                        return Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.star_outline_rounded,
                                    color: AppTheme.primary),
                                title: Text(s.unlockPremium),
                                subtitle: Text(s.premiumSubtitle),
                                trailing: ElevatedButton(
                                  onPressed: () => PaywallHard.show(context),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 36),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  child: Text(s.getPremium),
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
                                    : 'Restore purchase'),  // restore — no key in AppStrings
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
                                    : 'Ad-free for 60 min'),  // no key in AppStrings
                                subtitle: Text(isSpanish
                                    ? 'Ver un anuncio para desbloquear'
                                    : 'Watch an ad to unlock'),  // no key in AppStrings
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
                    const SizedBox(height: AppSpacing.xl),

                    // ── Language ──────────────────────────────────────
                    _SectionHeader(label: s.language),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.language_rounded,
                                color: AppTheme.primary),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                s.language,
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
                    _SectionHeader(label: isSpanish ? 'Tema' : 'Theme'),  // no key in AppStrings
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
                    const SizedBox(height: AppSpacing.xl),

                    // ── Notifications ─────────────────────────────────
                    _SectionHeader(label: s.notifications),
                    Card(
                      child: _ReminderTile(isSpanish: isSpanish),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Support ───────────────────────────────────────
                    _SectionHeader(label: s.support),
                    Card(
                      child: Column(
                        children: [
                          CalcwiseRateAppTile(label: s.rateApp),
                          Divider(
                              height: 1,
                              color: CalcwiseTheme.of(context).cardBorder),
                          ListTile(
                            leading: const Icon(Icons.email_rounded,
                                color: AppTheme.primary),
                            title: Text(isSpanish
                                ? 'Contactar soporte'
                                : 'Contact Support'),  // no key in AppStrings
                            trailing: Icon(Icons.open_in_new_rounded,
                                size: 18,
                                color: CalcwiseTheme.of(context).textSecondary),
                            onTap: () =>
                                _launchUrl('mailto:support@calqwise.com'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Legal ─────────────────────────────────────────
                    _SectionHeader(label: isSpanish ? 'Legal' : 'Legal'),  // same in both languages
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.privacy_tip_rounded,
                            color: AppTheme.primary),
                        title: Text(s.privacyPolicy),
                        trailing: Icon(Icons.open_in_new_rounded,
                            size: 18,
                            color: CalcwiseTheme.of(context).textSecondary),
                        onTap: () => _launchUrl('https://calqwise.com/privacy'),
                      ),
                    ),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: const Icon(Icons.manage_search_rounded,
                            color: AppTheme.primary),
                        title: Text(isSpanish
                            ? 'Configuración de privacidad'
                            : 'Privacy Settings'),
                        onTap: showCalcwisePrivacyOptions,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

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
                    const SizedBox(height: AppSpacing.xl),

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
                    const SizedBox(height: AppSpacing.xxl),

                    // ── Disclaimer ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xs, 0, AppSpacing.xs, 0),
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
                    const SizedBox(height: AppSpacing.lg),

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
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
                const CalcwiseAdFooter(),
              ],
            ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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

class _ReminderTile extends StatefulWidget {
  final bool isSpanish;
  const _ReminderTile({required this.isSpanish});

  @override
  State<_ReminderTile> createState() => _ReminderTileState();
}

class _ReminderTileState extends State<_ReminderTile> {
  static const _prefKey = 'rental_reminder_enabled';
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _enabled = prefs.getBool(_prefKey) ?? true);
    }
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      await RentalNotificationService.scheduleMonthlyReminder(
          widget.isSpanish);
    } else {
      await RentalNotificationService.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.isSpanish ? const AppStringsEs() : const AppStringsEn();
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_rounded, color: AppTheme.primary),
      title: Text(
        s.monthlyReminder,
        style: const TextStyle(fontSize: AppTextSize.body),
      ),
      subtitle: Text(
        s.monthlyReminderSubtitle,
        style: TextStyle(
            fontSize: AppTextSize.xs,
            color: CalcwiseTheme.of(context).textSecondary),
      ),
      value: _enabled,
      onChanged: _toggle,
      activeColor: AppTheme.primary,
    );
  }
}
