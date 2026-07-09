import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../freemium/iap_service.dart';
import '../freemium/freemium_service.dart';
import '../../widgets/paywall_hard.dart';
import '../theme/app_theme.dart';
import '../../l10n/strings_en.dart';
import '../../l10n/strings_es.dart';
import '../../main.dart';
import 'package:calcwise_core/calcwise_core.dart';

const _orange = PdfColor(0.863, 0.439, 0.039); // RentalExpenses orange
const _navy = PdfColor(0.059, 0.200, 0.353);
const _light = PdfColor(0.996, 0.957, 0.922);
const _green = PdfColor(0.133, 0.545, 0.133);
const _red = PdfColor(0.780, 0.118, 0.118);
const _darkGreen = PdfColor(0.047, 0.365, 0.047);

// ── Params classes (only sendable types: primitives, List, Map, Uint8List) ────

class _ReportParams {
  final String propertyName;
  final double monthlyRent;
  final double annualRent;
  final List<Map<String, dynamic>> expenses;
  final double totalMonthlyExpenses;
  final double netMonthlyIncome;
  final double netAnnualIncome;
  final double expenseRatio;
  final double? noi;
  final double? capRate;
  final double? cashOnCashRoi;
  final bool isSpanish;
  const _ReportParams({
    required this.propertyName,
    required this.monthlyRent,
    required this.annualRent,
    required this.expenses,
    required this.totalMonthlyExpenses,
    required this.netMonthlyIncome,
    required this.netAnnualIncome,
    required this.expenseRatio,
    this.noi,
    this.capRate,
    this.cashOnCashRoi,
    required this.isSpanish,
  });
}

class _ComparisonParams {
  final List<Map<String, dynamic>> properties;
  final int selectedMonthMs;
  final bool isSpanish;
  const _ComparisonParams({
    required this.properties,
    required this.selectedMonthMs,
    required this.isSpanish,
  });
}

class _DepreciationParams {
  final double purchasePrice;
  final double landValue;
  final double improvements;
  final double depreciableBasis;
  final double annualDepreciation;
  final double firstYearDepreciation;
  final int inServiceMonth;
  final int inServiceYear;
  final String propertyName;
  final bool isSpanish;
  const _DepreciationParams({
    required this.purchasePrice,
    required this.landValue,
    required this.improvements,
    required this.depreciableBasis,
    required this.annualDepreciation,
    required this.firstYearDepreciation,
    required this.inServiceMonth,
    required this.inServiceYear,
    required this.propertyName,
    required this.isSpanish,
  });
}

class _MileageParams {
  final String propertyName;
  final int year;
  final double totalMiles;
  final double rate;
  final double deduction;
  // trips serialized: {dateMs: int?, miles: double, purpose: String}
  final List<Map<String, dynamic>> trips;
  final bool isSpanish;
  const _MileageParams({
    required this.propertyName,
    required this.year,
    required this.totalMiles,
    required this.rate,
    required this.deduction,
    required this.trips,
    required this.isSpanish,
  });
}

// ── Shared PDF helpers (top-level so isolates can call them) ─────────────────

pw.Widget _sectionBox(String title, List<pw.Widget> rows) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

pw.Widget _row2(String label, String value,
        {bool bold = false, PdfColor? color}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label,
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
            pw.Text(value,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color ?? PdfColors.black)),
          ]),
    );

pw.Widget _legendRow({
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

pw.Widget _summaryTile(String label, String value, {bool highlight = false}) =>
    pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: highlight ? _navy : PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 7,
                  color: highlight ? PdfColors.grey300 : PdfColors.grey600),
              textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: highlight ? PdfColors.white : _navy),
              textAlign: pw.TextAlign.center),
        ],
      ),
    );

