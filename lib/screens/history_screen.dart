import '../core/ads/ad_footer.dart';
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
  final _mFmt    = NumberFormat('#,##0.00', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await loadHistory();
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  Future<void> _delete(int index, bool isSpanish) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getStringList('expense_history_v1') ?? [];
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
    Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (_, __, ___) => Scaffold(
        body: CalculatorScreen(preload: calc)),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 250),
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
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? _EmptyState(isSpanish: isSpanish)
                        : _buildList(isSpanish),
              ),
              const AdFooter(),
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
          padding: const EdgeInsets.all(16),
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
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: AppTheme.dangerRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_rounded,
                    color: AppTheme.dangerRed),
              ),
              onDismissed: (_) => _delete(i, isSpanish),
              child: Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cfColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
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
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
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
                            fontSize: 12, color: CalcwiseTheme.of(context).textSecondary),
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
                    transitionDuration: const Duration(milliseconds: 250),
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

// ── Widgets ───────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSpanish;
  const _EmptyState({required this.isSpanish});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 72, color: AppTheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              isSpanish ? 'Sin historial guardado' : 'No saved history',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isSpanish
                  ? 'Calcula los gastos de una propiedad y guarda el resultado.'
                  : 'Calculate expenses for a property and save the result.',
              textAlign: TextAlign.center,
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCTA extends StatelessWidget {
  final bool isSpanish;
  final int limit;
  const _UpgradeCTA({required this.isSpanish, required this.limit});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.primary.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: AppTheme.primary.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.lock_open_rounded,
                color: AppTheme.primary.withValues(alpha: 0.6), size: 32),
            const SizedBox(height: 8),
            Text(
              isSpanish
                  ? 'Guardaste $limit de $limit propiedades gratis'
                  : 'You\'ve saved $limit of $limit free properties',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              isSpanish
                  ? 'Desbloquea Premium para historial ilimitado'
                  : 'Unlock Premium for unlimited history',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CalcwiseTheme.of(context).textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => PaywallHard.show(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(
                  isSpanish ? 'Desbloquear — \$2.99' : 'Unlock Premium — \$2.99',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
