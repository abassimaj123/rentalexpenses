import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../models/expense_model.dart';
import '../models/property_model.dart';
import '../services/property_database_service.dart';
import 'expense_entry_screen.dart';
import 'expense_history_screen.dart';
import 'tenants_screen.dart';

class PropertyDetailScreen extends StatefulWidget {
  final Property property;

  const PropertyDetailScreen({super.key, required this.property});

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen> {
  // AmountFormatter replaces NumberFormat _fmt
  late Property _property;
  List<MonthlyExpense> _expenses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _property = widget.property;
    AnalyticsService.instance.logScreenView('property_detail');
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await PropertyDatabaseService.instance
        .getExpensesForProperty(_property.id);
    if (mounted)
      setState(() {
        _expenses = list;
        _loading = false;
      });
  }

  Future<void> _editProperty(bool isSpanish) async {
    await _showPropertyDialog(context, isSpanish, existing: _property);
  }

  Future<void> _showPropertyDialog(BuildContext ctx, bool isSpanish,
      {Property? existing}) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final rentCtrl = TextEditingController(
        text: existing != null && existing.monthlyRent > 0
            ? existing.monthlyRent.toStringAsFixed(2)
            : '');
    final sqftCtrl = TextEditingController(
        text: existing != null && existing.squareFootage > 0
            ? existing.squareFootage.toStringAsFixed(0)
            : '');