pw.Widget _buildIncomeChart({
  required double monthlyRent,
  required double totalMonthlyExpenses,
  required double netMonthlyIncome,
  required bool isSpanish,
}) {
  final cur0 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
  final chartTitle = isSpanish ? 'Distribución de ingresos' : 'Income Breakdown';

  final grossVal = monthlyRent.clamp(0.0, double.infinity);
  final expVal = totalMonthlyExpenses.clamp(0.0, double.infinity);
  final netVal = netMonthlyIncome.clamp(0.0, double.infinity);
  final total = grossVal + expVal + netVal;

  if (total < 0.01) return pw.SizedBox();

  const chartSize = 90.0;
  const innerR = chartSize / 2 * 0.55;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _navy,
        child: pw.Text(chartTitle,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white)),
      ),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
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
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _legendRow(
                  color: _green,
                  label: isSpanish ? 'Ingresos brutos' : 'Gross Revenue',
                  value: cur0.format(monthlyRent),
                ),
                pw.SizedBox(height: 6),
                _legendRow(
                  color: _red,
                  label: isSpanish ? 'Total de gastos' : 'Total Expenses',
                  value: cur0.format(totalMonthlyExpenses),
                ),
                pw.SizedBox(height: 6),
                _legendRow(
                  color: _darkGreen,
                  label: isSpanish ? 'Ingreso neto' : 'Net Income',
                  value: cur0.format(netMonthlyIncome),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

// ── Page builders (top-level so they run inside Isolate.run()) ────────────────

pw.Widget _buildReportPage(pw.Context ctx, _ReportParams p) {
  final now = DateTime.now();
  final cur2 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
  final cur0 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
  final dateFmt = DateFormat('MMMM d, yyyy', p.isSpanish ? 'es' : 'en');
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    p.isSpanish
                        ? 'Calculadora de Gastos de Alquiler'
                        : 'Rental Expenses Calculator',
                    style: pw.TextStyle(
                        fontSize: AppTextSize.title,
                        fontWeight: pw.FontWeight.bold,
                        color: _orange)),
                pw.Text(
                    p.propertyName.isNotEmpty
                        ? p.propertyName
                        : (p.isSpanish
                            ? 'Informe de Gastos de Propiedad'
                            : 'Property Expense Report'),
                    style: const pw.TextStyle(
                        fontSize: AppTextSize.xs, color: PdfColors.grey700)),
              ]),
          pw.Text(dateFmt.format(now),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
    pw.Container(
        height: 2,
        color: _orange,
        margin: const pw.EdgeInsets.only(top: 6, bottom: 14)),
    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(
          child: pw.Column(children: [
        _sectionBox(p.isSpanish ? 'INGRESOS' : 'INCOME', [
          _row2(p.isSpanish ? 'Alquiler mensual' : 'Monthly Rent',
              cur0.format(p.monthlyRent)),
          _row2(p.isSpanish ? 'Alquiler anual' : 'Annual Rent',
              cur0.format(p.annualRent),
              bold: true, color: _navy),
        ]),
        pw.SizedBox(height: 10),
        _sectionBox(p.isSpanish ? 'INGRESOS NETOS' : 'NET INCOME', [
          _row2(p.isSpanish ? 'Neto mensual' : 'Monthly Net',
              cur0.format(p.netMonthlyIncome),
              bold: true,
              color: p.netMonthlyIncome >= 0 ? _navy : PdfColors.red700),
          _row2(p.isSpanish ? 'Neto anual' : 'Annual Net',
              cur0.format(p.netAnnualIncome),
              bold: true,
              color: p.netAnnualIncome >= 0 ? _navy : PdfColors.red700),
          _row2(p.isSpanish ? 'Ratio de gastos' : 'Expense Ratio',
              '${(p.expenseRatio * 100).toStringAsFixed(1)}%'),
          if (p.noi != null)
            _row2('NOI', cur0.format(p.noi!),
                bold: true,
                color: p.noi! >= 0 ? _navy : PdfColors.red700),
        ]),
        if (p.capRate != null || p.cashOnCashRoi != null) ...[
          pw.SizedBox(height: 10),
          _sectionBox(
              p.isSpanish
                  ? 'MÉTRICAS DE INVERSIÓN'
                  : 'INVESTMENT METRICS', [
            if (p.capRate != null)
              _row2('Cap Rate', '${p.capRate!.toStringAsFixed(2)}%',
                  bold: true,
                  color: p.capRate! >= 6 ? _navy : PdfColors.red700),
            if (p.cashOnCashRoi != null)
              _row2(
                  p.isSpanish ? 'ROI (Cash-on-Cash)' : 'Cash-on-Cash ROI',
                  '${p.cashOnCashRoi!.toStringAsFixed(2)}%',
                  bold: true,
                  color: p.cashOnCashRoi! >= 8 ? _navy : PdfColors.red700),
          ]),
        ],
      ])),
      pw.SizedBox(width: 14),
      pw.Expanded(
          child: pw.Column(children: [
        _sectionBox(p.isSpanish ? 'GASTOS MENSUALES' : 'MONTHLY EXPENSES', [
          ...p.expenses.map(
              (e) => _row2(e['name'] as String, cur2.format(e['monthly']))),
          pw.Divider(color: PdfColors.grey300, height: 6),
          _row2(p.isSpanish ? 'Total de gastos' : 'Total Expenses',
              cur0.format(p.totalMonthlyExpenses),
              bold: true, color: _orange),
        ]),
      ])),
    ]),
    pw.SizedBox(height: 14),
    _buildIncomeChart(
      monthlyRent: p.monthlyRent,
      totalMonthlyExpenses: p.totalMonthlyExpenses,
      netMonthlyIncome: p.netMonthlyIncome,
      isSpanish: p.isSpanish,
    ),
    pw.Spacer(),
    PdfBrandHelper.footer(ctx, 'RentalExpenses'),
  ]);
}

