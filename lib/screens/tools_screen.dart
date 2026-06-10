import 'package:flutter/material.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart' show isSpanishNotifier;
import 'tax_summary_screen.dart';
import 'compare_properties_screen.dart';
import 'depreciation_screen.dart';
import 'mileage_log_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'package:calcwise_core/calcwise_core.dart'
    show CalcwiseAdFooter, AppDuration, AppSpacing, AppRadius, AppTextSize;

/// Tools hub screen — provides access to utility calculators and features
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (context, isSpanish, _) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        return Scaffold(
          appBar: AppBar(
            title: Text(s.tools),
            elevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    _ToolCard(
                      icon: Icons.receipt_rounded,
                      title: s.taxSummaryTool,
                      subtitle: s.taxSummaryToolSubtitle,
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                const TaxSummaryScreen(),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: AppDuration.base,
                          )),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ToolCard(
                      icon: Icons.trending_down_rounded,
                      title: s.depreciationTool,
                      subtitle: s.depreciationToolSubtitle,
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                const DepreciationScreen(),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: AppDuration.base,
                          )),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ToolCard(
                      icon: Icons.directions_car_rounded,
                      title: s.mileageLogTool,
                      subtitle: s.mileageLogToolSubtitle,
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                const MileageLogScreen(),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: AppDuration.base,
                          )),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ToolCard(
                      icon: Icons.compare_rounded,
                      title: s.comparePropertiesTool,
                      subtitle: s.comparePropertiesToolSubtitle,
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) =>
                                const ComparePropertiesScreen(),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: AppDuration.base,
                          )),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ToolCard(
                      icon: Icons.history_rounded,
                      title: s.expenseHistoryTool,
                      subtitle: s.expenseHistoryToolSubtitle,
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const HistoryScreen(showAppBar: true),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: AppDuration.base,
                          )),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ToolCard(
                      icon: Icons.settings_rounded,
                      title: s.settingsTool,
                      subtitle: s.settingsToolSubtitle,
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const SettingsScreen(),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: AppDuration.base,
                          )),
                    ),
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

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: ListTile(
        leading: Icon(icon, size: 28),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: AppTextSize.body)),
        subtitle: Text(subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: AppTextSize.sm)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      ),
    );
  }
}
