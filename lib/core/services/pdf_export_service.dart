import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../freemium/iap_service.dart';
import '../theme/app_theme.dart';
import '../../main.dart';
import 'package:calcwise_core/calcwise_core.dart';

const _orange = PdfColor(0.863, 0.439, 0.039); // RentalExpenses orange
const _navy = PdfColor(0.059, 0.200, 0.353);
const _light = PdfColor(0.996, 0.957, 0.922);

class PdfExportService {
  static final _cur2 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
  static final _cur0 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
  static final _date = DateFormat('MMMM d, yyyy');
  static Future<void> exportReport({
    required BuildContext context,
    required String propertyName,
    required double monthlyRent,
    required double annualRent,
    required List<Map<String, dynamic>> expenses, // {name, monthly}
    required double totalMonthlyExpenses,
    required double netMonthlyIncome,
    required double netAnnualIncome,
    required double expenseRatio,
    double? noi,
    double? capRate,
    double? cashOnCashRoi,
    bool isSpanish = false,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      build: (_) => _buildPage(
        propertyName: propertyName,
        monthlyRent: monthlyRent,
        annualRent: annualRent,
        expenses: expenses,
        totalMonthlyExpenses: totalMonthlyExpenses,
        netMonthlyIncome: netMonthlyIncome,
        netAnnualIncome: netAnnualIncome,
        expenseRatio: expenseRatio,
        noi: noi,
        capRate: capRate,
        cashOnCashRoi: cashOnCashRoi,
        isSpanish: isSpanish,
      ),
    ));
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'RentalExpenses_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildPage({
    required String propertyName,
    required double monthlyRent,
    required double annualRent,
    required List<Map<String, dynamic>> expenses,
    required double totalMonthlyExpenses,
    required double netMonthlyIncome,
    required double netAnnualIncome,
    required double expenseRatio,
    double? noi,
    double? capRate,
    double? cashOnCashRoi,
    bool isSpanish = false,
  }) {
    final now = DateTime.now();
    return pw
        .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                      isSpanish
                          ? 'Calculadora de Gastos de Alquiler'
                          : 'Rental Expenses Calculator',
                      style: pw.TextStyle(
                          fontSize: AppTextSize.title,
                          fontWeight: pw.FontWeight.bold,
                          color: _orange)),
                  pw.Text(
                      propertyName.isNotEmpty
                          ? propertyName
                          : (isSpanish
                              ? 'Informe de Gastos de Propiedad'
                              : 'Property Expense Report'),
                      style: const pw.TextStyle(
                          fontSize: AppTextSize.xs, color: PdfColors.grey700)),
                ]),
            pw.Text(_date.format(now),
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
      pw.Container(
          height: 2,
          color: _orange,
          margin: const pw.EdgeInsets.only(top: 6, bottom: 14)),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
            child: pw.Column(children: [
          _sectionBox(isSpanish ? 'INGRESOS' : 'INCOME', [
            _row2(isSpanish ? 'Alquiler mensual' : 'Monthly Rent',
                _cur0.format(monthlyRent)),
            _row2(isSpanish ? 'Alquiler anual' : 'Annual Rent',
                _cur0.format(annualRent),
                bold: true, color: _navy),
          ]),
          pw.SizedBox(height: 10),
          _sectionBox(isSpanish ? 'INGRESOS NETOS' : 'NET INCOME', [
            _row2(isSpanish ? 'Neto mensual' : 'Monthly Net',
                _cur0.format(netMonthlyIncome),
                bold: true,
                color: netMonthlyIncome >= 0 ? _navy : PdfColors.red700),
            _row2(isSpanish ? 'Neto anual' : 'Annual Net',
                _cur0.format(netAnnualIncome),
                bold: true,
                color: netAnnualIncome >= 0 ? _navy : PdfColors.red700),
            _row2(isSpanish ? 'Ratio de gastos' : 'Expense Ratio',
                '${(expenseRatio * 100).toStringAsFixed(1)}%'),
            if (noi != null)
              _row2('NOI', _cur0.format(noi),
                  bold: true,
                  color: noi >= 0 ? _navy : PdfColors.red700),
          ]),
          if (capRate != null || cashOnCashRoi != null) ...[
            pw.SizedBox(height: 10),
            _sectionBox(
                isSpanish ? 'MÉTRICAS DE INVERSIÓN' : 'INVESTMENT METRICS', [
              if (capRate != null)
                _row2('Cap Rate', '${capRate.toStringAsFixed(2)}%',
                    bold: true,
                    color: capRate >= 6 ? _navy : PdfColors.red700),
              if (cashOnCashRoi != null)
                _row2(
                    isSpanish ? 'ROI (Cash-on-Cash)' : 'Cash-on-Cash ROI',
                    '${cashOnCashRoi.toStringAsFixed(2)}%',
                    bold: true,
                    color: cashOnCashRoi >= 8 ? _navy : PdfColors.red700),
            ]),
          ],
        ])),
        pw.SizedBox(width: 14),
        pw.Expanded(
            child: pw.Column(children: [
          _sectionBox(
              isSpanish ? 'GASTOS MENSUALES' : 'MONTHLY EXPENSES', [
            ...expenses.map(
                (e) => _row2(e['name'] as String, _cur2.format(e['monthly']))),
            pw.Divider(color: PdfColors.grey300, height: 6),
            _row2(isSpanish ? 'Total de gastos' : 'Total Expenses',
                _cur0.format(totalMonthlyExpenses),
                bold: true, color: _orange),
          ]),
        ])),
      ]),
      pw.SizedBox(height: 14),
      _buildIncomeChart(
        monthlyRent: monthlyRent,
        totalMonthlyExpenses: totalMonthlyExpenses,
        netMonthlyIncome: netMonthlyIncome,
        isSpanish: isSpanish,
      ),
      pw.Spacer(),
      pw.Column(children: [
        pw.Divider(color: PdfColors.grey300, height: 12),
        pw.Text(
            isSpanish
                ? 'Generado por Rental Expenses Calculator · Solo para ilustración. No es consejo financiero.'
                : 'Generated by Rental Expenses Calculator · For illustration purposes only. Not financial advice.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
      ]),
    ]);
  }

  // ── Income Breakdown donut chart ──────────────────────────────────────────

  static const _green = PdfColor(0.133, 0.545, 0.133);      // gross revenue
  static const _red = PdfColor(0.780, 0.118, 0.118);        // expenses
  static const _darkGreen = PdfColor(0.047, 0.365, 0.047);  // net income

  static pw.Widget _buildIncomeChart({
    required double monthlyRent,
    required double totalMonthlyExpenses,
    required double netMonthlyIncome,
    required bool isSpanish,
  }) {
    final chartTitle =
        isSpanish ? 'Répartition des revenus' : 'Income Breakdown';

    final grossVal = monthlyRent.clamp(0.0, double.infinity);
    final expVal = totalMonthlyExpenses.clamp(0.0, double.infinity);
    final netVal = netMonthlyIncome.clamp(0.0, double.infinity);
    final total = grossVal + expVal + netVal;

    // Guard: nothing to show
    if (total < 0.01) return pw.SizedBox();

    // Compute the donut inner radius in absolute points (90pt chart = 45pt
    // nominal radius; inner ring = 55% of radius).
    const chartSize = 90.0;
    const innerR = chartSize / 2 * 0.55;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _navy,
          child: pw.Text(
            chartTitle,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Donut chart — one PieDataSet per slice
              pw.SizedBox(
                width: chartSize,
                height: chartSize,
                child: pw.Chart(
                  grid: pw.PieGrid(),
                  datasets: [
                    pw.PieDataSet(
                      value: grossVal,
                      color: _green,
                      legendPosition: pw.PieLegendPosition.none,
                      borderWidth: 1,
                      borderColor: PdfColors.white,
                      innerRadius: innerR,
                    ),
                    pw.PieDataSet(
                      value: expVal > 0 ? expVal : 0.001,
                      color: _red,
                      legendPosition: pw.PieLegendPosition.none,
                      borderWidth: 1,
                      borderColor: PdfColors.white,
                      innerRadius: innerR,
                    ),
                    pw.PieDataSet(
                      value: netVal > 0 ? netVal : 0.001,
                      color: _darkGreen,
                      legendPosition: pw.PieLegendPosition.none,
                      borderWidth: 1,
                      borderColor: PdfColors.white,
                      innerRadius: innerR,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              // Manual legend
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _legendRow(
                    color: _green,
                    label: isSpanish ? 'Ingresos brutos' : 'Gross Revenue',
                    value: _cur0.format(monthlyRent),
                  ),
                  pw.SizedBox(height: 6),
                  _legendRow(
                    color: _red,
                    label:
                        isSpanish ? 'Total de gastos' : 'Total Expenses',
                    value: _cur0.format(totalMonthlyExpenses),
                  ),
                  pw.SizedBox(height: 6),
                  _legendRow(
                    color: _darkGreen,
                    label: isSpanish ? 'Ingreso neto' : 'Net Income',
                    value: _cur0.format(netMonthlyIncome),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _legendRow({
    required PdfColor color,
    required String label,
    required String value,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.Row(children: [
          pw.Container(
            width: 10,
            height: 10,
            decoration: pw.BoxDecoration(color: color),
          ),
          pw.SizedBox(width: 6),
          pw.Text(
            '$label: $value',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
          ),
        ]),
      );

  // ─────────────────────────────────────────────────────────────────────────────

  static pw.Widget _sectionBox(String title, List<pw.Widget> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              color: _navy,
              child: pw.Text(title,
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white))),
          pw.Container(
              padding: const pw.EdgeInsets.all(AppSpacing.sm),
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
              child: pw.Column(children: rows)),
        ],
      );

  static pw.Widget _row2(String label, String value,
          {bool bold = false, PdfColor? color}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey800)),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                      color: color ?? PdfColors.black)),
            ]),
      );

  static Future<void> showUnlockOrPay(
      BuildContext context, Future<void> Function() onExport) async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _PdfUnlockSheet(onExport: onExport),
    );
  }
}