List<pw.Widget> _comparisonMetricRow({
  required String label,
  required List<Map<String, dynamic>> properties,
  required String key,
  required bool isCurrency,
  required bool higherIsBetter,
  required int winnerIdx,
  required double colWidth,
  required NumberFormat cur0,
  bool isPercent = false,
  bool bold = false,
  bool highlightWinner = false,
  double multiplier = 1,
}) {
  return [
    pw.Row(children: [
      pw.SizedBox(
        width: 120,
        child: pw.Text(label,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ),
      ...List.generate(properties.length, (i) {
        final raw = ((properties[i][key] as double?) ?? 0) * multiplier;
        String formatted;
        if (isCurrency) {
          formatted = cur0.format(raw);
        } else if (isPercent) {
          formatted = '${raw.toStringAsFixed(1)}%';
        } else {
          formatted = raw.toStringAsFixed(2);
        }
        final isWinner = highlightWinner && i == winnerIdx;
        PdfColor valueColor;
        if (key == 'netIncome' || key == 'noi') {
          valueColor = raw >= 0 ? _navy : PdfColors.red700;
        } else if (key == 'expenseRatio') {
          valueColor = raw < 80 ? _navy : PdfColors.red700;
        } else {
          valueColor = PdfColors.black;
        }
        return pw.Container(
          width: colWidth,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          color: isWinner ? _light : null,
          child: pw.Text(
            formatted,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: valueColor),
            textAlign: pw.TextAlign.center,
          ),
        );
      }),
    ]),
    pw.Divider(color: PdfColors.grey200, height: 1),
  ];
}

