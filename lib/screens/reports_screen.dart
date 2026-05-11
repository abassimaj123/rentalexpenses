import '../core/ads/ad_footer.dart';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../models/expense_model.dart';
import '../models/property_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';
import '../widgets/paywall_soft.dart';
import '../widgets/premium_cta_widget.dart';
import 'tax_summary_screen.dart';

// ── Palette cycling for bar chart ─────────────────────────────────────────────
const _chartColors = [
  AppTheme.primary,
  AppTheme.success,
  AppTheme.warning,
  Colors.red,
  AppTheme.chartPurple,
  AppTheme.chartTeal,
];

// ── Category labels ────────────────────────────────────────────────────────────
const _catKeysEn = [
  'Mortgage', 'Prop. Taxes', 'Insurance', 'HOA Fees',
  'Prop. Mgmt', 'Maintenance', 'Vacancy', 'Utilities',
  'Landscaping', 'Other',
];
const _catKeysEs = [
  'Hipoteca', 'Impuestos', 'Seguro', 'HOA',
  'Adm. Prop.', 'Mantenimiento', 'Vacancia', 'Servicios',
  'Jardinería', 'Otro',
];

// ── Trend data point ──────────────────────────────────────────────────────────
class _TrendPoint {
  final int year;
  final int month;
  final double income;   // sum of all properties' current monthlyRent
  final double expenses; // sum of recorded expenses that month (0 if untracked)
  double get cashFlow => income - expenses;

  const _TrendPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
  });
}