class _PdfUnlockSheet extends StatefulWidget {
  final Future<void> Function() onExport;
  const _PdfUnlockSheet({required this.onExport});
  @override
  State<_PdfUnlockSheet> createState() => _PdfUnlockSheetState();
}

class _PdfUnlockSheetState extends State<_PdfUnlockSheet> {
  bool _loading = false;
  Future<void> _watchAd() async {
    setState(() => _loading = true);
    final earned = await adService.showRewarded();
    if (!mounted) return;
    setState(() => _loading = false);
    if (earned) {
      Navigator.pop(context);
      await widget.onExport();
    } else
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isSpanishNotifier.value
              ? 'Anuncio no disponible. Inténtalo más tarde.'
              : 'Ad not available. Try again later.')));
  }

  @override
  Widget build(BuildContext context) {
    final adReady = adService.isRewardedReady;
    final isEs = isSpanishNotifier.value;
    return Padding(
      padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 28),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 20),
        const Icon(Icons.picture_as_pdf_rounded,
            size: 36, color: AppTheme.primary),
        const SizedBox(height: 12),
        Text(isEs ? 'Exportar Informe PDF' : 'Export PDF Report',
            style: const TextStyle(
                fontSize: AppTextSize.subtitle, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
            isEs
                ? 'Elige cómo desbloquear la exportación'
                : 'Choose how to unlock PDF export',
            style: const TextStyle(
                fontSize: AppTextSize.md, color: Color(0xFF475569))),
        const SizedBox(height: 24),
        Opacity(
            opacity: adReady ? 1.0 : 0.45,
            child: InkWell(
                onTap: (adReady && !_loading) ? _watchAd : null,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(AppRadius.xl)),
                  child: Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.play_circle_outline,
                            color: AppTheme.primary, size: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              isEs
                                  ? 'Ver un video corto'
                                  : 'Watch a short video',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppTextSize.bodyMd)),
                          const SizedBox(height: 2),
                          Text(
                              isEs
                                  ? 'Exportar una vez — gratis'
                                  : 'Export once — free',
                              style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: AppTextSize.md)),
                        ])),
                    if (_loading)
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      const Icon(Icons.chevron_right_rounded,
                          color: AppTheme.labelGray),
                  ]),
                ))),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                IAPService.instance.buy();
              },
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: Text(
                  isEs
                      ? 'Premium (ilimitado)'
                      : 'Premium (unlimited)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl))),
            )),
        const SizedBox(height: 10),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isEs ? 'Ahora no' : 'Not now',
                style: const TextStyle(color: Color(0xFF64748B)))),
      ]),
    );
  }
}