pw.Widget _buildComparisonPage(pw.Context ctx, _ComparisonParams p) {
  final now = DateTime.now();
  final cur0 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
  final dateFmt = DateFormat('MMMM d, yyyy', p.isSpanish ? 'es' : 'en');
  final selectedMonth =
      DateTime.fromMillisecondsSinceEpoch(p.selectedMonthMs);
  final monthFmt = DateFormat('MMMM yyyy', p.isSpanish ? 'es' : 'en');

  int winnerIdx = 0;
  for (int i = 1; i < p.properties.length; i++) {
    final net = (p.properties[i]['netIncome'] as double?) ?? 0;
    final bestNet = (p.properties[winnerIdx]['netIncome'] as double?) ?? 0;
    if (net > bestNet) winnerIdx = i;
  }
  final colWidth =
      (PdfPageFormat.a4.availableWidth - 72) / p.properties.length;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    p.isSpanish
                        ? 'Comparación de Propiedades'
                        : 'Property Comparison',
                    style: pw.TextStyle(
                        fontSize: AppTextSize.title,
                        fontWeight: pw.FontWeight.bold,
                        color: _orange)),
                pw.Text(monthFmt.format(selectedMonth),
                    style: const pw.TextStyle(
                        fontSize: AppTextSize.xs, color: PdfColors.grey700)),
              ]),
          pw.Text(dateFmt.format(now),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
      pw.Container(
          height: 2,
          color: _orange,
          margin: const pw.EdgeInsets.only(top: 6, bottom: 14)),
      pw.Row(children: [
        pw.SizedBox(width: 120),
        ...List.generate(p.properties.length, (i) {
          final isWinner = i == winnerIdx;
          return pw.Container(
            width: colWidth,
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            color: isWinner ? _navy : PdfColors.grey200,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  p.properties[i]['name'] as String? ?? '',
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color:
                          isWinner ? PdfColors.white : PdfColors.grey800),
                  textAlign: pw.TextAlign.center,
                ),
                if ((p.properties[i]['address'] as String? ?? '').isNotEmpty)
                  pw.Text(
                    p.properties[i]['address'] as String,
                    style: pw.TextStyle(
                        fontSize: 7,
                        color: isWinner
                            ? PdfColors.grey200
                            : PdfColors.grey600),
                    textAlign: pw.TextAlign.center,
                  ),
                if (isWinner)
                  pw.Text(
                    p.isSpanish ? '★ GANADOR' : '★ WINNER',
                    style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: _orange),
                  ),
              ],
            ),
          );
        }),
      ]),
      pw.SizedBox(height: 2),
      ..._comparisonMetricRow(
        label: p.isSpanish ? 'Alquiler mensual' : 'Monthly Rent',
        properties: p.properties,
        key: 'rent',
        isCurrency: true,
        higherIsBetter: true,
        winnerIdx: winnerIdx,
        colWidth: colWidth,
        cur0: cur0,
      ),
      ..._comparisonMetricRow(
        label: p.isSpanish ? 'Total gastos' : 'Total Expenses',
        properties: p.properties,
        key: 'expenses',
        isCurrency: true,
        higherIsBetter: false,
        winnerIdx: winnerIdx,
        colWidth: colWidth,
        cur0: cur0,
      ),
      ..._comparisonMetricRow(
        label: p.isSpanish ? 'Flujo neto mensual' : 'Monthly Net Income',
        properties: p.properties,
        key: 'netIncome',
        isCurrency: true,
        higherIsBetter: true,
        winnerIdx: winnerIdx,
        colWidth: colWidth,
        bold: true,
        highlightWinner: true,
        cur0: cur0,
      ),
      ..._comparisonMetricRow(
        label: p.isSpanish ? 'Flujo neto anual' : 'Annual Net Income',
        properties: p.properties,
        key: 'netIncome',
        isCurrency: true,
        higherIsBetter: true,
        winnerIdx: winnerIdx,
        colWidth: colWidth,
        multiplier: 12,
        cur0: cur0,
      ),
      ..._comparisonMetricRow(
        label: p.isSpanish ? 'Ratio de gastos' : 'Expense Ratio',
        properties: p.properties,
        key: 'expenseRatio',
        isCurrency: false,
        isPercent: true,
        higherIsBetter: false,
        winnerIdx: winnerIdx,
        colWidth: colWidth,
        cur0: cur0,
      ),
      ..._comparisonMetricRow(
        label: 'NOI (${p.isSpanish ? 'anual' : 'annual'})',
        properties: p.properties,
        key: 'noi',
        isCurrency: true,
        higherIsBetter: true,
        winnerIdx: winnerIdx,
        colWidth: colWidth,
        cur0: cur0,
      ),
      pw.Spacer(),
      PdfBrandHelper.footer(ctx, 'RentalExpenses'),
    ],
  );
}

