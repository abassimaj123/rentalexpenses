import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
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
  'Mortgage',
  'Prop. Taxes',
  'Insurance',
  'HOA Fees',
  'Prop. Mgmt',
  'Maintenance',
  'Vacancy',
  'Utilities',
  'Landscaping',
  'Other',
];
const _catKeysEs = [
  'Hipoteca',
  'Impuestos',
  'Seguro',
  'HOA',
  'Adm. Prop.',
  'Mantenimiento',
  'Vacancia',
  'Servicios',
  'Jardinería',
  'Otro',
];

// ── Cash-flow month data (net BarChart) ───────────────────────────────────────
class _CashFlowMonth {
  final int year;
  final int month;
  final double income;
  final double expenses;
  double get net => income - expenses;

  const _CashFlowMonth({
    required this.year,
    required this.month,
    required this.income,
    required this.expenses,
  });
}

// ── Trend data point ──────────────────────────────────────────────────────────
class _TrendPoint {
  final int year;
  final int month;
  final double income; // sum of all properties' current monthlyRent
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
    e.mortgage,
    e.propertyTaxes,
    e.insurance,
    e.hoaFees,
    e.propertyMgmt,
    e.maintenance,
    e.vacancyLoss,
    e.utilities,
    e.landscaping,
    e.otherExpenses,
  ];
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // AmountFormatter replaces NumberFormat _fmt

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<Property> _properties = [];
  Map<String, MonthlyExpense?> _expenseMap = {};
  List<_TrendPoint> _trendData = [];
  List<_CashFlowMonth> _cashFlowData = [];
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
    final now = DateTime.now();
    final fromDate =
        DateTime(now.year, now.month - 11); // Dart normalises overflow
    final totalRent = props.fold<double>(0, (s, p) => s + p.monthlyRent);

    final expTotals =
        await PropertyDatabaseService.instance.getMonthlyExpenseTotals(
      fromYear: fromDate.year,
      fromMonth: fromDate.month,
      toYear: now.year,
      toMonth: now.month,
    );

    final trend = <_TrendPoint>[];
    final cashFlow = <_CashFlowMonth>[];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - 11 + i);
      final key = d.year * 12 + d.month;
      final expTotal = expTotals[key] ?? 0;
      trend.add(_TrendPoint(
        year: d.year,
        month: d.month,
        income: totalRent,
        expenses: expTotal,
      ));
      cashFlow.add(_CashFlowMonth(
        year: d.year,
        month: d.month,
        income: totalRent,
        expenses: expTotal,
      ));
    }

    if (mounted) {
      setState(() {
        _properties = props;
        _expenseMap = map;
        _trendData = trend;
        _cashFlowData = cashFlow;
        _loading = false;
      });
    }
  }

  double _cf(Property p) {
    final e = _expenseMap[p.id];
    return p.monthlyRent - (e?.totalExpenses ?? 0);
  }

  Future<void> _pickMonth(bool isSpanish) async {
    int year = _selectedMonth.year;
    int month = _selectedMonth.month;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        int pickedYear = year;
        int pickedMonth = month;
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            final monthsEn = [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec'
            ];
            final monthsEs = [
              'Ene',
              'Feb',
              'Mar',
              'Abr',
              'May',
              'Jun',
              'Jul',
              'Ago',
              'Sep',
              'Oct',
              'Nov',
              'Dic'
            ];
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
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () => setLocal(() => pickedYear--),
                      ),
                      Text('$pickedYear',
                          style: const TextStyle(
                              fontSize: AppTextSize.subtitle,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
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
                      return Semantics(
                        button: true,
                        selected: sel,
                        label: months[i],
                        child: GestureDetector(
                          onTap: () => setLocal(() => pickedMonth = i + 1),
                          child: Container(
                            width: 62,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: sel
                                  ? AppTheme.primary
                                  : Theme.of(ctx)
                                      .colorScheme
                                      .surfaceContainerLow,
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
                        ), // GestureDetector
                      ); // Semantics
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
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
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
    if (!freemiumService.hasFullAccess) {
      await PaywallHard.show(context);
      return;
    }

    final isSpanish = isSpanishNotifier.value;
    final doc = pw.Document();
    final dateFmt = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en');
    final monthLabel = dateFmt.format(_selectedMonth);
    final now = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Localised strings for PDF
    final pdfTitle =
        isSpanish ? 'Informe de Gastos de Alquiler' : 'Rental Expenses Report';
    final pdfPeriod =
        isSpanish ? 'Período: $monthLabel' : 'Period: $monthLabel';
    final pdfCategory = isSpanish ? 'Categoría' : 'Category';
    final pdfAmount = isSpanish ? 'Monto' : 'Amount';
    final pdfMonthlyRent = isSpanish ? 'Alquiler mensual' : 'Monthly Rent';
    final pdfTotalExpenses = isSpanish ? 'Total de gastos' : 'Total Expenses';
    final pdfCashFlow = isSpanish ? 'Flujo de caja' : 'Cash Flow';
    final pdfPortfolioTotals =
        isSpanish ? 'Totales del portafolio' : 'Portfolio Totals';
    final pdfMetric = isSpanish ? 'Métrica' : 'Metric';
    final pdfProperties = isSpanish ? 'Propiedades' : 'Properties';
    final pdfTotalRent = isSpanish ? 'Alquiler total' : 'Total Rent';
    final pdfMonthlyFlow = isSpanish ? 'Flujo mensual' : 'Monthly Cash Flow';
    final pdfAnnualFlow = isSpanish ? 'Flujo anual' : 'Annual Cash Flow';
    final pdfGenerated = isSpanish ? 'Generado: $now' : 'Generated: $now';
    final catKeys = isSpanish ? _catKeysEs : _catKeysEn;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(AppSpacing.xxxl),
        build: (ctx) {
          final rows = <pw.Widget>[
            pw.Text(pdfTitle,
                style: pw.TextStyle(
                    fontSize: AppTextSize.titleMd,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(pdfPeriod,
                style: const pw.TextStyle(fontSize: AppTextSize.md)),
            pw.SizedBox(height: 16),
          ];

          // Per-property summaries
          for (final p in _properties) {
            final e = _expenseMap[p.id];
            final vals = _catValues(e);
            final cf = p.monthlyRent - (e?.totalExpenses ?? 0);

            rows.add(pw.Text(p.name,
                style: pw.TextStyle(
                    fontSize: AppTextSize.body,
                    fontWeight: pw.FontWeight.bold)));
            rows.add(pw.SizedBox(height: 4));

            final tableData = <List<String>>[
              [pdfCategory, pdfAmount],
              [pdfMonthlyRent, AmountFormatter.ui(p.monthlyRent, 'USD')],
              ...catKeys
                  .asMap()
                  .entries
                  .where((en) => vals[en.key] > 0)
                  .map((en) => [en.value, AmountFormatter.ui(vals[en.key], 'USD')]),
              [pdfTotalExpenses, AmountFormatter.ui(e?.totalExpenses ?? 0, 'USD')],
              [pdfCashFlow, '${cf < 0 ? '-' : '+'}${AmountFormatter.ui(cf.abs(), 'USD')}'],
            ];

            rows.add(
              pw.TableHelper.fromTextArray(
                headers: tableData.first,
                data: tableData.skip(1).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: AppTextSize.xs),
                cellStyle: const pw.TextStyle(fontSize: AppTextSize.xs),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey200),
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
            totalExp += e?.totalExpenses ?? 0;
            totalCF += _cf(p);
          }

          rows.addAll([
            pw.Divider(),
            pw.Text(pdfPortfolioTotals,
                style: pw.TextStyle(
                    fontSize: AppTextSize.body,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [pdfMetric, pdfAmount],
              data: [
                [pdfProperties, '${_properties.length}'],
                [pdfTotalRent, AmountFormatter.ui(totalRent, 'USD')],
                [pdfTotalExpenses, AmountFormatter.ui(totalExp, 'USD')],
                [
                  pdfMonthlyFlow,
                  '${totalCF < 0 ? '-' : '+'}${AmountFormatter.ui(totalCF.abs(), 'USD')}'
                ],
                [
                  pdfAnnualFlow,
                  '${(totalCF * 12) < 0 ? '-' : '+'}${AmountFormatter.ui((totalCF * 12).abs(), 'USD')}'
                ],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: AppTextSize.xs),
              cellStyle: const pw.TextStyle(fontSize: AppTextSize.xs),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 22,
            ),
            pw.SizedBox(height: 20),
            pw.Text(pdfGenerated,
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
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
        double totalCF = 0;
        for (final p in _properties) {
          totalRent += p.monthlyRent;
          totalCF += _cf(p);
        }
        final totalAnnualCF = totalCF * 12;

        // Sorted by CF descending
        final sorted = List<Property>.from(_properties)
          ..sort((a, b) => _cf(b).compareTo(_cf(a)));
        final performers = sorted.where((p) => _cf(p) >= 0).toList();
        final underperformers = sorted.where((p) => _cf(p) < 0).toList();

        // Chart: premium gate — show first property only if >2 props and not premium
        final isPremium = freemiumService.hasFullAccess;
        final showFullChart = isPremium || _properties.length <= 2;
        final chartProps = showFullChart ? _properties : [_properties.first];

        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish ? 'Reportes' : 'Reports'),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_balance_rounded),
                tooltip:
                    isSpanish ? 'Schedule E / Taxes' : 'Schedule E / Taxes',
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const TaxSummaryScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: AppDuration.base,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
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
                tooltip: isSpanish ? 'Actualizar' : 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const _ReportsSkeleton()
                    : _properties.isEmpty
                        ? _EmptyState(isSpanish: isSpanish)
                        : ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              // ── Cash Flow — Last 12 Months ─────────────
                              if (_cashFlowData.isNotEmpty) ...[
                                _SectionLabel(isSpanish
                                    ? 'FLUJO DE EFECTIVO — ÚLTIMOS 12 MESES'
                                    : 'CASH FLOW — LAST 12 MONTHS'),
                                _CashFlowNetChart(
                                  months: _cashFlowData,
                                  isSpanish: isSpanish,
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Month selector chip
                              InkWell(
                                onTap: () => _pickMonth(isSpanish),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                                child: Container(
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
                              _SectionLabel(isSpanish
                                  ? 'RESUMEN DEL PORTAFOLIO'
                                  : 'PORTFOLIO SUMMARY'),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _SummaryTile(
                                              icon: Icons.home_work_rounded,
                                              label: isSpanish
                                                  ? 'Propiedades'
                                                  : 'Properties',
                                              value: '${_properties.length}',
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                          Expanded(
                                            child: _SummaryTile(
                                              icon: Icons.attach_money_rounded,
                                              label: isSpanish
                                                  ? 'Ingresos totales'
                                                  : 'Total Rent',
                                              value:
                                                  AmountFormatter.ui(totalRent, 'USD'),
                                              color: CalcwiseTheme.of(context)
                                                  .textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Divider(
                                          height: 24,
                                          color: CalcwiseTheme.of(context)
                                              .cardBorder),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _SummaryTile(
                                              icon: Icons.trending_up_rounded,
                                              label: isSpanish
                                                  ? 'Flujo de caja mensual'
                                                  : 'Monthly Cash Flow',
                                              value:
                                                  '${totalCF < 0 ? '-' : '+'}${AmountFormatter.ui(totalCF.abs(), 'USD')}',
                                              color: totalCF >= 0
                                                  ? AppTheme.success
                                                  : AppTheme.dangerRed,
                                            ),
                                          ),
                                          Expanded(
                                            child: _SummaryTile(
                                              icon:
                                                  Icons.calendar_today_rounded,
                                              label: isSpanish
                                                  ? 'Flujo de caja anual'
                                                  : 'Annual Cash Flow',
                                              value:
                                                  '${totalAnnualCF < 0 ? '-' : '+'}${AmountFormatter.ui(totalAnnualCF.abs(), 'USD')}',
                                              color: totalAnnualCF >= 0
                                                  ? AppTheme.success
                                                  : AppTheme.dangerRed,
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
                                  points: _trendData,
                                  isPremium: isPremium,
                                  isSpanish: isSpanish,
                                ),
                                const SizedBox(height: 20),
                              ],

                              // ── Expense Category Chart ─────────────────────
                              _SectionLabel(isSpanish
                                  ? 'GASTOS POR CATEGORÍA'
                                  : 'EXPENSES BY CATEGORY'),
                              _ExpenseCategoryChart(
                                properties: chartProps,
                                expenseMap: _expenseMap,
                                isSpanish: isSpanish,
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
                                      isSpanish: isSpanish,
                                      isUnderperformer: true,
                                    )),
                              ],
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

// ── Cash Flow Net BarChart (new retention section) ────────────────────────────

class _CashFlowNetChart extends StatelessWidget {
  final List<_CashFlowMonth> months;
  final bool isSpanish;

  const _CashFlowNetChart({
    required this.months,
    required this.isSpanish,
  });

  static const _monthsEn = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _monthsEs = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  String _compact(double v) {
    final abs = v.abs();
    final sign = v < 0 ? '-' : '';
    if (abs >= 1000) return '$sign\$${(abs / 1000).toStringAsFixed(1)}k';
    return '$sign\$${abs.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = CalcwiseTheme.of(context);
    final labels = isSpanish ? _monthsEs : _monthsEn;

    // Summary stats
    final nets = months.map((m) => m.net).toList();
    final totalNet = nets.fold<double>(0, (s, n) => s + n);
    final avgNet = nets.isEmpty ? 0.0 : totalNet / nets.length;

    double bestNet = nets.isEmpty ? 0.0 : nets[0];
    int bestIdx = 0;
    for (int i = 1; i < nets.length; i++) {
      if (nets[i] > bestNet) {
        bestNet = nets[i];
        bestIdx = i;
      }
    }
    final bestMonth = months.isEmpty ? null : months[bestIdx];

    // Compute chart maxY / minY
    final maxAbsNet =
        nets.isEmpty ? 1.0 : nets.map((n) => n.abs()).reduce(math.max);
    final chartMax = (maxAbsNet * 1.3).clamp(1.0, double.infinity);

    // Accessibility label
    final semanticLabel = isSpanish
        ? 'Gráfico de flujo neto: promedio ${AmountFormatter.formatNumber(avgNet)}, total ${AmountFormatter.formatNumber(totalNet)}'
        : 'Net cash flow chart: avg ${AmountFormatter.ui(avgNet, 'USD')}, total ${AmountFormatter.ui(totalNet, 'USD')}';

    final barGroups = months.asMap().entries.map((entry) {
      final i = entry.key;
      final m = entry.value;
      final isPositive = m.net >= 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: m.net.abs() < 0.01 ? 0.01 : m.net,
            color: isPositive
                ? CalcwiseSemanticColors.success(Theme.of(context).brightness)
                : CalcwiseSemanticColors.error(Theme.of(context).brightness),
            width: CalcwiseChartTokens.barWidth,
            borderRadius: isPositive
                ? const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  )
                : const BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
          ),
        ],
      );
    }).toList();

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legend
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 10),
                child: Row(children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: CalcwiseSemanticColors.success(
                          Theme.of(context).brightness),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSpanish ? 'Positivo' : 'Positive',
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: theme.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: CalcwiseSemanticColors.error(
                          Theme.of(context).brightness),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSpanish ? 'Negativo' : 'Negative',
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: theme.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 18,
                    child: CustomPaint(
                      painter: _DashedLinePainter(
                          color: theme.textSecondary.withValues(alpha: 0.55)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isSpanish ? 'Promedio' : 'Average',
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: theme.textSecondary),
                  ),
                ]),
              ),

              // Bar chart
              LayoutBuilder(builder: (context, constraints) {
                final chartHeight =
                    (constraints.maxWidth < 400) ? 185.0 : 220.0;
                return SizedBox(
                  height: chartHeight,
                  child: BarChart(
                    BarChartData(
                      minY: -chartMax,
                      maxY: chartMax,
                      barGroups: barGroups,
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          HorizontalLine(
                            y: avgNet,
                            color: theme.textSecondary.withValues(alpha: 0.55),
                            strokeWidth: 1.5,
                            dashArray: [6, 3],
                            label: HorizontalLineLabel(
                              show: false,
                            ),
                          ),
                        ],
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: val == 0
                              ? theme.cardBorder.withValues(alpha: 0.8)
                              : theme.cardBorder.withValues(alpha: 0.35),
                          strokeWidth: val == 0 ? 1.5 : 0.8,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 54,
                            getTitlesWidget: (val, meta) {
                              if (val == chartMax || val == -chartMax) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                _compact(val),
                                style: TextStyle(
                                    fontSize: AppTextSize.xs, color: theme.textSecondary),
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
                              if (i < 0 || i >= months.length) {
                                return const SizedBox.shrink();
                              }
                              final m = months[i];
                              final lbl = labels[m.month - 1];
                              final suffix = m.month == 1
                                  ? "\n'${m.year % 100}"
                                  : '';
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '$lbl$suffix',
                                  style: TextStyle(
                                      fontSize: AppTextSize.xs, color: theme.textSecondary),
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
                            final m = months[group.x];
                            final net = m.net;
                            final sign = net >= 0 ? '+' : '-';
                            return BarTooltipItem(
                              '${labels[m.month - 1]} ${m.year}\n'
                              '${isSpanish ? "Ingresos" : "Income"}: ${AmountFormatter.ui(m.income, 'USD')}\n'
                              '${isSpanish ? "Gastos" : "Expenses"}: ${AmountFormatter.ui(m.expenses, 'USD')}\n'
                              '${isSpanish ? "Neto" : "Net"}: $sign${AmountFormatter.ui(net.abs(), 'USD')}',
                              const TextStyle(
                                  color: Colors.white,
                                  fontSize: AppTextSize.xs),
                            );
                          },
                        ),
                      ),
                    ),
                    swapAnimationDuration: CalcwiseChartTokens.swapDuration,
                  ),
                );
              }),

              const SizedBox(height: 12),

              // Summary row
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceTint,
                  borderRadius: BorderRadius.circular(AppRadius.mdPlus),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.18)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _NetStat(
                            label: isSpanish
                                ? 'Promedio mensual'
                                : 'Avg monthly net',
                            value: _compact(avgNet),
                            positive: avgNet >= 0,
                          ),
                        ),
                        Expanded(
                          child: _NetStat(
                            label: isSpanish ? 'Total neto YTD' : 'Total net YTD',
                            value: _compact(totalNet),
                            positive: totalNet >= 0,
                          ),
                        ),
                      ],
                    ),
                    if (bestMonth != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${isSpanish ? "Mejor mes" : "Best month"}: '
                        '${labels[bestMonth.month - 1]} ${bestMonth.year} '
                        '(${_compact(bestNet)})',
                        style: TextStyle(
                          fontSize: AppTextSize.xs,
                          color: CalcwiseSemanticColors.success(
                              Theme.of(context).brightness),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NetStat extends StatelessWidget {
  final String label;
  final String value;
  final bool positive;

  const _NetStat({
    required this.label,
    required this.value,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: AppTextSize.xs,
              color: CalcwiseTheme.of(context).textSecondary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: AppTextSize.bodyMd,
            fontWeight: FontWeight.bold,
            color: positive
                ? CalcwiseSemanticColors.success(Theme.of(context).brightness)
                : CalcwiseSemanticColors.error(Theme.of(context).brightness),
          ),
        ),
      ],
    );
  }
}

