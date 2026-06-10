import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../screens/calculator_screen.dart';
import '../widgets/paywall_soft.dart';

/// Read-only detail view for a saved expense calculation from history.
class HistoryDetailScreen extends StatefulWidget {
  final ExpenseCalc calc;

  const HistoryDetailScreen({super.key, required this.calc});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('history_detail');
  }

  Future<void> _exportPdf(bool isPremium, bool isSpanish) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    if (!isPremium) {
      await PaywallSoft.show(context);
      return;
    }
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final c = widget.calc;
      final dateFmt = DateFormat('MMMM d, yyyy');
      final cf = c.monthlyCashFlow;
      final cfSign = cf >= 0 ? '+' : '-';

      final doc = pw.Document();
      const green = PdfColor.fromInt(0xFF16A34A);
      const red = PdfColor.fromInt(0xFFDC2626);
      const gray = PdfColor.fromInt(0xFF64748B);
      const light = PdfColor.fromInt(0xFFF1F5F9);

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const pw.BoxDecoration(color: green),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    c.propertyName.isNotEmpty
                        ? c.propertyName
                        : s.myProperty,
                    style: pw.TextStyle(
                      fontSize: AppTextSize.subtitle,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${s.savedLabel}: ${dateFmt.format(c.savedAt)}',
                    style: const pw.TextStyle(
                        fontSize: AppTextSize.xs, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // ── Cash-flow hero row ────────────────────────────────────────
            pw.Row(children: [
              _pdfMetric(
                label: s.monthlyCashFlow,
                value: '$cfSign${AmountFormatter.ui(cf.abs(), 'USD')}',
                color: cf >= 0 ? green : red,
              ),
              pw.SizedBox(width: 12),
              _pdfMetric(
                label: s.annualCashFlow,
                value:
                    '${c.annualCashFlow >= 0 ? '+' : '-'}${AmountFormatter.ui(c.annualCashFlow.abs(), 'USD')}',
                color: c.annualCashFlow >= 0 ? green : red,
              ),
              pw.SizedBox(width: 12),
              _pdfMetric(
                label: 'NOI',
                value: '${c.noi >= 0 ? '+' : '-'}${AmountFormatter.ui(c.noi.abs(), 'USD')}',
                color: c.noi >= 0 ? green : red,
              ),
            ]),
            pw.SizedBox(height: 18),

            // ── Income / Expenses table ───────────────────────────────────
            pw.Text(
              s.breakdown,
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: AppTextSize.md,
                  color: gray),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [s.category, s.amount],
              data: [
                [s.monthlyRent, AmountFormatter.ui(c.rentIncome, 'USD')],
                if (c.mortgage > 0)
                  [s.mortgage, AmountFormatter.ui(c.mortgage, 'USD')],
                if (c.propertyTaxes > 0)
                  [s.propertyTaxesLabel, AmountFormatter.ui(c.propertyTaxes, 'USD')],
                if (c.insurance > 0)
                  [s.insurance, AmountFormatter.ui(c.insurance, 'USD')],
                if (c.hoaFees > 0) ['HOA', AmountFormatter.ui(c.hoaFees, 'USD')],
                if (c.propertyMgmt > 0)
                  [s.administration, AmountFormatter.ui(c.propertyMgmt, 'USD')],
                if (c.maintenance > 0)
                  [s.maintenance, AmountFormatter.ui(c.maintenance, 'USD')],
                if (c.vacancyLoss > 0)
                  [s.vacancy, AmountFormatter.ui(c.vacancyLoss, 'USD')],
                if (c.utilities > 0)
                  [s.utilities, AmountFormatter.ui(c.utilities, 'USD')],
                if (c.landscaping > 0)
                  [s.landscapingLabel, AmountFormatter.ui(c.landscaping, 'USD')],
                if (c.otherExpenses > 0)
                  [s.other, AmountFormatter.ui(c.otherExpenses, 'USD')],
                [s.totalExpenses, AmountFormatter.ui(c.totalExpenses, 'USD')],
              ],
              border: pw.TableBorder.all(color: PdfColors.grey300),
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: AppTextSize.xs),
              cellStyle: const pw.TextStyle(fontSize: AppTextSize.xs),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColor.fromInt(0xFFECFDF5)),
              cellHeight: 22,
              oddRowDecoration: const pw.BoxDecoration(color: light),
            ),
            pw.SizedBox(height: 16),

            // ── Investor metrics (if available) ───────────────────────────
            if (c.capRate != null || c.cocRoi != null) ...[
              pw.Text(
                s.investmentMetrics,
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: AppTextSize.md,
                    color: gray),
              ),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                if (c.capRate != null) ...[
                  _pdfMetric(
                    label: 'Cap Rate',
                    value: '${c.capRate!.toStringAsFixed(2)}%',
                    color: c.capRate! >= 6 ? green : red,
                  ),
                  pw.SizedBox(width: 12),
                ],
                if (c.grossYield != null) ...[
                  _pdfMetric(
                    label: s.grossYield,
                    value: '${c.grossYield!.toStringAsFixed(2)}%',
                    color: c.grossYield! >= 8 ? green : red,
                  ),
                  pw.SizedBox(width: 12),
                ],
                if (c.cocRoi != null)
                  _pdfMetric(
                    label: 'CoC ROI',
                    value: '${c.cocRoi!.toStringAsFixed(2)}%',
                    color: c.cocRoi! >= 8 ? green : red,
                  ),
              ]),
              pw.SizedBox(height: 12),
            ],

            pw.Spacer(),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 4),
            pw.Text(
              'Rental Expenses Tracker — ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
      ));

      await AnalyticsService.instance.logPdfExported();
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename:
            '${c.propertyName.isEmpty ? "rental" : c.propertyName.replaceAll(' ', '_')}_expense.pdf',
      );
    } catch (e) {
      if (mounted) {
        final s2 = isSpanishNotifier.value ? const AppStringsEs() : const AppStringsEn();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s2.pdfExportFailed),
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// Small metric box for PDF layout.
  pw.Widget _pdfMetric({
    required String label,
    required String value,
    required PdfColor color,
  }) =>
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(AppRadius.sm),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(label,
                  style:
                      const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 4),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: AppTextSize.md,
                      fontWeight: pw.FontWeight.bold,
                      color: color),
                  textAlign: pw.TextAlign.center),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, yyyy — h:mm a');
    final c = widget.calc;
    final cfColor =
        c.monthlyCashFlow >= 0 ? AppTheme.success : AppTheme.dangerRed;

    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        return Scaffold(
          appBar: AppBar(
            title: Text(
              c.propertyName.isNotEmpty
                  ? c.propertyName
                  : s.calculationDetail,
            ),
            actions: [
              // Premium badge / upsell
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.hasFullAccessNotifier,
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
                    tooltip: s.goPremium,
                    onPressed: () => IAPService.instance.buy(),
                  );
                },
              ),
              // Share
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: s.share,
                onPressed: () => _share(context, isSpanish),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // ── Saved-at timestamp ──────────────────────────────
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 14,
                              color: CalcwiseTheme.of(context).textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            dateFmt.format(c.savedAt),
                            style: TextStyle(
                                fontSize: AppTextSize.md,
                                color: CalcwiseTheme.of(context).textSecondary),
                          ),
                        ],
                      ),
                    ),

                    // ── Cash-flow hero ──────────────────────────────────
                    _HeroCard(
                      label: s.monthlyCashFlow,
                      value:
                          '${c.monthlyCashFlow < 0 ? '-' : ''}${AmountFormatter.ui(c.monthlyCashFlow.abs(), 'USD')}',
                      color: cfColor,
                    ),
                    const SizedBox(height: 16),

                    // ── Income ──────────────────────────────────────────
                    _SectionCard(
                      title: s.income,
                      rows: [
                        _Row(
                          s.rentIncome,
                          AmountFormatter.ui(c.rentIncome, 'USD'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Expenses breakdown ──────────────────────────────
                    _SectionCard(
                      title: s.monthlyExpensesSection,
                      rows: [
                        if (c.mortgage > 0)
                          _Row(s.mortgage,
                              AmountFormatter.ui(c.mortgage, 'USD')),
                        if (c.propertyTaxes > 0)
                          _Row(s.propertyTaxesLabel,
                              AmountFormatter.ui(c.propertyTaxes, 'USD')),
                        if (c.insurance > 0)
                          _Row(s.insurance,
                              AmountFormatter.ui(c.insurance, 'USD')),
                        if (c.hoaFees > 0)
                          _Row('HOA', AmountFormatter.ui(c.hoaFees, 'USD')),
                        if (c.propertyMgmt > 0)
                          _Row(s.administration,
                              AmountFormatter.ui(c.propertyMgmt, 'USD')),
                        if (c.maintenance > 0)
                          _Row(s.maintenance,
                              AmountFormatter.ui(c.maintenance, 'USD')),
                        if (c.vacancyLoss > 0)
                          _Row(s.vacancy,
                              AmountFormatter.ui(c.vacancyLoss, 'USD')),
                        if (c.utilities > 0)
                          _Row(s.utilities,
                              AmountFormatter.ui(c.utilities, 'USD')),
                        if (c.landscaping > 0)
                          _Row(s.landscapingLabel,
                              AmountFormatter.ui(c.landscaping, 'USD')),
                        if (c.otherExpenses > 0)
                          _Row(s.other,
                              AmountFormatter.ui(c.otherExpenses, 'USD')),
                        _Row(
                          s.totalExpensesLabel,
                          AmountFormatter.ui(c.totalExpenses, 'USD'),
                          bold: true,
                          valueColor: AppTheme.dangerRed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Summary metrics ─────────────────────────────────
                    _SectionCard(
                      title: s.keyMetrics,
                      rows: [
                        _Row(
                          s.annualRent,
                          AmountFormatter.ui(c.rentIncome * 12, 'USD'),
                        ),
                        _Row(
                          s.annualExpenses,
                          AmountFormatter.ui(c.totalExpenses * 12, 'USD'),
                          valueColor: AppTheme.dangerRed,
                        ),
                        _Row(
                          s.annualCashFlow,
                          '${c.annualCashFlow < 0 ? '-' : ''}${AmountFormatter.ui(c.annualCashFlow.abs(), 'USD')}',
                          valueColor: cfColor,
                        ),
                        _Row(
                          s.expenseRatio,
                          '${c.expenseRatio.toStringAsFixed(1)}%',
                          valueColor: c.expenseRatio < 70
                              ? AppTheme.success
                              : c.expenseRatio < 90
                                  ? AppTheme.warning
                                  : AppTheme.dangerRed,
                        ),
                        _Row(
                          s.breakEvenRentLabel,
                          '${AmountFormatter.ui(c.breakEvenRent, 'USD')}/mo',
                        ),
                        _Row(
                          s.annualNOI,
                          '${c.noi < 0 ? '-' : ''}${AmountFormatter.ui(c.noi.abs(), 'USD')}',
                          valueColor: c.noi >= 0
                              ? AppTheme.success
                              : AppTheme.dangerRed,
                        ),
                      ],
                    ),

                    // ── Investor metrics (optional) ─────────────────────
                    if (c.capRate != null || c.cocRoi != null) ...[
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: s.investmentMetrics,
                        rows: [
                          if (c.capRate != null)
                            _Row(
                              'Cap Rate',
                              '${c.capRate!.toStringAsFixed(2)}%',
                              valueColor: c.capRate! >= 6
                                  ? AppTheme.success
                                  : c.capRate! >= 4
                                      ? AppTheme.warning
                                      : AppTheme.dangerRed,
                            ),
                          if (c.grossYield != null)
                            _Row(
                              s.grossYield,
                              '${c.grossYield!.toStringAsFixed(2)}%',
                              valueColor: c.grossYield! >= 8
                                  ? AppTheme.success
                                  : AppTheme.warning,
                            ),
                          if (c.cocRoi != null)
                            _Row(
                              'Cash-on-Cash ROI',
                              '${c.cocRoi!.toStringAsFixed(2)}%',
                              valueColor: c.cocRoi! >= 8
                                  ? AppTheme.success
                                  : c.cocRoi! >= 4
                                      ? AppTheme.warning
                                      : AppTheme.dangerRed,
                            ),
                          _Row(
                            s.capRateGood,
                            s.cocRoiExcellent,
                            valueColor: CalcwiseTheme.of(context).textSecondary,
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // PDF export button
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.hasFullAccessNotifier,
                builder: (_, isPremium, __) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: isPremium ? AppTheme.primary : CalcwiseTheme.of(context).surfaceHigh,
                            foregroundColor: isPremium ? Colors.white : CalcwiseTheme.of(context).textSecondary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                            side: isPremium ? BorderSide.none : BorderSide(color: CalcwiseTheme.of(context).cardBorder),
                          ),
                          icon: Icon(isPremium ? Icons.picture_as_pdf_rounded : Icons.lock_rounded, size: 20),
                          label: Text(
                            s.exportPdf,
                            style: const TextStyle(fontSize: AppTextSize.body, fontWeight: FontWeight.w600),
                          ),
                          onPressed: _exporting
                              ? null
                              : () => _exportPdf(isPremium, isSpanish),
                        ),
                      ),
                    ),
                    if (!isPremium) const CalcwiseAdFooter(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _share(BuildContext context, bool isSpanish) {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final c = widget.calc;
    final name = c.propertyName.isNotEmpty ? c.propertyName : s.myProperty;
    final cf =
        '${c.monthlyCashFlow < 0 ? '-' : ''}${AmountFormatter.ui(c.monthlyCashFlow.abs(), 'USD')}';
    final text = [
      s.shareTitle(name),
      s.shareMonthlyRent(AmountFormatter.ui(c.rentIncome, 'USD')),
      s.shareTotalExpenses(AmountFormatter.ui(c.totalExpenses, 'USD')),
      s.shareMonthlyCashFlow(c.monthlyCashFlow < 0 ? '-' : '', AmountFormatter.ui(c.monthlyCashFlow.abs(), 'USD')),
      s.shareAnnualCashFlow(c.annualCashFlow < 0 ? '-' : '', AmountFormatter.ui(c.annualCashFlow.abs(), 'USD')),
      s.shareAnnualNOI(AmountFormatter.ui(c.noi, 'USD')),
      '',
      s.shareCalculatedWith,
      '',
      s.shareExportPdfCTA,
    ].join('\n');

    Share.share(text, subject: s.shareTitle(name));
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _HeroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: AppTextSize.body,
                  color: CalcwiseTheme.of(context).textSecondary)),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: AppTextSize.displayLg,
                  fontWeight: FontWeight.bold,
                  color: color)),
          const SizedBox(height: 4),
          Text('/mo',
              style: TextStyle(
                  fontSize: AppTextSize.md,
                  color: CalcwiseTheme.of(context).textSecondary)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<_Row> rows;

  const _SectionCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: AppTextSize.md,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary)),
            const SizedBox(height: 10),
            ...rows.map((r) => _RowWidget(row: r)),
          ],
        ),
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _Row(this.label, this.value, {this.valueColor, this.bold = false});
}

class _RowWidget extends StatelessWidget {
  final _Row row;
  const _RowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(row.label,
                style: TextStyle(
                    fontSize: AppTextSize.body,
                    color: CalcwiseTheme.of(context).textSecondary)),
          ),
          const SizedBox(width: 12),
          Text(
            row.value,
            style: TextStyle(
              fontSize: AppTextSize.body,
              fontWeight: row.bold ? FontWeight.bold : FontWeight.w600,
              color: row.valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