pw.Widget _buildDepreciationPage(pw.Context ctx, _DepreciationParams p) {
  final now = DateTime.now();
  final cur2 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
  final cur0 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 0);
  final dateFmt = DateFormat('MMMM d, yyyy', p.isSpanish ? 'es' : 'en');
  final monthNames = p.isSpanish
      ? const [
          'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
          'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
        ]
      : const [
          'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
  final monthLabel = monthNames[(p.inServiceMonth - 1).clamp(0, 11)];
  final checkpoints = [5, 10, 15, 20, 28];

  double cumAt(int years) {
    if (years <= 0) return 0;
    final full =
        p.firstYearDepreciation + p.annualDepreciation * (years - 1);
    return full > p.depreciableBasis ? p.depreciableBasis : full;
  }

  const taxRate = 0.24;
  final annualTaxSavings = p.annualDepreciation * taxRate;
  final firstYearTaxSavings = p.firstYearDepreciation * taxRate;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    p.isSpanish
                        ? 'Calculadora de Depreciación'
                        : 'Depreciation Calculator',
                    style: pw.TextStyle(
                        fontSize: AppTextSize.title,
                        fontWeight: pw.FontWeight.bold,
                        color: _orange)),
                pw.Text(
                    p.propertyName.isNotEmpty
                        ? p.propertyName
                        : 'MACRS GDS · 27.5 ${p.isSpanish ? 'años' : 'years'} · ${p.isSpanish ? 'Residencial' : 'Residential'}',
                    style: const pw.TextStyle(
                        fontSize: AppTextSize.xs,
                        color: PdfColors.grey700)),
              ]),
          pw.Text(dateFmt.format(now),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
      pw.Container(
          height: 2,
          color: _orange,
          margin: const pw.EdgeInsets.only(top: 6, bottom: 14)),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(
            child: pw.Column(children: [
          _sectionBox(p.isSpanish ? 'DATOS DE ENTRADA' : 'INPUT DATA', [
            _row2(p.isSpanish ? 'Precio de compra' : 'Purchase Price',
                cur0.format(p.purchasePrice)),
            _row2(p.isSpanish ? 'Valor del terreno' : 'Land Value',
                cur0.format(p.landValue)),
            if (p.improvements > 0)
              _row2(
                  p.isSpanish
                      ? 'Mejoras de capital'
                      : 'Capital Improvements',
                  cur0.format(p.improvements)),
            _row2(p.isSpanish ? 'Mes en servicio' : 'In-Service Month',
                '$monthLabel ${p.inServiceYear}'),
            _row2(p.isSpanish ? 'Método' : 'Method',
                p.isSpanish
                    ? 'Línea recta (MACRS GDS)'
                    : 'Straight-Line (MACRS GDS)'),
            _row2(p.isSpanish ? 'Período' : 'Recovery Period',
                p.isSpanish
                    ? '27.5 años (residencial)'
                    : '27.5 years (residential)'),
          ]),
          pw.SizedBox(height: 10),
          _sectionBox(p.isSpanish ? 'RESULTADO' : 'RESULT', [
            _row2(
                p.isSpanish ? 'Base depreciable' : 'Depreciable Basis',
                cur0.format(p.depreciableBasis)),
            _row2(
                p.isSpanish ? 'Depreciación anual' : 'Annual Depreciation',
                cur2.format(p.annualDepreciation),
                bold: true,
                color: _navy),
            pw.Divider(color: PdfColors.grey300, height: 6),
            _row2(
                p.isSpanish ? '1er año (mid-month)' : '1st Year (mid-month)',
                cur2.format(p.firstYearDepreciation),
                bold: true,
                color: _orange),
          ]),
        ])),
        pw.SizedBox(width: 14),
        pw.Expanded(
            child: pw.Column(children: [
          _sectionBox(
              p.isSpanish
                  ? 'DEPRECIACIÓN ACUMULADA'
                  : 'CUMULATIVE DEPRECIATION', [
            ...checkpoints.map((yr) {
              final cum = cumAt(yr);
              final label = yr == 28
                  ? p.isSpanish ? '27.5 años (total)' : '27.5 years (full)'
                  : '$yr ${p.isSpanish ? 'años' : 'years'}';
              return _row2(label, cur0.format(cum),
                  bold: yr == 28, color: yr == 28 ? _navy : null);
            }),
          ]),
          pw.SizedBox(height: 10),
          _sectionBox(
              p.isSpanish
                  ? 'AHORRO FISCAL ESTIMADO (24%)'
                  : 'EST. TAX SAVINGS (24% bracket)', [
            _row2(p.isSpanish ? 'Ahorro anual' : 'Annual Savings',
                cur2.format(annualTaxSavings),
                bold: true, color: _navy),
            _row2(p.isSpanish ? 'Ahorro 1er año' : '1st Year Savings',
                cur2.format(firstYearTaxSavings)),
            _row2(
                p.isSpanish
                    ? 'Ahorro total (27.5 años)'
                    : 'Total Savings (27.5 years)',
                cur0.format(p.depreciableBasis * taxRate)),
          ]),
        ])),
      ]),
      pw.Spacer(),
      PdfBrandHelper.footer(ctx, 'RentalExpenses'),
    ],
  );
}