// ── Expense Category Bar Chart ─────────────────────────────────────────────────

class _ExpenseCategoryChart extends StatelessWidget {
  final List<Property> properties;
  final Map<String, MonthlyExpense?> expenseMap;
  final bool isSpanish;

  const _ExpenseCategoryChart({
    required this.properties,
    required this.expenseMap,
    required this.isSpanish,
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
          padding: const EdgeInsets.all(AppSpacing.xxl),
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
    final maxVal =
        activeIndices.map((i) => totals[i]).reduce((a, b) => a > b ? a : b);

    // Accessibility: build descriptive text summary for screen readers
    final _chartSummaryParts = activeIndices
        .map((i) => '${labels[i]}: ${AmountFormatter.ui(totals[i], 'USD')}')
        .join(', ');
    final _chartSemanticLabel = isSpanish
        ? 'Gráfico de gastos por categoría: $_chartSummaryParts'
        : 'Expense category chart: $_chartSummaryParts';

    final barGroups = activeIndices.asMap().entries.map((entry) {
      final idx = entry.key;
      final catIdx = entry.value;
      return BarChartGroupData(
        x: idx,
        barRods: [
          BarChartRodData(
            toY: totals[catIdx],
            color: _chartColors[catIdx % _chartColors.length],
            width: CalcwiseChartTokens.barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return Semantics(
      label: _chartSemanticLabel,
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartHeight =
                      (constraints.maxWidth < 400) ? 200.0 : 240.0;
                  return SizedBox(
                    height: chartHeight,
                    child: BarChart(
                      BarChartData(
                        maxY: maxVal * 1.2,
                        barGroups: barGroups,
                        gridData: const FlGridData(
                            show: true, drawVerticalLine: false),
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
                                  style: TextStyle(
                                      fontSize: AppTextSize.xs,
                                      color: CalcwiseTheme.of(context)
                                          .textSecondary),
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
                                    style: TextStyle(
                                        fontSize: AppTextSize.xxs,
                                        color: CalcwiseTheme.of(context)
                                            .textSecondary),
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
                                '${labels[catIdx]}\n${AmountFormatter.ui(rod.toY, 'USD')}',
                                const TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTextSize.xs),
                              );
                            },
                          ),
                        ),
                      ),
                      swapAnimationDuration: CalcwiseChartTokens.swapDuration,
                    ),
                  );
                },
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
                          style: TextStyle(
                              fontSize: AppTextSize.xs,
                              color: CalcwiseTheme.of(context).textSecondary)),
                    ],
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ), // Card
    ); // Semantics
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
                fontSize: AppTextSize.xs,
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
            style: TextStyle(
                fontSize: AppTextSize.xs,
                color: CalcwiseTheme.of(context).textSecondary),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: AppTextSize.bodyLg,
                fontWeight: FontWeight.bold,
                color: color),
            textAlign: TextAlign.center),
      ],
    );
  }
}

