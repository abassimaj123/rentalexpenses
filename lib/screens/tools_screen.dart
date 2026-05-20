import 'package:flutter/material.dart';
import '../main.dart' show isSpanishNotifier;
import 'tax_summary_screen.dart';
import 'compare_properties_screen.dart';
import 'settings_screen.dart';
import 'history_screen.dart';
import 'package:calcwise_core/calcwise_core.dart';

/// Tools hub screen — provides access to utility calculators and features
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (context, isSpanish, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish ? 'Herramientas' : 'Tools'),
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
                      title: isSpanish ? 'Resumen Fiscal' : 'Tax Summary',
                      subtitle: isSpanish
                          ? 'Desglose de impuestos y deducciones'
                          : 'Tax breakdown & deductions',
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
                      icon: Icons.compare_rounded,
                      title: isSpanish
                          ? 'Comparar Propiedades'
                          : 'Compare Properties',
                      subtitle: isSpanish
                          ? 'Comparar rentabilidad de propiedades'
                          : 'Compare property profitability side-by-side',
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
                      title:
                          isSpanish ? 'Historial de Gastos' : 'Expense History',
                      subtitle: isSpanish
                          ? 'Ver historial completo de transacciones'
                          : 'View full transaction history',
                      onTap: () => Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => const HistoryScreen(),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration: AppDuration.base,
                          )),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ToolCard(
                      icon: Icons.settings_rounded,
                      title: isSpanish ? 'Configuración' : 'Settings',
                      subtitle: isSpanish
                          ? 'Preferencias y configuración de la app'
                          : 'App preferences & settings',
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