pw.Widget _buildMileageHeader(_MileageParams p) {
  final cur2 =
      NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
  final dateFmt = DateFormat('MMMM d, yyyy', p.isSpanish ? 'es' : 'en');
  final now = DateTime.now();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                    p.isSpanish
                        ? 'Registro de Millaje de Negocios'
                        : 'Business Mileage Log',
                    style: pw.TextStyle(
                        fontSize: AppTextSize.title,
                        fontWeight: pw.FontWeight.bold,
                        color: _orange)),
                pw.Text(
                    p.propertyName.isNotEmpty
                        ? '${p.propertyName} · ${p.year}'
                        : '${p.year}',
                    style: const pw.TextStyle(
                        fontSize: AppTextSize.xs,
                        color: PdfColors.grey700)),
              ]),
          pw.Text(dateFmt.format(now),
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
      pw.Container(
          height: 2,
          color: _orange,
          margin: const pw.EdgeInsets.only(top: 6, bottom: 10)),
      pw.Row(children: [
        pw.Expanded(child: _summaryTile(
          p.isSpanish ? 'Total millas' : 'Total Miles',
          '${p.totalMiles.toStringAsFixed(1)} mi',
        )),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _summaryTile(
          p.isSpanish ? 'Tasa IRS ${p.year}' : 'IRS Rate ${p.year}',
          '\$${p.rate.toStringAsFixed(3)}/mi',
        )),
        pw.SizedBox(width: 8),
        pw.Expanded(child: _summaryTile(
          p.isSpanish ? 'Deducción' : 'Deduction',
          cur2.format(p.deduction),
          highlight: true,
        )),
      ]),
      pw.SizedBox(height: 10),
    ],
  );
}

pw.Widget _buildMileageBody(_MileageParams p) {
  // Deserialize dateMs back to DateTime
  final trips = p.trips.map((t) {
    final ms = t['dateMs'] as int?;
    return <String, dynamic>{
      ...t,
      'date': ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null,
    };
  }).toList();

  if (trips.isEmpty) {
    return pw.Center(
      child: pw.Text(
        p.isSpanish ? 'Sin trayectos registrados.' : 'No trips recorded.',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
      ),
    );
  }

  final Map<String, double> byCategory = {};
  for (final t in trips) {
    final purpose = (t['purpose'] as String? ?? '').trim();
    final cat =
        purpose.isNotEmpty ? purpose : (p.isSpanish ? 'Sin motivo' : 'No purpose');
    byCategory[cat] = (byCategory[cat] ?? 0) + ((t['miles'] as double?) ?? 0);
  }

  final dateFmt = DateFormat('yyyy-MM-dd');

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (byCategory.length > 1) ...[
        _sectionBox(p.isSpanish ? 'POR CATEGORÍA' : 'BY CATEGORY', [
          ...byCategory.entries
              .map((e) => _row2(e.key, '${e.value.toStringAsFixed(1)} mi')),
        ]),
        pw.SizedBox(height: 12),
      ],
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: _navy,
        child: pw.Row(children: [
          pw.SizedBox(
              width: 80,
              child: pw.Text(p.isSpanish ? 'Fecha' : 'Date',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white))),
          pw.SizedBox(width: 8),
          pw.Expanded(
              child: pw.Text(p.isSpanish ? 'Motivo' : 'Purpose',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white))),
          pw.SizedBox(width: 8),
          pw.SizedBox(
              width: 60,
              child: pw.Text(p.isSpanish ? 'Millas' : 'Miles',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white),
                  textAlign: pw.TextAlign.right)),
        ]),
      ),
      ...List.generate(trips.length, (i) {
        final t = trips[i];
        final tripDate = t['date'] as DateTime?;
        final miles = (t['miles'] as double?) ?? 0;
        final purpose = (t['purpose'] as String? ?? '').trim();
        final odd = i.isOdd;
        return pw.Container(
          color: odd ? _light : PdfColors.white,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 80,
                child: pw.Text(
                    tripDate != null ? dateFmt.format(tripDate) : '',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey800))),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: pw.Text(purpose.isNotEmpty ? purpose : '—',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey800))),
            pw.SizedBox(width: 8),
            pw.SizedBox(
                width: 60,
                child: pw.Text('${miles.toStringAsFixed(1)} mi',
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: _navy),
                    textAlign: pw.TextAlign.right)),
          ]),
        );
      }),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: PdfColors.grey200,
        child: pw.Row(children: [
          pw.Expanded(
              child: pw.Text(p.isSpanish ? 'TOTAL' : 'TOTAL',
                  style:
                      pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
          pw.Text(
              '${trips.fold<double>(0, (s, t) => s + ((t['miles'] as double?) ?? 0)).toStringAsFixed(1)} mi',
              style: pw.TextStyle(
                  fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy)),
        ]),
      ),
    ],
  );
}