class _PropertyRow extends StatelessWidget {
  final Property property;
  final MonthlyExpense? expense;
  final bool isSpanish;
  final bool isUnderperformer;
  const _PropertyRow({
    required this.property,
    required this.expense,
    required this.isSpanish,
    required this.isUnderperformer,
  });

  @override
  Widget build(BuildContext context) {
    final cf = property.monthlyRent - (expense?.totalExpenses ?? 0);
    final cfColor = cf >= 0 ? AppTheme.success : AppTheme.dangerRed;
    final ratio = property.monthlyRent > 0
        ? ((expense?.totalExpenses ?? 0) / property.monthlyRent * 100)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color:
          isUnderperformer ? AppTheme.dangerRed.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: isUnderperformer
            ? BorderSide(color: AppTheme.dangerRed.withValues(alpha: 0.30))
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.mdPlus),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cfColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.mdPlus),
              ),
              child: Icon(
                cf >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
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
                    '${isSpanish ? 'Alquiler' : 'Rent'}: ${AmountFormatter.ui(property.monthlyRent, 'USD')}  •  ${ratio.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: AppTextSize.sm,
                        color: CalcwiseTheme.of(context).textSecondary),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${cf < 0 ? '-' : '+'}${AmountFormatter.ui(cf.abs(), 'USD')}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: cfColor,
                    fontSize: AppTextSize.bodyMd,
                  ),
                ),
                Text(
                  isSpanish ? '/mes' : '/mo',
                  style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: CalcwiseTheme.of(context).textSecondary),
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

  const _CashFlowTrendChart({
    required this.points,
    required this.isPremium,
    required this.isSpanish,
  });

  static const _freeMonths = 3;

  static const _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  static const _monthsEs = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  @override
  Widget build(BuildContext outerCtx) {
    final theme = CalcwiseTheme.of(outerCtx);
    final brightness = Theme.of(outerCtx).brightness;
    final successColor = CalcwiseSemanticColors.success(brightness);
    final errorColor = CalcwiseSemanticColors.error(brightness);
    final displayPoints = isPremium
        ? points
        : points.sublist(
            points.length > _freeMonths ? points.length - _freeMonths : 0);
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
              isSpanish ? 'Sin datos registrados aún' : 'No data recorded yet',
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

    final barWidth = isPremium
        ? CalcwiseChartTokens.barWidth
        : CalcwiseChartTokens.barWidthTouched;

    // Accessibility: build summary label
    final _totalIncome = displayPoints.fold<double>(0, (s, p) => s + p.income);
    final _totalExpenses =
        displayPoints.fold<double>(0, (s, p) => s + p.expenses);
    final _cashFlowLabel = isSpanish
        ? 'Tendencia de flujo de caja: ingresos ${AmountFormatter.ui(_totalIncome, 'USD')}, '
            'gastos ${AmountFormatter.ui(_totalExpenses, 'USD')}'
        : 'Cash flow trend: income ${AmountFormatter.ui(_totalIncome, 'USD')}, '
            'expenses ${AmountFormatter.ui(_totalExpenses, 'USD')}';

    final barGroups = displayPoints.asMap().entries.map((entry) {
      final i = entry.key;
      final pt = entry.value;
      final cf = pt.cashFlow;
      final top = math.max(pt.income, pt.expenses);

      final stack = <BarChartRodStackItem>[];

      if (pt.expenses > 0 && pt.income > 0) {
        // Red portion = expenses
        stack.add(BarChartRodStackItem(0, pt.expenses, errorColor));
        if (cf > 0) {
          // Green portion = cash flow above expenses
          stack.add(
              BarChartRodStackItem(pt.expenses, pt.income, successColor));
        }
      } else if (pt.income > 0) {
        // Only rent, no expenses tracked → subtle green
        stack.add(BarChartRodStackItem(
            0, pt.income, successColor.withValues(alpha: 0.45)));
      } else if (pt.expenses > 0) {
        stack.add(BarChartRodStackItem(0, pt.expenses, errorColor));
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
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return Semantics(
      label: _cashFlowLabel,
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Legend row
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 12),
                child: Row(children: [
                  _LegendDot(color: successColor),
                  const SizedBox(width: 4),
                  Text(
                    isSpanish ? 'Flujo de caja' : 'Cash Flow',
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: theme.textSecondary),
                  ),
                  const SizedBox(width: 14),
                  _LegendDot(color: errorColor),
                  const SizedBox(width: 4),
                  Text(
                    isSpanish ? 'Gastos' : 'Expenses',
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: theme.textSecondary),
                  ),
                ]),
              ),

              // Chart
              LayoutBuilder(
                builder: (context, constraints) {
                  final chartHeight =
                      (constraints.maxWidth < 400) ? 185.0 : 220.0;
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
                                        fontSize: AppTextSize.xs,
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
                                final pt = displayPoints[i];
                                final lbl = labels[pt.month - 1];
                                // Mark January with year suffix to avoid
                                // ambiguity when the chart spans two years.
                                final suffix =
                                    pt.month == 1 ? "\n'${pt.year % 100}" : '';
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '$lbl$suffix',
                                    style: TextStyle(
                                        fontSize: AppTextSize.xs,
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
                              final pt = displayPoints[group.x];
                              final cf = pt.cashFlow;
                              final sign = cf >= 0 ? '+' : '-';
                              return BarTooltipItem(
                                '${labels[pt.month - 1]} ${pt.year}\n'
                                '${isSpanish ? "Alquiler" : "Rent"}: ${AmountFormatter.ui(pt.income, 'USD')}\n'
                                '${isSpanish ? "Gastos" : "Expenses"}: ${AmountFormatter.ui(pt.expenses, 'USD')}\n'
                                '${isSpanish ? "Flujo" : "Cash Flow"}: $sign${AmountFormatter.ui(cf.abs(), 'USD')}',
                                const TextStyle(
                                    color: Colors.white,
                                    fontSize: AppTextSize.xs),
                              );
                            },
                          ),
                        ),
                      ),
                      swapAnimationDuration: CalcwiseChartTokens.swapDuration,
                    ),
                  );
                },
              ),

              // Free-tier upsell banner
              if (isLimited) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceTint,
                    borderRadius: BorderRadius.circular(AppRadius.mdPlus),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.20)),
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
                            fontSize: AppTextSize.xs,
                            color: theme.textSecondary),
                      ),
                    ),
                    TextButton(
                      onPressed: () => PaywallSoft.show(outerCtx),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        isSpanish ? 'Desbloquear' : 'Unlock',
                        style: const TextStyle(
                            fontSize: AppTextSize.xs,
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
      ), // Card
    ); // Semantics
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