List<double> _catValues(MonthlyExpense? e) {
  if (e == null) return List.filled(10, 0);
  return [
    e.mortgage, e.propertyTaxes, e.insurance, e.hoaFees,
    e.propertyMgmt, e.maintenance, e.vacancyLoss, e.utilities,
    e.landscaping, e.otherExpenses,
  ];
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Property> _properties = [];
  Map<String, MonthlyExpense?> _expenseMap = {};
  List<_TrendPoint> _trendData = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logReportViewed();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final props = await PropertyDatabaseService.instance.getAllProperties();

    // Current-month expenses (existing logic)
    final Map<String, MonthlyExpense?> map = {};
    for (final p in props) {
      map[p.id] = await PropertyDatabaseService.instance
          .getExpenseForMonth(p.id, _selectedMonth.year, _selectedMonth.month);
    }

    // ── 12-month cash-flow trend ────────────────────────────────────────────
    final now       = DateTime.now();
    final fromDate  = DateTime(now.year, now.month - 11); // Dart normalises overflow
    final totalRent = props.fold<double>(0, (s, p) => s + p.monthlyRent);

    final expTotals = await PropertyDatabaseService.instance.getMonthlyExpenseTotals(
      fromYear:  fromDate.year,  fromMonth:  fromDate.month,
      toYear:    now.year,       toMonth:    now.month,
    );

    final trend = <_TrendPoint>[];
    for (int i = 0; i < 12; i++) {
      final d   = DateTime(now.year, now.month - 11 + i);
      final key = d.year * 12 + d.month;
      trend.add(_TrendPoint(
        year:     d.year,
        month:    d.month,
        income:   totalRent,
        expenses: expTotals[key] ?? 0,
      ));
    }

    if (mounted) {
      setState(() {
        _properties = props;
        _expenseMap = map;
        _trendData  = trend;
        _loading    = false;
      });
    }
  }

  double _cf(Property p) {
    final e = _expenseMap[p.id];
    return p.monthlyRent - (e?.totalExpenses ?? 0);
  }

  Future<void> _pickMonth(bool isSpanish) async {
    int year  = _selectedMonth.year;
    int month = _selectedMonth.month;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        int pickedYear  = year;
        int pickedMonth = month;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final monthsEn = ['Jan','Feb','Mar','Apr','May','Jun',
                              'Jul','Aug','Sep','Oct','Nov','Dec'];
            final monthsEs = ['Ene','Feb','Mar','Abr','May','Jun',
                              'Jul','Ago','Sep','Oct','Nov','Dic'];
            final months = isSpanish ? monthsEs : monthsEn;
            return AlertDialog(
              title: Text(isSpanish ? 'Seleccionar Mes' : 'Select Month'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setLocal(() => pickedYear--),
                      ),
                      Text('$pickedYear',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setLocal(() => pickedYear++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (i) {
                      final sel = (i + 1) == pickedMonth;
                      return GestureDetector(
                        onTap: () => setLocal(() => pickedMonth = i + 1),
                        child: Container(
                          width: 62,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: sel
                                ? AppTheme.primary
                                : Theme.of(ctx).colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: sel ? AppTheme.primary : CalcwiseTheme.of(context).cardBorder),
                          ),
                          child: Text(
                            months[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: sel ? Colors.white : null,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13,
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
                  child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth = DateTime(pickedYear, pickedMonth);
                    });
                    Navigator.pop(ctx);
                    _load();
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _exportPdf(BuildContext context) async {
    if (!freemiumService.isPremium) {
      await PaywallHard.show(context);
      return;
    }

    final doc = pw.Document();
    final dateFmt = DateFormat('MMMM yyyy', 'en');
    final monthLabel = dateFmt.format(_selectedMonth);
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) {
          final rows = <pw.Widget>[
            pw.Text('Rental Expenses Report',
                style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Period: $monthLabel',
                style: const pw.TextStyle(fontSize: 13)),
            pw.SizedBox(height: 16),
          ];

          // Per-property summaries
          for (final p in _properties) {
            final e = _expenseMap[p.id];
            final vals = _catValues(e);
            final cf = p.monthlyRent - (e?.totalExpenses ?? 0);

            rows.add(pw.Text(p.name,
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
            rows.add(pw.SizedBox(height: 4));

            final tableData = <List<String>>[
              ['Category', 'Amount'],
              ['Monthly Rent', '\$${_fmt.format(p.monthlyRent)}'],
              ..._catKeysEn.asMap().entries
                  .where((en) => vals[en.key] > 0)
                  .map((en) => [en.value, '\$${_fmt.format(vals[en.key])}']),
              ['Total Expenses', '\$${_fmt.format(e?.totalExpenses ?? 0)}'],
              ['Cash Flow', '${cf < 0 ? '-' : '+'}\$${_fmt.format(cf.abs())}'],
            ];

            rows.add(
              pw.TableHelper.fromTextArray(
                headers: tableData.first,
                data: tableData.skip(1).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                cellStyle: const pw.TextStyle(fontSize: 11),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellHeight: 22,
              ),
            );
            rows.add(pw.SizedBox(height: 14));
          }

          // Overall totals
          double totalRent = 0, totalExp = 0, totalCF = 0;
          for (final p in _properties) {
            final e = _expenseMap[p.id];
            totalRent += p.monthlyRent;
            totalExp  += e?.totalExpenses ?? 0;
            totalCF   += _cf(p);
          }

          rows.addAll([
            pw.Divider(),
            pw.Text('Portfolio Totals',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['Metric', 'Amount'],
              data: [
                ['Properties', '${_properties.length}'],
                ['Total Rent', '\$${_fmt.format(totalRent)}'],
                ['Total Expenses', '\$${_fmt.format(totalExp)}'],
                ['Monthly Cash Flow',
                  '${totalCF < 0 ? '-' : '+'}\$${_fmt.format(totalCF.abs())}'],
                ['Annual Cash Flow',
                  '${(totalCF * 12) < 0 ? '-' : '+'}\$${_fmt.format((totalCF * 12).abs())}'],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
              cellStyle: const pw.TextStyle(fontSize: 11),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 22,
            ),
            pw.SizedBox(height: 20),
            pw.Text('Generated: $now',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          ]);

          return rows;
        },
      ),
    );

    await AnalyticsService.instance.logPdfExported();
    await Printing.layoutPdf(onLayout: (_) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final dateFmt = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en');
        final monthLabel = dateFmt.format(_selectedMonth);

        // Compute portfolio stats
        double totalRent = 0;
        double totalCF   = 0;
        for (final p in _properties) {
          totalRent += p.monthlyRent;
          totalCF   += _cf(p);
        }
        final totalAnnualCF = totalCF * 12;

        // Sorted by CF descending
        final sorted = List<Property>.from(_properties)
          ..sort((a, b) => _cf(b).compareTo(_cf(a)));
        final performers      = sorted.where((p) => _cf(p) >= 0).toList();
        final underperformers = sorted.where((p) => _cf(p) < 0).toList();

        // Chart: premium gate — show first property only if >2 props and not premium
        final isPremium = freemiumService.isPremium;
        final showFullChart = isPremium || _properties.length <= 2;
        final chartProps = showFullChart ? _properties : [_properties.first];

        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish ? 'Reportes' : 'Reports'),
            actions: [
              // Premium badge
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.isPremiumNotifier,
                builder: (_, isPremium, __) {
                  if (isPremium) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 4),
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
              IconButton(
                icon: const Icon(Icons.account_balance_rounded),
                tooltip: isSpanish ? 'Schedule E / Taxes' : 'Schedule E / Taxes',
                onPressed: () => Navigator.of(context).push(PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const TaxSummaryScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 250),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_outlined),
                tooltip: isSpanish ? 'Exportar PDF' : 'Export PDF',
                onPressed: () => _exportPdf(context),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month_rounded),
                tooltip: isSpanish ? 'Seleccionar mes' : 'Select month',
                onPressed: () => _pickMonth(isSpanish),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _properties.isEmpty
                        ? _EmptyState(isSpanish: isSpanish)
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Month selector chip
                              GestureDetector(
                                onTap: () => _pickMonth(isSpanish),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppTheme.primary.withValues(alpha: 0.25)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.calendar_month_rounded,
                                          color: AppTheme.primary, size: 18),
                                      const SizedBox(width: 8),
                                      Text(
                                        monthLabel,
                                        style: const TextStyle(
                                          color: AppTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.expand_more_rounded,
                                          color: AppTheme.primary, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Portfolio summary
                              _SectionLabel(
                                  isSpanish ? 'RESUMEN DEL PORTAFOLIO' : 'PORTFOLIO SUMMARY'),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _SummaryTile(
                                              icon: Icons.home_work_rounded,
                                              label: isSpanish ? 'Propiedades' : 'Properties',
                                              value: '${_properties.length}',
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          Expanded(
                                            child: _SummaryTile(
                                              icon: Icons.attach_money_rounded,
                                              label: isSpanish ? 'Ingresos totales' : 'Total Rent',
                                              value: '\$${_fmt.format(totalRent)}',
                                              color: CalcwiseTheme.of(context).textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Divider(height: 24, color: CalcwiseTheme.of(context).cardBorder),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _SummaryTile(
                                              icon: Icons.trending_up_rounded,
                                              label: isSpanish
                                                  ? 'Flujo de caja mensual'
                                                  : 'Monthly Cash Flow',
                                              value:
                                                  '${totalCF < 0 ? '-' : '+'}\$${_fmt.format(totalCF.abs())}',
                                              color: totalCF >= 0 ? AppTheme.success : AppTheme.dangerRed,
                                            ),
                                          ),
                                          Expanded(
                                            child: _SummaryTile(
                                              icon: Icons.calendar_today_rounded,
                                              label: isSpanish
                                                  ? 'Flujo de caja anual'
                                                  : 'Annual Cash Flow',
                                              value:
                                                  '${totalAnnualCF < 0 ? '-' : '+'}\$${_fmt.format(totalAnnualCF.abs())}',
                                              color:
                                                  totalAnnualCF >= 0 ? AppTheme.success : AppTheme.dangerRed,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ── 12-Month Cash-Flow Trend ───────────────────
                              if (_trendData.isNotEmpty) ...[
                                _SectionLabel(isSpanish
                                    ? 'TENDENCIA 12 MESES'
                                    : '12-MONTH TREND'),
                                _CashFlowTrendChart(
                                  points:    _trendData,
                                  isPremium: isPremium,
                                  isSpanish: isSpanish,
                                  fmt:       _fmt,
                                ),
                                const SizedBox(height: 20),
                              ],

                              // ── Expense Category Chart ─────────────────────
                              _SectionLabel(
                                  isSpanish ? 'GASTOS POR CATEGORÍA' : 'EXPENSES BY CATEGORY'),
                              _ExpenseCategoryChart(
                                properties: chartProps,
                                expenseMap: _expenseMap,
                                isSpanish: isSpanish,
                                fmt: _fmt,
                              ),
                              if (!showFullChart) ...[
                                const SizedBox(height: 10),
                                PremiumCtaWidget(
                                  feature: isSpanish
                                      ? 'el gráfico completo'
                                      : 'full category chart',
                                ),
                              ],
                              const SizedBox(height: 20),

                              // Top performers
                              if (performers.isNotEmpty) ...[
                                _SectionLabel(isSpanish
                                    ? 'MEJORES PROPIEDADES'
                                    : 'TOP PERFORMERS'),
                                ...performers.map((p) => _PropertyRow(
                                  property: p,
                                  expense: _expenseMap[p.id],
                                  fmt: _fmt,
                                  isSpanish: isSpanish,
                                  isUnderperformer: false,
                                )),
                                const SizedBox(height: 16),
                              ],

                              // Underperformers
                              if (underperformers.isNotEmpty) ...[
                                _SectionLabel(isSpanish
                                    ? 'PROPIEDADES CON PÉRDIDAS'
                                    : 'UNDERPERFORMERS'),
                                ...underperformers.map((p) => _PropertyRow(
                                  property: p,
                                  expense: _expenseMap[p.id],
                                  fmt: _fmt,
                                  isSpanish: isSpanish,
                                  isUnderperformer: true,
                                )),
                              ],
                            ],
                          ),
              ),
              const AdFooter(),
            ],
          ),
        );
      },
    );
  }
}

// ── Expense Category Bar Chart ─────────────────────────────────────────────────

class _ExpenseCategoryChart extends StatelessWidget {
  final List<Property> properties;
  final Map<String, MonthlyExpense?> expenseMap;
  final bool isSpanish;
  final NumberFormat fmt;

  const _ExpenseCategoryChart({
    required this.properties,
    required this.expenseMap,
    required this.isSpanish,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    // Aggregate category totals across shown properties
    final totals = List<double>.filled(10, 0);
    for (final p in properties) {
      final vals = _catValues(expenseMap[p.id]);
      for (var i = 0; i < 10; i++) {
        totals[i] += vals[i];
      }
    }

    // Only include categories with non-zero values
    final activeIndices = <int>[];
    for (var i = 0; i < 10; i++) {
      if (totals[i] > 0) activeIndices.add(i);
    }

    if (activeIndices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              isSpanish ? 'Sin gastos registrados' : 'No expenses recorded',
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
            ),
          ),
        ),
      );
    }

    final labels = isSpanish ? _catKeysEs : _catKeysEn;
    final maxVal = activeIndices.map((i) => totals[i]).reduce((a, b) => a > b ? a : b);

    final barGroups = activeIndices.asMap().entries.map((entry) {
      final idx = entry.key;
      final catIdx = entry.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: totals[catIdx],
            color: _chartColors[catIdx % _chartColors.length],
            width: 14,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final chartHeight = (constraints.maxWidth < 400)
                  ? 200.0
                  : 240.0;
                return SizedBox(
                  height: chartHeight,
                  child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.2,
                  barGroups: barGroups,
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 52,
                        getTitlesWidget: (val, meta) {
                          if (val == 0) return const SizedBox.shrink();
                          return Text(
                            '\$${val >= 1000 ? '${(val / 1000).toStringAsFixed(1)}k' : val.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 10, color: CalcwiseTheme.of(context).textSecondary),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();
                          if (i < 0 || i >= activeIndices.length) {
                            return const SizedBox.shrink();
                          }
                          final catIdx = activeIndices[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              labels[catIdx],
                              style: TextStyle(fontSize: 9, color: CalcwiseTheme.of(context).textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final catIdx = activeIndices[group.x];
                        return BarTooltipItem(
                          '${labels[catIdx]}\n\$${fmt.format(rod.toY)}',
                          const TextStyle(color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                ),
              ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: activeIndices.map((catIdx) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _chartColors[catIdx % _chartColors.length],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(labels[catIdx],
                        style: TextStyle(fontSize: 10, color: CalcwiseTheme.of(context).textSecondary)),
                  ],
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: CalcwiseTheme.of(context).textSecondary,
                letterSpacing: 0.8)),
      );
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(fontSize: 11, color: CalcwiseTheme.of(context).textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final Property property;
  final MonthlyExpense? expense;
  final NumberFormat fmt;
  final bool isSpanish;
  final bool isUnderperformer;
  const _PropertyRow({
    required this.property,
    required this.expense,
    required this.fmt,
    required this.isSpanish,
    required this.isUnderperformer,
  });

  @override
  Widget build(BuildContext context) {
    final cf = property.monthlyRent - (expense?.totalExpenses ?? 0);
    final cfColor = cf >= 0 ? AppTheme.success : AppTheme.dangerRed;
    final ratio = property.monthlyRent > 0
        ? ((expense?.totalExpenses ?? 0) / property.monthlyRent * 100) : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isUnderperformer
          ? AppTheme.dangerRed.withValues(alpha: 0.08)
          : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isUnderperformer
            ? BorderSide(color: AppTheme.dangerRed.withValues(alpha: 0.30))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cfColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                cf >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: cfColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(property.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${isSpanish ? 'Alquiler' : 'Rent'}: \$${fmt.format(property.monthlyRent)}  •  ${ratio.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 12, color: CalcwiseTheme.of(context).textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${cf < 0 ? '-' : '+'}\$${fmt.format(cf.abs())}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cfColor,
                    fontSize: 15,
                  ),
                ),
                Text(
                  isSpanish ? '/mes' : '/mo',
                  style: TextStyle(fontSize: 11, color: CalcwiseTheme.of(context).textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 12-Month Cash-Flow Trend Chart ────────────────────────────────────────────

class _CashFlowTrendChart extends StatelessWidget {
  final List<_TrendPoint> points;
  final bool isPremium;
  final bool isSpanish;
  final NumberFormat fmt;

  const _CashFlowTrendChart({
    required this.points,
    required this.isPremium,
    required this.isSpanish,
    required this.fmt,
  });

  static const _freeMonths = 3;

  static const _monthsEn = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  static const _monthsEs = [
    'Ene','Feb','Mar','Abr','May','Jun',
    'Jul','Ago','Sep','Oct','Nov','Dic',
  ];

  @override
  Widget build(BuildContext outerCtx) {
    final theme = CalcwiseTheme.of(outerCtx);
    final displayPoints = isPremium
        ? points
        : points.sublist(points.length > _freeMonths
            ? points.length - _freeMonths
            : 0);
    final isLimited = !isPremium && points.length > _freeMonths;

    final labels = isSpanish ? _monthsEs : _monthsEn;

    // Handle empty / all-zero state
    final hasData = displayPoints.any((p) => p.income > 0 || p.expenses > 0);
    if (!hasData) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Center(
            child: Text(
              isSpanish
                  ? 'Sin datos registrados aún'
                  : 'No data recorded yet',
              style: TextStyle(color: theme.textSecondary),
            ),
          ),
        ),
      );
    }

    final maxY = displayPoints
            .map((p) => math.max(p.income, p.expenses))
            .reduce((a, b) => a > b ? a : b) *
        1.25;

    final barWidth = isPremium ? 18.0 : 28.0;

    final barGroups = displayPoints.asMap().entries.map((entry) {
      final i   = entry.key;
      final pt  = entry.value;
      final cf  = pt.cashFlow;
      final top = math.max(pt.income, pt.expenses);

      final stack = <BarChartRodStackItem>[];

      if (pt.expenses > 0 && pt.income > 0) {
        // Red portion = expenses
        stack.add(BarChartRodStackItem(
            0, pt.expenses, Colors.red.shade400));
        if (cf > 0) {
          // Green portion = cash flow above expenses
          stack.add(BarChartRodStackItem(
              pt.expenses, pt.income, AppTheme.success));
        }
      } else if (pt.income > 0) {
        // Only rent, no expenses tracked → subtle green
        stack.add(BarChartRodStackItem(
            0, pt.income, AppTheme.success.withValues(alpha: 0.45)));
      } else if (pt.expenses > 0) {
        stack.add(BarChartRodStackItem(
            0, pt.expenses, Colors.red.shade400));
      }

      if (stack.isEmpty) {
        stack.add(BarChartRodStackItem(0, 1, theme.cardBorder));
      }

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: top < 1 ? 1 : top,
            rodStackItems: stack,
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft:  Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend row
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Row(children: [
                _LegendDot(color: AppTheme.success),
                const SizedBox(width: 4),
                Text(
                  isSpanish ? 'Flujo de caja' : 'Cash Flow',
                  style: TextStyle(
                      fontSize: 11, color: theme.textSecondary),
                ),
                const SizedBox(width: 14),
                _LegendDot(color: Colors.red.shade400),
                const SizedBox(width: 4),
                Text(
                  isSpanish ? 'Gastos' : 'Expenses',
                  style: TextStyle(
                      fontSize: 11, color: theme.textSecondary),
                ),
              ]),
            ),

            // Chart
            LayoutBuilder(
              builder: (context, constraints) {
                final chartHeight = (constraints.maxWidth < 400)
                  ? 185.0
                  : 220.0;
                return SizedBox(
                  height: chartHeight,
                  child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barGroups: barGroups,
                  gridData: const FlGridData(
                      show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 54,
                        getTitlesWidget: (val, meta) {
                          if (val == 0 || val == maxY) {
                            return const SizedBox.shrink();
                          }
                          final s = val >= 1000
                              ? '\$${(val / 1000).toStringAsFixed(1)}k'
                              : '\$${val.toStringAsFixed(0)}';
                          return Text(s,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: theme.textSecondary));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (val, meta) {
                          final i = val.toInt();
                          if (i < 0 || i >= displayPoints.length) {
                            return const SizedBox.shrink();
                          }
                          final pt  = displayPoints[i];
                          final lbl = labels[pt.month - 1];
                          // Mark January with year suffix to avoid
                          // ambiguity when the chart spans two years.
                          final suffix = pt.month == 1
                              ? "\n'${pt.year % 100}"
                              : '';
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '$lbl$suffix',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: theme.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) {
                        final pt  = displayPoints[group.x];
                        final cf  = pt.cashFlow;
                        final sign = cf >= 0 ? '+' : '-';
                        return BarTooltipItem(
                          '${labels[pt.month - 1]} ${pt.year}\n'
                          '${isSpanish ? "Alquiler" : "Rent"}: \$${fmt.format(pt.income)}\n'
                          '${isSpanish ? "Gastos" : "Expenses"}: \$${fmt.format(pt.expenses)}\n'
                          '${isSpanish ? "Flujo" : "Cash Flow"}: $sign\$${fmt.format(cf.abs())}',
                          const TextStyle(
                              color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                ),
              ),
                  );
                },
              ),
            ),

            // Free-tier upsell banner
            if (isLimited) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color:
                          AppTheme.primary.withValues(alpha: 0.20)),
                ),
                child: Row(children: [
                  Icon(Icons.lock_outline,
                      size: 15, color: theme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isSpanish
                          ? 'Mostrando 3 meses. Premium desbloquea 12 meses.'
                          : 'Showing 3 months. Premium unlocks 12-month history.',
                      style: TextStyle(
                          fontSize: 11, color: theme.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => PaywallSoft.show(outerCtx),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      isSpanish ? 'Desbloquear' : 'Unlock',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary),
                    ),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSpanish;
  const _EmptyState({required this.isSpanish});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 72,
                color: CalcwiseTheme.of(context).textSecondary.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              isSpanish
                  ? 'Sin propiedades aún'
                  : 'No properties yet',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSpanish
                  ? 'Agrega propiedades en la pestaña Propiedades para ver reportes.'
                  : 'Add properties in the Properties tab to see reports here.',
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
