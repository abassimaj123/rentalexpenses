import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../screens/calculator_screen.dart';
import '../screens/history_detail_screen.dart';
import '../widgets/paywall_hard.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.showAppBar = false});
  final bool showAppBar;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ExpenseCalc> _entries = [];
  List<HistoryEntry> _otherEntries = [];
  bool _loading = true;

  final _dateFmt = DateFormat('MMM d, yyyy', 'en');
  final _dateFmtEs = DateFormat('d MMM yyyy', 'es');
  // AmountFormatter replaces NumberFormat _mFmt

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('history');
    historyRefreshNotifier.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    historyRefreshNotifier.removeListener(_reload);
    super.dispose();
  }

  void _reload() => _load();

  Future<void> _load() async {
    final entries = await loadHistory();
    final smartEntries = await smartHistoryService.getHistory('rentalexpenses');
    final other = smartEntries.where((e) => e.screenId != 'expenses').toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    if (mounted)
      setState(() {
        _entries = entries;
        _otherEntries = other;
        _loading = false;
      });
  }

  Future<void> _deleteOther(HistoryEntry entry) async {
    HapticFeedback.mediumImpact();
    if (entry.id != null) await smartHistoryService.delete(entry.id!);
    if (!mounted) return;
    await _load();
  }

  String _otherEntryTitle(String screenId, AppStrings s) {
    switch (screenId) {
      case 'depreciation':
        return s.depreciationEntryTitle;
      case 'mileage_log':
        return s.mileageEntryTitle;
      case 'income':
        return s.incomeEntryTitle;
      case 'tax_summary':
        return s.taxSummaryEntryTitle;
      case 'roi':
        return s.compareEntryTitle;
      default:
        return screenId;
    }
  }

  String _otherEntrySubtitle(HistoryEntry e) {
    final l1 = e.l1;
    switch (e.screenId) {
      case 'depreciation':
        return AmountFormatter.ui((l1['annual_depreciation'] as num?)?.toDouble() ?? 0, 'USD');
      case 'mileage_log':
        return AmountFormatter.ui((l1['deduction'] as num?)?.toDouble() ?? 0, 'USD');
      case 'income':
        return AmountFormatter.ui((l1['net_profit'] as num?)?.toDouble() ?? 0, 'USD');
      case 'tax_summary':
        return AmountFormatter.ui((l1['taxable_income'] as num?)?.toDouble() ?? 0, 'USD');
      case 'roi':
        return (l1['winner'] as String?) ?? '';
      default:
        return '';
    }
  }

  // Fields that are counts/dates, not currency amounts — must not be $-formatted.
  static const _nonCurrencyFields = {
    'in_service_month', 'in_service_year', 'year', 'month', 'property_count',
    'trip_count', 'property_id',
  };

  void _openOtherDetail(HistoryEntry entry, bool isSpanish) {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final inputs = (entry.l2['inputs'] as Map?) ?? {};
    final results = (entry.l2['results'] as Map?) ?? {};
    final rows = <MapEntry<String, dynamic>>[
      ...inputs.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      ...results.entries.map((e) => MapEntry(e.key.toString(), e.value)),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(entry.pinLabel ?? _otherEntryTitle(entry.screenId, s)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: rows.map((r) {
              final value = r.value;
              final display = (value is num && !_nonCurrencyFields.contains(r.key))
                  ? AmountFormatter.ui(value.toDouble(), 'USD')
                  : value.toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.key.replaceAll('_', ' '),
                        style: TextStyle(color: CalcwiseTheme.of(context).textSecondary)),
                    Text(display, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(int index, bool isSpanish) async {
    HapticFeedback.mediumImpact();
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('expense_history_v1') ?? [];
    if (index < raw.length) raw.removeAt(index);
    await prefs.setStringList('expense_history_v1', raw);
    if (!mounted) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.entryDeleted),
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
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        final bodyContent = Column(
          children: [
            Expanded(
              child: _loading
                  ? const CalcwiseLoadingState(showHeroCard: false)
                  : (_entries.isEmpty && _otherEntries.isEmpty)
                      ? _EmptyState(isSpanish: isSpanish)
                      : _buildList(isSpanish),
            ),
            const CalcwiseAdFooter(),
          ],
        );
        return widget.showAppBar
            ? Scaffold(
                appBar: AppBar(
                  title: Text(s.historyTitle),
                  actions: [
                    if (_entries.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded),
                        tooltip: s.clearHistory,
                        onPressed: () => _confirmClearAll(isSpanish),
                      ),
                  ],
                ),
                body: CalcwisePageEntrance(child: bodyContent),
              )
            : bodyContent;
      },
    );
  }

  Widget _buildList(bool isSpanish) {
    return ValueListenableBuilder<bool>(
      valueListenable: freemiumService.hasFullAccessNotifier,
      builder: (_, isPremium, __) {
        final limit = MonetizationConfig.freeCalculationLimit;
        final ctaCount = isPremium ? 0 : 1;
        final otherHeaderCount = _otherEntries.isEmpty ? 0 : 1;
        final mainCount = _entries.length + ctaCount;
        final totalCount = mainCount + otherHeaderCount + _otherEntries.length;
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: totalCount,
          itemBuilder: (_, i) {
            // Free upgrade CTA at bottom of the main list
            if (!isPremium && i == _entries.length) {
              return _UpgradeCTA(isSpanish: isSpanish, limit: limit);
            }
            // "Other saved scenarios" section (Depreciation/Mileage/Reports/Tax/Compare)
            if (i >= mainCount) {
              final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
              final otherIndex = i - mainCount - otherHeaderCount;
              if (otherIndex < 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                  child: Text(
                    s.otherSavedScenarios.toUpperCase(),
                    style: TextStyle(
                        fontSize: AppTextSize.sm,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: CalcwiseTheme.of(context).textSecondary),
                  ),
                );
              }
              final entry = _otherEntries[otherIndex];
              return Dismissible(
                key: ValueKey('smart_${entry.id}_${entry.screenId}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Icon(Icons.delete_rounded, color: AppTheme.dangerRed),
                ),
                onDismissed: (_) => _deleteOther(entry),
                child: Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg, vertical: AppSpacing.smPlus),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(Icons.insert_chart_outlined_rounded,
                          color: AppTheme.primary, size: 22),
                    ),
                    title: Text(
                      entry.pinLabel ?? _otherEntryTitle(entry.screenId, s),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: AppTextSize.bodyMd),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xxs),
                        Text(_otherEntrySubtitle(entry),
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Text(
                          (isSpanish ? _dateFmtEs : _dateFmt).format(entry.savedAt),
                          style: TextStyle(
                              fontSize: AppTextSize.sm,
                              color: CalcwiseTheme.of(context).textSecondary),
                        ),
                      ],
                    ),
                    onTap: () => _openOtherDetail(entry, isSpanish),
                  ),
                ),
              );
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
                  subtitle: Builder(builder: (context) {
                    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${s.monthlyCFLabel}: ${cf < 0 ? '-' : ''}${AmountFormatter.ui(cf.abs(), 'USD')}',
                          style: TextStyle(
                              color: cfColor, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          (isSpanish ? _dateFmtEs : _dateFmt).format(e.savedAt),
                          style: TextStyle(
                              fontSize: AppTextSize.sm,
                              color: CalcwiseTheme.of(context).textSecondary),
                        ),
                      ],
                    );
                  }),
                  trailing: Builder(builder: (context) {
                    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
                    return IconButton(
                      icon: const Icon(Icons.replay_rounded,
                          color: AppTheme.primary, size: 20),
                      tooltip: s.loadInCalculator,
                      onPressed: () => _loadIntoCalculator(e),
                    );
                  }),
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
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.clearHistory),
        content: Text(s.clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.clear,
                style: const TextStyle(color: AppTheme.dangerRed)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('expense_history_v1');
      if (!mounted) return;
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
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 72, color: AppTheme.primary.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.noSavedHistory,
              style: const TextStyle(
                  fontSize: AppTextSize.subtitle, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.noSavedHistorySubtitle,
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
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
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
              s.savedNOfNFreeProperties(limit),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: AppTextSize.body),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              s.unlockForUnlimitedHistory,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: CalcwiseTheme.of(context).textSecondary,
                  fontSize: AppTextSize.md),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => PaywallHard.show(context, isSpanish: isSpanishNotifier.value),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
                child: Text(s.unlockPremium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