    await showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(s.editProperty),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: s.propertyName),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: addrCtrl,
                decoration: InputDecoration(labelText: s.address),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: rentCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: s.monthlyRent,
                    prefixText: '\$'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: sqftCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: s.squareFootageOptional),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = _property.copyWith(
                name: nameCtrl.text.trim().isEmpty
                    ? _property.name
                    : nameCtrl.text.trim(),
                address: addrCtrl.text.trim(),
                monthlyRent:
                    double.tryParse(rentCtrl.text) ?? _property.monthlyRent,
                squareFootage:
                    double.tryParse(sqftCtrl.text) ?? _property.squareFootage,
              );
              await PropertyDatabaseService.instance.updateProperty(updated);
              if (mounted) setState(() => _property = updated);
              if (d.mounted) Navigator.pop(d);
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: Text(s.save),
          ),
        ],
      ),
    );
  }

  Future<void> _addExpenses(bool isSpanish) async {
    final now = DateTime.now();
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ExpenseEntryScreen(
            property: _property, targetMonth: DateTime(now.year, now.month)),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: AppDuration.base,
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openEntry(MonthlyExpense e) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ExpenseEntryScreen(
          property: _property,
          existing: e,
          targetMonth: e.date,
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: AppDuration.base,
      ),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        final isPremium = freemiumService.hasFullAccess;
        final visibleExpenses =
            isPremium ? _expenses : _expenses.take(12).toList();
        final dateFmt = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en');
        final now = DateTime.now();

        // Current month stats
        MonthlyExpense? currentMonth;
        try {
          currentMonth = _expenses.firstWhere(
            (e) => e.year == now.year && e.month == now.month,
          );
        } catch (_) {}

        final rent = _property.monthlyRent;
        final curExpenses = currentMonth?.totalExpenses ?? 0.0;
        final curCF = rent - curExpenses;
        final curRatio = rent > 0 ? (curExpenses / rent * 100) : 0.0;
        final annualCF = curCF * 12;
        final noi = (rent - (curExpenses - (currentMonth?.mortgage ?? 0))) * 12;

        return Scaffold(
          appBar: AppBar(
            title: Text(_property.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_rounded),
                tooltip: s.edit,
                onPressed: () => _editProperty(isSpanish),
              ),
              IconButton(
                icon: const Icon(Icons.history_rounded),
                tooltip: s.expenseHistory,
                onPressed: () => Navigator.of(context)
                    .push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            ExpenseHistoryScreen(property: _property),
                        transitionsBuilder: (_, anim, __, child) =>
                            FadeTransition(opacity: anim, child: child),
                        transitionDuration: AppDuration.base,
                      ),
                    )
                    .then((_) => _load()),
              ),
              IconButton(
                icon: const Icon(Icons.people_rounded),
                tooltip: s.tenants,
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                        TenantsScreen(property: _property),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: AppDuration.base,
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addExpenses(isSpanish),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: Text('${s.addExpenses} — ${dateFmt.format(DateTime(now.year, now.month))}'),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const CalcwiseLoadingState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
                        children: [
                          // Property info card
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                            AppSpacing.smPlus),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.mdPlus),
                                        ),
                                        child: const Icon(Icons.home_rounded,
                                            color: AppTheme.primary),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _property.name,
                                              style: const TextStyle(
                                                fontSize: AppTextSize.subtitle,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_property.address.isNotEmpty)
                                              Text(
                                                _property.address,
                                                style: TextStyle(
                                                  color:
                                                      CalcwiseTheme.of(context)
                                                          .textSecondary,
                                                  fontSize: AppTextSize.md,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  Divider(
                                      height: 24,
                                      color:
                                          CalcwiseTheme.of(context).cardBorder),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _InfoTile(
                                          icon: Icons.attach_money_rounded,
                                          label: s.monthlyRent,
                                          value: AmountFormatter.ui(rent, 'USD'),
                                        ),
                                      ),
                                      if (_property.squareFootage > 0)
                                        Expanded(
                                          child: _InfoTile(
                                            icon: Icons.straighten_rounded,
                                            label: s.sqFt,
                                            value:
                                                '${_property.squareFootage.toStringAsFixed(0)} ft²',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // Quick stats
                          _SectionLabel(isSpanish
                              ? 'ESTADÍSTICAS — MES ACTUAL'
                              : 'QUICK STATS — CURRENT MONTH'),
                          if (currentMonth == null)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  s.noExpensesRecorded,
                                  style: TextStyle(
                                      color: CalcwiseTheme.of(context)
                                          .textSecondary),
                                ),
                              ),
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    label: s.monthlyCashFlow,
                                    value:
                                        '${curCF < 0 ? '-' : '+'}${AmountFormatter.ui(curCF.abs(), 'USD')}',
                                    color: curCF >= 0
                                        ? AppTheme.success
                                        : CalcwiseSemanticColors.error(
                                            Theme.of(context).brightness),
                                    icon: curCF >= 0
                                        ? Icons.trending_up_rounded
                                        : Icons.trending_down_rounded,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.smPlus),
                                Expanded(
                                  child: _StatCard(
                                    label: s.expenseRatio,
                                    value: '${curRatio.toStringAsFixed(1)}%',
                                    color: curRatio < 80
                                        ? AppTheme.success
                                        : CalcwiseSemanticColors.warnIcon,
                                    icon: Icons.pie_chart_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.smPlus),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatCard(
                                    label: s.annualCF,
                                    value:
                                        '${annualCF < 0 ? '-' : '+'}${AmountFormatter.ui(annualCF.abs(), 'USD')}',
                                    color: annualCF >= 0
                                        ? AppTheme.success
                                        : CalcwiseSemanticColors.error(
                                            Theme.of(context).brightness),
                                    icon: Icons.calendar_today_rounded,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.smPlus),
                                Expanded(
                                  child: _StatCard(
                                    label: 'NOI',
                                    value:
                                        '${noi < 0 ? '-' : ''}${AmountFormatter.ui(noi.abs(), 'USD')}',
                                    color: noi >= 0
                                        ? AppTheme.success
                                        : CalcwiseSemanticColors.error(
                                            Theme.of(context).brightness),
                                    icon: Icons.account_balance_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),

                          // Recent months
                          _SectionLabel(isSpanish
                              ? 'ENTRADAS RECIENTES'
                              : 'RECENT ENTRIES'),
                          if (_expenses.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  s.noExpenseEntriesYet,
                                  style: TextStyle(
                                      color: CalcwiseTheme.of(context)
                                          .textSecondary),
                                ),
                              ),
                            )
                          else
                            ...visibleExpenses.map((e) {
                              final cf = rent - e.totalExpenses;
                              final ratio = rent > 0
                                  ? (e.totalExpenses / rent * 100)
                                  : 0.0;
                              final cfColor = cf >= 0
                                  ? AppTheme.success
                                  : CalcwiseSemanticColors.error(
                                      Theme.of(context).brightness);
                              return Card(
                                margin: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xl),
                                  onTap: () => _openEntry(e),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.mdPlus),
                                    child: Row(
                                      children: [
                                        Icon(Icons.receipt_long_rounded,
                                            color: CalcwiseTheme.of(context)
                                                .textSecondary,
                                            size: 22),
                                        const SizedBox(width: AppSpacing.md),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                dateFmt.format(e.date),
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              Text(
                                                '${AmountFormatter.ui(e.totalExpenses, 'USD')}  •  ${ratio.toStringAsFixed(1)}%',
                                                style: TextStyle(
                                                    fontSize: AppTextSize.sm,
                                                    color: CalcwiseTheme.of(
                                                            context)
                                                        .textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${cf < 0 ? '-' : '+'}${AmountFormatter.ui(cf.abs(), 'USD')}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: cfColor,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Icon(Icons.chevron_right_rounded,
                                            color: CalcwiseTheme.of(context)
                                                .textSecondary,
                                            size: 18),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
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

// ── Small widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          label,
          style: TextStyle(
              fontSize: AppTextSize.xs,
              fontWeight: FontWeight.bold,
              color: CalcwiseTheme.of(context).textSecondary,
              letterSpacing: 0.8),
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: CalcwiseTheme.of(context).textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: CalcwiseTheme.of(context).textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: AppTextSize.body, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mdPlus),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: AppTextSize.sm,
                          color: CalcwiseTheme.of(context).textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: AppTextSize.bodyLg,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