// ── Dashed legend line painter ────────────────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  final Color color;
  const _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashLen = 4.0;
    const gapLen = 2.0;
    double x = 0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + dashLen).clamp(0, size.width), y), paint);
      x += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
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
            Icon(Icons.bar_chart_rounded,
                size: 72,
                color: CalcwiseTheme.of(context)
                    .textSecondary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              isSpanish ? 'Sin propiedades aún' : 'No properties yet',
              style: const TextStyle(
                  fontSize: AppTextSize.subtitle, fontWeight: FontWeight.w600),
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

// ---------------------------------------------------------------------------
// Skeleton loading placeholder for ReportsScreen
// ---------------------------------------------------------------------------
class _ReportsSkeleton extends StatefulWidget {
  const _ReportsSkeleton();
  @override
  State<_ReportsSkeleton> createState() => _ReportsSkeletonState();
}

class _ReportsSkeletonState extends State<_ReportsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _shimmer({double? width, required double height}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final shine = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Color.lerp(base, shine, _anim.value),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month picker chip placeholder
          _shimmer(width: 160, height: 36),
          const SizedBox(height: AppSpacing.xl),
          // Summary card placeholder
          _shimmer(height: 120),
          const SizedBox(height: AppSpacing.xl),
          // Chart placeholder
          _shimmer(width: 140, height: 14),
          const SizedBox(height: AppSpacing.md),
          _shimmer(height: 220),
          const SizedBox(height: AppSpacing.xl),
          // Property rows
          for (int i = 0; i < 3; i++) ...[
            _shimmer(height: 64),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}