// ── Top-level isolate entry points ────────────────────────────────────────────

Future<Uint8List> _buildReportPdf(_ReportParams p) async {
  await initializeDateFormatting();
  final pdf = pw.Document();
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
    build: (ctx) => _buildReportPage(ctx, p),
  ));
  return pdf.save();
}

Future<Uint8List> _buildComparisonPdf(_ComparisonParams p) async {
  await initializeDateFormatting();
  final pdf = pw.Document();
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
    build: (ctx) => _buildComparisonPage(ctx, p),
  ));
  return pdf.save();
}

Future<Uint8List> _buildDepreciationPdf(_DepreciationParams p) async {
  await initializeDateFormatting();
  final pdf = pw.Document();
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
    build: (ctx) => _buildDepreciationPage(ctx, p),
  ));
  return pdf.save();
}

Future<Uint8List> _buildMileagePdf(_MileageParams p) async {
  await initializeDateFormatting();
  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
    header: (_) => _buildMileageHeader(p),
    footer: (ctx) => PdfBrandHelper.footer(ctx, 'RentalExpenses'),
    build: (_) => [_buildMileageBody(p)],
  ));
  return pdf.save();
}

// ── Service class ─────────────────────────────────────────────────────────────

class PdfExportService {
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
    final params = _ReportParams(
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
    );
    final bytes = await Isolate.run(() => _buildReportPdf(params));
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'RentalExpenses_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> exportComparison({
    required BuildContext context,
    required List<Map<String, dynamic>> properties,
    // Each map: {name, address, rent, expenses, netIncome, expenseRatio, noi}
    required DateTime selectedMonth,
    bool isSpanish = false,
  }) async {
    final params = _ComparisonParams(
      properties: properties,
      selectedMonthMs: selectedMonth.millisecondsSinceEpoch,
      isSpanish: isSpanish,
    );
    final bytes = await Isolate.run(() => _buildComparisonPdf(params));
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'RentalExpenses_Compare_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> exportDepreciation({
    required BuildContext context,
    required double purchasePrice,
    required double landValue,
    required double improvements,
    required double depreciableBasis,
    required double annualDepreciation,
    required double firstYearDepreciation,
    required int inServiceMonth,
    required int inServiceYear,
    String propertyName = '',
    bool isSpanish = false,
  }) async {
    final params = _DepreciationParams(
      purchasePrice: purchasePrice,
      landValue: landValue,
      improvements: improvements,
      depreciableBasis: depreciableBasis,
      annualDepreciation: annualDepreciation,
      firstYearDepreciation: firstYearDepreciation,
      inServiceMonth: inServiceMonth,
      inServiceYear: inServiceYear,
      propertyName: propertyName,
      isSpanish: isSpanish,
    );
    final bytes = await Isolate.run(() => _buildDepreciationPdf(params));
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'RentalExpenses_Depreciation_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> exportMileageLog({
    required BuildContext context,
    required String propertyName,
    required int year,
    required double totalMiles,
    required double rate,
    required double deduction,
    required List<Map<String, dynamic>> trips,
    // Each: {date: DateTime, miles: double, purpose: String}
    bool isSpanish = false,
  }) async {
    // Serialize DateTime → int (millisecondsSinceEpoch) for isolate transfer
    final serializableTrips = trips.map((t) {
      final date = t['date'] as DateTime?;
      final copy = Map<String, dynamic>.from(t);
      copy.remove('date');
      copy['dateMs'] = date?.millisecondsSinceEpoch;
      return copy;
    }).toList();

    final params = _MileageParams(
      propertyName: propertyName,
      year: year,
      totalMiles: totalMiles,
      rate: rate,
      deduction: deduction,
      trips: serializableTrips,
      isSpanish: isSpanish,
    );
    final bytes = await Isolate.run(() => _buildMileagePdf(params));
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'RentalExpenses_Mileage_${year}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> showUnlockOrPay(
      BuildContext context, Future<void> Function() onExport) async {
    if (freemiumService.hasFullAccess) {
      await onExport();
      return;
    }
    await PaywallHard.show(context);
  }
}
