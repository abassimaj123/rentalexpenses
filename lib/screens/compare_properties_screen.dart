import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/services/pdf_export_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../models/expense_model.dart';
import '../models/property_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';
import '../widgets/paywall_soft.dart';
import '../widgets/save_scenario_button.dart';

class ComparePropertiesScreen extends StatefulWidget {
  const ComparePropertiesScreen({super.key});

  @override
  State<ComparePropertiesScreen> createState() =>
      _ComparePropertiesScreenState();
}

class _ComparePropertiesScreenState extends State<ComparePropertiesScreen> {
  // AmountFormatter replaces NumberFormat _fmt

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Property> _allProperties = [];
  final Set<String> _selectedIds = {};
  Map<String, MonthlyExpense?> _expenseMap = {};
  bool _loading = true;
  String? _currentHash;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('compare_properties');
    _loadProperties();
  }

  @override
  void dispose() {
    smartHistoryService.cancelPendingSave('rentalexpenses', 'roi');
    super.dispose();
  }

  Future<void> _loadProperties() async {
    setState(() => _loading = true);
    final props = await PropertyDatabaseService.instance.getAllProperties();
    if (mounted) {
      setState(() {
        _allProperties = props;
        if (props.length >= 2 && _selectedIds.isEmpty) {
          _selectedIds.add(props[0].id);
          _selectedIds.add(props[1].id);
        }
        _loading = false;
      });
    }
    await _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    final Map<String, MonthlyExpense?> map = {};
    for (final id in _selectedIds) {
      map[id] = await PropertyDatabaseService.instance
          .getExpenseForMonth(id, _selectedMonth.year, _selectedMonth.month);
    }
    if (mounted) {
      setState(() => _expenseMap = map);
      if (_selectedIds.length >= 2) _scheduleAutoSave();
    }
  }

  Future<void> _pickMonth(bool isSpanish) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    int pickedYear = _selectedMonth.year;
    int pickedMonth = _selectedMonth.month;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final monthsEn = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            final monthsEs = [
              'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
              'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
            ];
            final months = isSpanish ? monthsEs : monthsEn;
            return AlertDialog(
              title: Text(s.selectMonth),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        tooltip: 'Previous year',
                        onPressed: () => setLocal(() => pickedYear--),
                      ),
                      Text('$pickedYear',
                          style: const TextStyle(
                              fontSize: AppTextSize.subtitle,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        tooltip: 'Next year',
                        onPressed: () => setLocal(() => pickedYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (i) {
                      final sel = (i + 1) == pickedMonth;
                      return InkWell(
                        onTap: () => setLocal(() => pickedMonth = i + 1),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 62,
                          constraints: const BoxConstraints(minHeight: 48),
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primary
                                : CalcwiseTheme.of(context).surfaceHigh,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                                color: sel
                                    ? AppTheme.primary
                                    : CalcwiseTheme.of(context).cardBorder),
                          ),
                          child: Text(
                            months[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? Colors.white : null,
                              fontWeight:
                                  sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: AppTextSize.md,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(s.cancel),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() =>
                        _selectedMonth = DateTime(pickedYear, pickedMonth));
                    Navigator.pop(ctx);
                    _loadExpenses();
                  },
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
                  child: Text(s.ok),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleProperty(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        _expenseMap.remove(id);
      } else {
        if (_selectedIds.length >= 3) return; // max 3
        _selectedIds.add(id);
      }
    });
    _loadExpenses();
    if (_selectedIds.length >= 2) {
      AnalyticsService.instance.logPropertiesCompared();
    }
  }

  // ── SmartHistory helpers ────────────────────────────────────────────────────

  double _roundTo(double v, double step) => (v / step).round() * step;

  void _scheduleAutoSave() {
    final selected = _selectedProperties;
    if (selected.length < 2) return;
    // Use first two selected properties for hash (sorted by id for stability)
    final sorted = List<Property>.from(selected)..sort((a, b) => a.id.compareTo(b.id));
    final p1 = sorted[0];
    final p2 = sorted[1];
    final e1 = _expenseMap[p1.id];
    final e2 = _expenseMap[p2.id];

    final hash = ResultHasher.hashInputs({
      'p1_value': _roundTo(p1.monthlyRent * 12 * 10, 5000), // proxy for property value
      'p1_rent': _roundTo(p1.monthlyRent, 100),
      'p2_value': _roundTo(p2.monthlyRent * 12 * 10, 5000),
      'p2_rent': _roundTo(p2.monthlyRent, 100),
    });
    _currentHash = hash;

    final cf1 = _cf(p1);
    final cf2 = _cf(p2);
    final winner = cf1 >= cf2 ? p1.name : p2.name;

    final l1 = <String, dynamic>{
      'prop1_value': p1.monthlyRent * 12 * 10,
      'prop2_value': p2.monthlyRent * 12 * 10,
      'winner': winner,
      'winner_coc_return': cf1 >= cf2 ? (cf1 * 12) : (cf2 * 12),
    };
    final l2 = <String, dynamic>{
      'inputs': {
        'prop1_name': p1.name,
        'prop1_rent': p1.monthlyRent,
        'prop1_expenses': e1?.totalExpenses ?? 0,
        'prop2_name': p2.name,
        'prop2_rent': p2.monthlyRent,
        'prop2_expenses': e2?.totalExpenses ?? 0,
        'month': _selectedMonth.month,
        'year': _selectedMonth.year,
      },
      'results': {
        'prop1_cashflow': cf1,
        'prop1_annual_cf': cf1 * 12,
        'prop2_cashflow': cf2,
        'prop2_annual_cf': cf2 * 12,
        'winner': winner,
      },
    };
    smartHistoryService.scheduleAutoSave(
      appKey: 'rentalexpenses',
      screenId: 'roi',
      inputHash: hash,
      l1: l1,
      l2: l2,
    );
  }

  Future<void> _saveScenario(String? label) async {
    final hash = _currentHash;
    if (hash == null) return;
    final selected = _selectedProperties;
    if (selected.length < 2) return;
    final sorted = List<Property>.from(selected)..sort((a, b) => a.id.compareTo(b.id));
    final p1 = sorted[0];
    final p2 = sorted[1];
    final e1 = _expenseMap[p1.id];
    final e2 = _expenseMap[p2.id];
    final cf1 = _cf(p1);
    final cf2 = _cf(p2);
    final winner = cf1 >= cf2 ? p1.name : p2.name;

    await smartHistoryService.saveScenario(
      appKey: 'rentalexpenses',
      screenId: 'roi',
      inputHash: hash,
      l1: {
        'prop1_value': p1.monthlyRent * 12 * 10,
        'prop2_value': p2.monthlyRent * 12 * 10,
        'winner': winner,
        'winner_coc_return': cf1 >= cf2 ? (cf1 * 12) : (cf2 * 12),
      },
      l2: {
        'inputs': {
          'prop1_name': p1.name,
          'prop1_rent': p1.monthlyRent,
          'prop1_expenses': e1?.totalExpenses ?? 0,
          'prop2_name': p2.name,
          'prop2_rent': p2.monthlyRent,
          'prop2_expenses': e2?.totalExpenses ?? 0,
          'month': _selectedMonth.month,
          'year': _selectedMonth.year,
        },
        'results': {
          'prop1_cashflow': cf1,
          'prop1_annual_cf': cf1 * 12,
          'prop2_cashflow': cf2,
          'prop2_annual_cf': cf2 * 12,
          'winner': winner,
        },
      },
      label: label,
    );
    historyRefreshNotifier.value++;
    adService.onSave();
    final trigger = await paywallSession.recordAction();
    if (!mounted) return;
    if (trigger == PaywallTrigger.soft) PaywallSoft.show(context);
    if (trigger == PaywallTrigger.hard) PaywallHard.show(context);
  }

  Future<void> _exportPdf(bool isSpanish) async {
    final selected = _selectedProperties;
    if (selected.length < 2) return;
    HapticFeedback.mediumImpact();

    Future<void> doExport() => PdfExportService.exportComparison(
          context: context,
          properties: selected.map((p) {
            final e = _expenseMap[p.id];
            final cf = _cf(p);
            final ratio = _ratio(p);
            final noi = _noi(p);
            return <String, dynamic>{
              'name': p.name,
              'address': p.address,
              'rent': p.monthlyRent,
              'expenses': e?.totalExpenses ?? 0.0,
              'netIncome': cf,
              'expenseRatio': ratio,
              'noi': noi,
            };
          }).toList(),
          selectedMonth: _selectedMonth,
          isSpanish: isSpanish,
        );

    if (freemiumService.hasFullAccess) {
      await doExport();
      await AnalyticsService.instance.logPdfExported();
    } else {
      await PdfExportService.showUnlockOrPay(context, doExport);
    }
  }

  List<Property> get _selectedProperties =>
      _allProperties.where((p) => _selectedIds.contains(p.id)).toList();

  double _cf(Property p) {
    final e = _expenseMap[p.id];
    return p.monthlyRent - (e?.totalExpenses ?? 0);
  }

  double _ratio(Property p) {
    final e = _expenseMap[p.id];
    if (p.monthlyRent <= 0 || e == null) return 0;
    return e.totalExpenses / p.monthlyRent * 100;
  }

  double _noi(Property p) {
    final e = _expenseMap[p.id];
    final mort = e?.mortgage ?? 0;
    final exp = e?.totalExpenses ?? 0;
    return (p.monthlyRent - (exp - mort)) * 12;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        final isPremium = freemiumService.hasFullAccess;

        if (!isPremium) {
          return Scaffold(
            appBar: AppBar(title: Text(s.compareProperties)),
            body: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_rounded,
                                size: 48, color: AppTheme.primary),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            s.premiumFeature,
                            style: const TextStyle(
                                fontSize: AppTextSize.titleMd,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.smPlus),
                          Text(
                            s.premiumFeatureSubtitle,
                            style: TextStyle(
                                color: CalcwiseTheme.of(context).textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xxlPlus),
                          ElevatedButton.icon(
                            onPressed: () => PaywallHard.show(context),
                            icon: const Icon(Icons.star_rounded),
                            label: Text(s.getPremium),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const CalcwiseAdFooter(),
              ],
            ),
          );
        }

        final dateFmt = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en');
        final selected = _selectedProperties;

        return Scaffold(
          appBar: AppBar(
            title: Text(s.compareProperties),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded),
                tooltip: 'Pick month',
                onPressed: () => _pickMonth(isSpanish),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const SizedBox.shrink()
                    : _allProperties.isEmpty
                        ? Center(
                            child: Text(
                              s.noPropertiesToCompare,
                              style: TextStyle(
                                  color:
                                      CalcwiseTheme.of(context).textSecondary),
                            ),
                          )
                        : ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              // Month badge
                              InkWell(
                                onTap: () => _pickMonth(isSpanish),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                child: Container(
                                  constraints:
                                      const BoxConstraints(minHeight: 48),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary
                                        .withValues(alpha: 0.08),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_month_rounded,
                                          color: AppTheme.primary, size: 18),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        dateFmt.format(_selectedMonth),
                                        style: const TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // Property chips
                              _SectionLabel(s.selectPropertiesMax3),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _allProperties.map((p) {
                                  final sel = _selectedIds.contains(p.id);
                                  return FilterChip(
                                    label: Text(p.name),
                                    selected: sel,
                                    onSelected: (_) {
                                      _toggleProperty(p.id);
                                    },
                                    selectedColor: AppTheme.primary
                                        .withValues(alpha: 0.15),
                                    checkmarkColor: AppTheme.primary,
                                    side: BorderSide(
                                      color: sel
                                          ? AppTheme.primary
                                          : CalcwiseTheme.of(context)
                                              .cardBorder,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: AppSpacing.xl),

                              // Comparison table
                              if (selected.length >= 2) ...[
                                _SectionLabel(s.comparison),
                                CalcwisePageEntrance(child: Card(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    child: _ComparisonTable(
                                      properties: selected,
                                      expenseMap: _expenseMap,
                                      isSpanish: isSpanish,
                                      cfFn: _cf,
                                      ratioFn: _ratio,
                                      noiFn: _noi,
                                    ),
                                  ),
                                )), // CalcwisePageEntrance closes
                                const SizedBox(height: AppSpacing.md),
                                SaveScenarioButton(onSave: _saveScenario),
                                const SizedBox(height: AppSpacing.sm),
                                OutlinedButton.icon(
                                  onPressed: () => _exportPdf(isSpanish),
                                  icon: const Icon(Icons.picture_as_pdf_rounded),
                                  label: Text(s.exportPdf),
                                  style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 44)),
                                ),
                              ] else
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.xl),
                                  decoration: BoxDecoration(
                                    color:
                                        CalcwiseTheme.of(context).surfaceHigh,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                    border: Border.all(
                                        color: CalcwiseTheme.of(context)
                                            .cardBorder),
                                  ),
                                  child: Text(
                                    s.selectAtLeast2,
                                    style: TextStyle(
                                        color: CalcwiseTheme.of(context)
                                            .textSecondary),
                                    textAlign: TextAlign.center,
                                  ),
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

// ── Comparison table ──────────────────────────────────────────────────────────

class _ComparisonTable extends StatelessWidget {
  final List<Property> properties;
  final Map<String, MonthlyExpense?> expenseMap;
  final bool isSpanish;
  final double Function(Property) cfFn;
  final double Function(Property) ratioFn;
  final double Function(Property) noiFn;

  const _ComparisonTable({
    required this.properties,
    required this.expenseMap,
    required this.isSpanish,
    required this.cfFn,
    required this.ratioFn,
    required this.noiFn,
  });

  @override
  Widget build(BuildContext context) {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final rows = [
      _RowData(
        label: s.monthlyRentRow,
        values:
            properties.map((p) => AmountFormatter.ui(p.monthlyRent, 'USD')).toList(),
        colors: properties
            .map((_) => CalcwiseTheme.of(context).textSecondary)
            .toList(),
        higherIsBetter: true,
        rawValues: properties.map((p) => p.monthlyRent).toList(),
      ),
      _RowData(
        label: s.totalExpensesRow,
        values: properties.map((p) {
          final e = expenseMap[p.id];
          return AmountFormatter.ui(e?.totalExpenses ?? 0, 'USD');
        }).toList(),
        colors: properties
            .map((_) => CalcwiseTheme.of(context).textSecondary)
            .toList(),
        higherIsBetter: false,
        rawValues: properties
            .map((p) => expenseMap[p.id]?.totalExpenses ?? 0)
            .toList(),
      ),
      _RowData(
        label: s.monthlyCFRow,
        values: properties.map((p) {
          final cf = cfFn(p);
          return '${cf < 0 ? '-' : '+'}${AmountFormatter.ui(cf.abs(), 'USD')}';
        }).toList(),
        colors: properties.map((p) {
          final cf = cfFn(p);
          return cf >= 0
              ? AppTheme.success
              : CalcwiseSemanticColors.error(Theme.of(context).brightness);
        }).toList(),
        higherIsBetter: true,
        rawValues: properties.map(cfFn).toList(),
      ),
      _RowData(
        label: s.annualCFRow,
        values: properties.map((p) {
          final cf = cfFn(p) * 12;
          return '${cf < 0 ? '-' : '+'}${AmountFormatter.ui(cf.abs(), 'USD')}';
        }).toList(),
        colors: properties.map((p) {
          final cf = cfFn(p);
          return cf >= 0
              ? AppTheme.success
              : CalcwiseSemanticColors.error(Theme.of(context).brightness);
        }).toList(),
        higherIsBetter: true,
        rawValues: properties.map((p) => cfFn(p) * 12).toList(),
      ),
      _RowData(
        label: s.expenseRatioRow,
        values:
            properties.map((p) => '${ratioFn(p).toStringAsFixed(1)}%').toList(),
        colors: properties.map((p) {
          final r = ratioFn(p);
          return r < 80 ? AppTheme.success : CalcwiseSemanticColors.warnIcon;
        }).toList(),
        higherIsBetter: false,
        rawValues: properties.map(ratioFn).toList(),
      ),
      _RowData(
        label: s.noiAnnual(s.annual.toLowerCase()),
        values: properties.map((p) {
          final n = noiFn(p);
          return '${n < 0 ? '-' : ''}${AmountFormatter.ui(n.abs(), 'USD')}';
        }).toList(),
        colors: properties.map((p) {
          final n = noiFn(p);
          return n >= 0
              ? AppTheme.success
              : CalcwiseSemanticColors.error(Theme.of(context).brightness);
        }).toList(),
        higherIsBetter: true,
        rawValues: properties.map(noiFn).toList(),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            const SizedBox(width: 110),
            ...properties.map((p) => Expanded(
                  child: Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppTextSize.sm,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
          ],
        ),
        Divider(height: 16, color: CalcwiseTheme.of(context).cardBorder),

        // Data rows
        ...rows.map((row) {
          // Find best value index
          int bestIdx = 0;
          for (int i = 1; i < row.rawValues.length; i++) {
            if (row.higherIsBetter) {
              if (row.rawValues[i] > row.rawValues[bestIdx]) bestIdx = i;
            } else {
              if (row.rawValues[i] < row.rawValues[bestIdx]) bestIdx = i;
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    row.label,
                    style: TextStyle(
                        fontSize: AppTextSize.sm,
                        color: CalcwiseTheme.of(context).textSecondary),
                  ),
                ),
                ...List.generate(properties.length, (i) {
                  final isBest = i == bestIdx &&
                      row.rawValues.any((v) => v != row.rawValues[0]);
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
                      decoration: isBest
                          ? BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            )
                          : null,
                      child: Text(
                        row.values[i],
                        style: TextStyle(
                          fontSize: AppTextSize.md,
                          fontWeight: FontWeight.bold,
                          color: row.colors[i],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _RowData {
  final String label;
  final List<String> values;
  final List<Color> colors;
  final bool higherIsBetter;
  final List<double> rawValues;

  _RowData({
    required this.label,
    required this.values,
    required this.colors,
    required this.higherIsBetter,
    required this.rawValues,
  });
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(label,
            style: TextStyle(
                fontSize: AppTextSize.xs,
                fontWeight: FontWeight.bold,
                color: CalcwiseTheme.of(context).textSecondary,
                letterSpacing: 0.8)),
      );
}
