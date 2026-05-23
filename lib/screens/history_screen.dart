import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../screens/calculator_screen.dart';
import '../screens/history_detail_screen.dart';
import '../widgets/paywall_hard.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ExpenseCalc> _entries = [];
  bool _loading = true;

  final _dateFmt = DateFormat('MMM d, yyyy');
  final _mFmt = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await loadHistory();
    if (mounted)
      setState(() {
        _entries = entries;
        _loading = false;
      });
  }

  Future<void> _delete(int index, bool isSpanish) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('expense_history_v1') ?? [];
    if (index < raw.length) raw.removeAt(index);
    await prefs.setStringList('expense_history_v1', raw);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isSpanish ? 'Entrada eliminada' : 'Entry deleted'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _loadIntoCalculator(ExpenseCalc calc) {
    // Push a new calculator screen pre-loaded with this entry
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            Scaffold(body: CalculatorScreen(preload: calc)),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: AppDuration.base,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish ? 'Historial' : 'History'),
            actions: [
              if (_entries.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: isSpanish ? 'Borrar todo' : 'Clear all',
                  onPressed: () => _confirmClearAll(isSpanish),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const _HistorySkeleton()
                    : _entries.isEmpty
                        ? CalcwiseEmptyState(
                            icon: Icons.history_rounded,
                            title: isSpanish
                                ? 'Sin historial guardado'
                                : 'No saved history',
                            body: isSpanish
                                ? 'Calcula los gastos de una propiedad y guarda el resultado.'
                                : 'Calculate expenses for a property and save the result.',
                          )
                        : _buildList(isSpanish),
              ),
              const CalcwiseAdFooter(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(bool isSpanish) {
    return ValueListenableBuilder<bool>(
      valueListenable: freemiumService.isPremiumNotifier,
      builder: (_, isPremium, __) {
        final limit = MonetizationConfig.freeCalculationLimit;
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: _entries.length + (isPremium ? 0 : 1),
          itemBuilder: (_, i) {
            // Free upgrade CTA at bottom
            if (!isPremium && i == _entries.length) {
              return _UpgradeCTA(isSpanish: isSpanish, limit: limit);
            }
            final e = _entries[i];
            final cf = e.monthlyCashFlow;
            final cfColor = cf >= 0 ? AppTheme.success : AppTheme.dangerRed;
            return Dismissible(
              key: ValueKey('${e.savedAt.toIso8601String()}_$i'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: AppSpacing.xl),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child:
                    const Icon(Icons.delete_rounded, color: AppTheme.dangerRed),
              ),
              onDismissed: (_) => _delete(i, isSpanish),
              child: Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.smPlus),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cfColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Icon(
                      cf >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: cfColor,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    e.propertyName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppTextSize.bodyMd),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        isSpanish
                            ? 'Flujo mensual: ${cf < 0 ? '-' : ''}\$${_mFmt.format(cf.abs())}'
                            : 'Monthly CF: ${cf < 0 ? '-' : ''}\$${_mFmt.format(cf.abs())}',
                        style: TextStyle(
                            color: cfColor, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _dateFmt.format(e.savedAt),
                        style: TextStyle(
                            fontSize: AppTextSize.sm,
                            color: CalcwiseTheme.of(context).textSecondary),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.replay_rounded,
                        color: AppTheme.primary, size: 20),
                    tooltip: isSpanish
                        ? 'Cargar en calculadora'
                        : 'Load in calculator',
                    onPressed: () => _loadIntoCalculator(e),
                  ),
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (_, __, ___) => HistoryDetailScreen(calc: e),
                      transitionsBuilder: (_, anim, __, child) =>
                          FadeTransition(opacity: anim, child: child),
                      transitionDuration: AppDuration.base,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmClearAll(bool isSpanish) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isSpanish ? '¿Borrar historial?' : 'Clear history?'),
        content: Text(isSpanish
            ? 'Se eliminarán todas las entradas guardadas.'
            : 'All saved entries will be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isSpanish ? 'Borrar' : 'Clear',
                style: const TextStyle(color: AppTheme.dangerRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('expense_history_v1');
      await _load();
    }
  }
}

// ── Skeleton shimmer ──────────────────────────────────────────────────────────

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.smPlus),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _ShimmerBox(width: 120, height: 26, radius: AppRadius.md),
                      const Spacer(),
                      _ShimmerBox(width: 70, height: 22, radius: AppRadius.sm),
                    ]),
                    const SizedBox(height: 12),
                    ...List.generate(
                      3,
                      (_) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ShimmerBox(width: 100, height: 13, radius: 4),
                            _ShimmerBox(width: 70, height: 13, radius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width, height, radius;
  const _ShimmerBox(
      {required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _UpgradeCTA extends StatelessWidget {
  final bool isSpanish;
  final int limit;
  const _UpgradeCTA({required this.isSpanish, required this.limit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: AppTheme.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Icon(Icons.lock_open_rounded,
                color: AppTheme.primary.withValues(alpha: 0.6), size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isSpanish
                  ? 'Guardaste $limit de $limit propiedades gratis'
                  : 'You\'ve saved $limit of $limit free properties',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: AppTextSize.body),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isSpanish
                  ? 'Desbloquea Premium para historial ilimitado'
                  : 'Unlock Premium for unlimited history',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CalcwiseTheme.of(context).textSecondary,
                  fontSize: AppTextSize.md),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => PaywallHard.show(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(
                  isSpanish
                      ? 'Desbloquear — \$2.99'
                      : 'Unlock Premium — \$2.99',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
