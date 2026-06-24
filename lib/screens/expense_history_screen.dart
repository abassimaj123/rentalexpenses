import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../models/expense_model.dart';
import '../models/property_model.dart';
import '../screens/receipt_viewer_screen.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';
import 'expense_entry_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  final Property property;

  const ExpenseHistoryScreen({super.key, required this.property});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  // AmountFormatter replaces NumberFormat _fmt
  List<MonthlyExpense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('expense_history');
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await PropertyDatabaseService.instance
        .getExpensesForProperty(widget.property.id);
    if (mounted)
      setState(() {
        _expenses = list;
        _loading = false;
      });
  }

  Future<void> _delete(MonthlyExpense e, bool isSpanish) async {
    HapticFeedback.mediumImpact();
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    await PropertyDatabaseService.instance.deleteExpense(e.id);
    if (mounted) {
      setState(() => _expenses.removeWhere((x) => x.id == e.id));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.entryDeleted),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _openEntry(MonthlyExpense e) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ExpenseEntryScreen(
          property: widget.property,
          existing: e,
          targetMonth: e.date,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: AppDuration.base,
      ),
    );
    if (!mounted) return;
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        final isPremium = freemiumService.hasFullAccess;
        final freeLimit = MonetizationConfig.freeCalculationLimit;
        final dateFmt = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en');

        return Scaffold(
          appBar: AppBar(
            title: Text(s.expenseHistory),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
          body: CalcwisePageEntrance(
            child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const CalcwiseLoadingState(showHeroCard: false)
                    : _expenses.isEmpty
                        ? _EmptyState(isSpanish: isSpanish)
                        : ListView.builder(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: _expenses.length,
                            itemBuilder: (ctx, i) {
                              final e = _expenses[i];
                              final rent = widget.property.monthlyRent;
                              final cf = rent - e.totalExpenses;
                              final ratio = rent > 0
                                  ? (e.totalExpenses / rent * 100)
                                  : 0.0;
                              final cfColor = cf >= 0
                                  ? AppTheme.success
                                  : AppTheme.dangerRed;

                              // Free users: blur entries beyond freeLimit
                              final isLocked = !isPremium && i >= freeLimit;

                              if (isLocked) {
                                return _LockedRow(
                                  isSpanish: isSpanish,
                                  onUnlock: () => PaywallHard.show(context),
                                );
                              }

                              return Dismissible(
                                key: ValueKey(e.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(
                                      right: AppSpacing.xl),
                                  decoration: BoxDecoration(
                                    color: AppTheme.dangerRed
                                        .withValues(alpha: 0.12),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xl),
                                  ),
                                  child: const Icon(Icons.delete_rounded,
                                      color: AppTheme.dangerRed),
                                ),
                                confirmDismiss: (_) async {
                                  return await showDialog<bool>(
                                        context: ctx,
                                        builder: (d) => AlertDialog(
                                          title: Text(s.deleteEntry),
                                          content: Text(s.deleteEntryConfirm(dateFmt.format(e.date))),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, false),
                                              child: Text(s.cancel),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(d, true),
                                              child: Text(
                                                  s.delete,
                                                  style: const TextStyle(
                                                      color:
                                                          AppTheme.dangerRed)),
                                            ),
                                          ],
                                        ),
                                      ) ??
                                      false;
                                },
                                onDismissed: (_) => _delete(e, isSpanish),
                                child: Card(
                                  margin: const EdgeInsets.only(
                                      bottom: AppSpacing.smPlus),
                                  child: InkWell(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xl),
                                    onTap: () => _openEntry(e),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.lg),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: cfColor.withValues(
                                                  alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.mdPlus),
                                            ),
                                            child: Icon(
                                              cf >= 0
                                                  ? Icons.trending_up_rounded
                                                  : Icons.trending_down_rounded,
                                              color: cfColor,
                                            ),
                                          ),
                                          const SizedBox(
                                              width: AppSpacing.mdPlus),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  dateFmt.format(e.date),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize:
                                                        AppTextSize.bodyMd,
                                                  ),
                                                ),
                                                const SizedBox(
                                                    height: AppSpacing.xs),
                                                Text(
                                                  '${s.expensesLabel}: ${AmountFormatter.ui(e.totalExpenses, 'USD')}  •  ${ratio.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    fontSize: AppTextSize.md,
                                                    color: CalcwiseTheme.of(
                                                            context)
                                                        .textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Receipt icon badge
                                          if (e.receiptPath != null) ...[
                                            const SizedBox(
                                                width: AppSpacing.sm),
                                            Semantics(
                                              label: 'View receipt',
                                              button: true,
                                              child: InkWell(
                                              onTap: () {
                                                Navigator.of(ctx).push(
                                                  PageRouteBuilder(
                                                    pageBuilder: (_, __, ___) =>
                                                        ReceiptViewerScreen(
                                                      imagePath: e.receiptPath!,
                                                    ),
                                                    transitionsBuilder:
                                                        (_, anim, __, child) =>
                                                            FadeTransition(
                                                                opacity: anim,
                                                                child: child),
                                                    transitionDuration:
                                                        AppDuration.base,
                                                  ),
                                                );
                                              },
                                              borderRadius: BorderRadius.circular(AppRadius.md),
                                              child: Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.success
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppRadius.md),
                                                ),
                                                child: const Icon(
                                                  Icons.check_circle_rounded,
                                                  color: AppTheme.success,
                                                  size: 18,
                                                ),
                                              ),
                                            ),
                                            ),
                                            const SizedBox(
                                                width: AppSpacing.sm),
                                          ],
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${cf < 0 ? '-' : '+'}${AmountFormatter.ui(cf.abs(), 'USD')}',
                                                style: TextStyle(
                                                  fontSize: AppTextSize.bodyMd,
                                                  fontWeight: FontWeight.bold,
                                                  color: cfColor,
                                                ),
                                              ),
                                              const SizedBox(
                                                  height: AppSpacing.xxs),
                                              Text(
                                                s.monthlyCFShort,
                                                style: TextStyle(
                                                  fontSize: AppTextSize.xs,
                                                  color:
                                                      CalcwiseTheme.of(context)
                                                          .textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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
            Icon(Icons.receipt_long_rounded,
                size: 72,
                color: CalcwiseTheme.of(context)
                    .textSecondary
                    .withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.noExpenseEntriesYet,
              style: const TextStyle(
                  fontSize: AppTextSize.subtitle, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.noExpenseEntriesSubtitle,
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  final bool isSpanish;
  final VoidCallback onUnlock;
  const _LockedRow({required this.isSpanish, required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.smPlus),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onUnlock,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: CalcwiseTheme.of(context)
                      .textSecondary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.mdPlus),
                ),
                child: Icon(Icons.lock_rounded,
                    color: CalcwiseTheme.of(context).textSecondary),
              ),
              const SizedBox(width: AppSpacing.mdPlus),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 14,
                        width: 120,
                        color: CalcwiseTheme.of(context).cardBorder),
                    const SizedBox(height: 6),
                    Container(
                        height: 12,
                        width: 180,
                        color: CalcwiseTheme.of(context).cardBorder),
                  ],
                ),
              ),
              Text(
                isSpanish ? 'Premium' : 'Premium',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: AppTextSize.md,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
