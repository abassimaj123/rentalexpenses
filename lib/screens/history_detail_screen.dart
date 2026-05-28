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

  Future<void> _exportPdf(bool isPremium, bool isSpanish) async {
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
                        : (isSpanish ? 'Mi Propiedad' : 'My Property'),
                    style: pw.TextStyle(
                      fontSize: AppTextSize.subtitle,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${isSpanish ? "Guardado" : "Saved"}: ${dateFmt.format(c.savedAt)}',
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
                label: isSpanish ? 'Flujo mensual' : 'Monthly Cash Flow',
                value: '$cfSign${AmountFormatter.ui(cf.abs(), 'USD')}',
                color: cf >= 0 ? green : red,
              ),
              pw.SizedBox(width: 12),
              _pdfMetric(
                label: isSpanish ? 'Flujo anual' : 'Annual Cash Flow',
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
              isSpanish ? 'Desglose' : 'Breakdown',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: AppTextSize.md,
                  color: gray),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: [
                isSpanish ? 'Categoría' : 'Category',
                isSpanish ? 'Monto' : 'Amount',
              ],
              data: [
                [
                  isSpanish ? 'Alquiler mensual' : 'Monthly Rent',
                  AmountFormatter.ui(c.rentIncome, 'USD')
                ],
                if (c.mortgage > 0)
                  [
                    isSpanish ? 'Hipoteca' : 'Mortgage',
                    AmountFormatter.ui(c.mortgage, 'USD')
                  ],
                if (c.propertyTaxes > 0)
                  [
                    isSpanish ? 'Impuestos' : 'Property Taxes',
                    AmountFormatter.ui(c.propertyTaxes, 'USD')
                  ],
                if (c.insurance > 0)
                  [
                    isSpanish ? 'Seguro' : 'Insurance',
                    AmountFormatter.ui(c.insurance, 'USD')
                  ],
                if (c.hoaFees > 0) ['HOA', AmountFormatter.ui(c.hoaFees, 'USD')],
                if (c.propertyMgmt > 0)
                  [
                    isSpanish ? 'Administración' : 'Property Mgmt',
                    AmountFormatter.ui(c.propertyMgmt, 'USD')
                  ],
                if (c.maintenance > 0)
                  [
                    isSpanish ? 'Mantenimiento' : 'Maintenance',
                    AmountFormatter.ui(c.maintenance, 'USD')
                  ],
                if (c.vacancyLoss > 0)
                  [
                    isSpanish ? 'Vacancia' : 'Vacancy',
                    AmountFormatter.ui(c.vacancyLoss, 'USD')
                  ],
                if (c.utilities > 0)
                  [
                    isSpanish ? 'Servicios' : 'Utilities',
                    AmountFormatter.ui(c.utilities, 'USD')
                  ],
                if (c.landscaping > 0)
                  [
                    isSpanish ? 'Jardinería' : 'Landscaping',
                    AmountFormatter.ui(c.landscaping, 'USD')
                  ],
                if (c.otherExpenses > 0)
                  [
                    isSpanish ? 'Otros' : 'Other',
                    AmountFormatter.ui(c.otherExpenses, 'USD')
                  ],
                [
                  isSpanish ? 'TOTAL GASTOS' : 'TOTAL EXPENSES',
                  AmountFormatter.ui(c.totalExpenses, 'USD')
                ],
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
                isSpanish ? 'Métricas de Inversión' : 'Investment Metrics',
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
                    label: isSpanish ? 'Rend. bruto' : 'Gross Yield',
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isSpanishNotifier.value
              ? 'Error al exportar PDF'
              : 'PDF export failed'),
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
        return Scaffold(
          appBar: AppBar(
            title: Text(
              c.propertyName.isNotEmpty
                  ? c.propertyName
                  : (isSpanish ? 'Detalle de cálculo' : 'Calculation Detail'),
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
                    tooltip: isSpanish ? 'Obtener Premium' : 'Go Premium',
                    onPressed: () => IAPService.instance.buy(),
                  );
                },
              ),
              // Share
              IconButton(
                icon: const Icon(Icons.share_rounded),
                tooltip: isSpanish ? 'Compartir' : 'Share',
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
                      label: isSpanish
                          ? 'Flujo de caja mensual'
                          : 'Monthly Cash Flow',
                      value:
                          '${c.monthlyCashFlow < 0 ? '-' : ''}${AmountFormatter.ui(c.monthlyCashFlow.abs(), 'USD')}',
                      color: cfColor,
                    ),
                    const SizedBox(height: 16),

                    // ── Income ──────────────────────────────────────────
                    _SectionCard(
                      title: isSpanish ? 'Ingresos' : 'Income',
                      rows: [
                        _Row(
                          isSpanish ? 'Ingreso por renta' : 'Rent Income',
                          AmountFormatter.ui(c.rentIncome, 'USD'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Expenses breakdown ──────────────────────────────
                    _SectionCard(
                      title:
                          isSpanish ? 'Gastos mensuales' : 'Monthly Expenses',
                      rows: [
                        if (c.mortgage > 0)
                          _Row(isSpanish ? 'Hipoteca' : 'Mortgage',
                              AmountFormatter.ui(c.mortgage, 'USD')),
                        if (c.propertyTaxes > 0)
                          _Row(
                              isSpanish ? 'Impuesto predial' : 'Property Taxes',
                              AmountFormatter.ui(c.propertyTaxes, 'USD')),
                        if (c.insurance > 0)
                          _Row(isSpanish ? 'Seguro' : 'Insurance',
                              AmountFormatter.ui(c.insurance, 'USD')),
                        if (c.hoaFees > 0)
                          _Row('HOA', AmountFormatter.ui(c.hoaFees, 'USD')),
                        if (c.propertyMgmt > 0)
                          _Row(isSpanish ? 'Administración' : 'Property Mgmt',
                              AmountFormatter.ui(c.propertyMgmt, 'USD')),
                        if (c.maintenance > 0)
                          _Row(isSpanish ? 'Mantenimiento' : 'Maintenance',
                              AmountFormatter.ui(c.maintenance, 'USD')),
                        if (c.vacancyLoss > 0)
                          _Row(isSpanish ? 'Vacancia' : 'Vacancy Loss',
                              AmountFormatter.ui(c.vacancyLoss, 'USD')),
                        if (c.utilities > 0)
                          _Row(isSpanish ? 'Servicios' : 'Utilities',
                              AmountFormatter.ui(c.utilities, 'USD')),
                        if (c.landscaping > 0)
                          _Row(isSpanish ? 'Jardinería' : 'Landscaping',
                              AmountFormatter.ui(c.landscaping, 'USD')),
                        if (c.otherExpenses > 0)
                          _Row(isSpanish ? 'Otros gastos' : 'Other Expenses',
                              AmountFormatter.ui(c.otherExpenses, 'USD')),
                        _Row(
                          isSpanish ? 'Total gastos' : 'Total Expenses',
                          AmountFormatter.ui(c.totalExpenses, 'USD'),
                          bold: true,
                          valueColor: AppTheme.dangerRed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Summary metrics ─────────────────────────────────
                    _SectionCard(
                      title: isSpanish ? 'Métricas clave' : 'Key Metrics',
                      rows: [
                        _Row(
                          isSpanish ? 'Flujo anual' : 'Annual Cash Flow',
                          '${c.annualCashFlow < 0 ? '-' : ''}${AmountFormatter.ui(c.annualCashFlow.abs(), 'USD')}',
                          valueColor: cfColor,
                        ),
                        _Row(
                          isSpanish ? 'Ratio de gastos' : 'Expense Ratio',
                          '${c.expenseRatio.toStringAsFixed(1)}%',
                          valueColor: c.expenseRatio < 70
                              ? AppTheme.success
                              : c.expenseRatio < 90
                                  ? AppTheme.warning
                                  : AppTheme.dangerRed,
                        ),
                        _Row(
                          isSpanish ? 'Renta mínima' : 'Break-even Rent',
                          '${AmountFormatter.ui(c.breakEvenRent, 'USD')}/mo',
                        ),
                        _Row(
                          'NOI (anual)',
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
                        title: isSpanish
                            ? 'Métricas de Inversión'
                            : 'Investment Metrics',
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
                              isSpanish ? 'Rendimiento bruto' : 'Gross Yield',
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
                            isSpanish
                                ? 'Cap Rate > 6% = bueno'
                                : 'Cap Rate > 6% = good',
                            isSpanish
                                ? 'CoC ROI > 8% = excelente'
                                : 'CoC ROI > 8% = excellent',
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
                            isSpanish ? 'Exportar PDF' : 'Export PDF',
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
    final c = widget.calc;
    final name = c.propertyName.isNotEmpty
        ? c.propertyName
        : (isSpanish ? 'Mi propiedad' : 'My Property');
    final cf =
        '${c.monthlyCashFlow < 0 ? '-' : ''}${AmountFormatter.ui(c.monthlyCashFlow.abs(), 'USD')}';
    final text = isSpanish
        ? '$name\n'
            'Renta: ${AmountFormatter.ui(c.rentIncome, 'USD')}/mes\n'
            'Gastos: ${AmountFormatter.ui(c.totalExpenses, 'USD')}/mes\n'
            'Flujo mensual: $cf\n'
            'Flujo anual: ${AmountFormatter.ui(c.annualCashFlow, 'USD')}\n'
            'Ratio de gastos: ${c.expenseRatio.toStringAsFixed(1)}%\n'
            '\nRental Expenses Tracker\n\n'
            '📄 Exporta el reporte completo en PDF →'
        : '$name\n'
            'Rent: ${AmountFormatter.ui(c.rentIncome, 'USD')}/mo\n'
            'Expenses: ${AmountFormatter.ui(c.totalExpenses, 'USD')}/mo\n'
            'Monthly CF: $cf\n'
            'Annual CF: ${AmountFormatter.ui(c.annualCashFlow, 'USD')}\n'
            'Expense Ratio: ${c.expenseRatio.toStringAsFixed(1)}%\n'
            '\nRental Expenses Tracker\n\n'
            '📄 Export the full PDF report in the app →';

    Share.share(text,
        subject: isSpanish ? 'Cálculo — $name' : 'Calculation — $name');
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
