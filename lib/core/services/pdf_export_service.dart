import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../freemium/iap_service.dart';
import '../theme/app_theme.dart';
import '../../l10n/strings_en.dart';
import '../../l10n/strings_es.dart';
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
        isSpanish ? 'Distribución de ingresos' : 'Income Breakdown';

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

  // ── Compare Properties export ─────────────────────────────────────────────

  static Future<void> exportComparison({
    required BuildContext context,
    required List<Map<String, dynamic>> properties,
    // Each map: {name, address, rent, expenses, netIncome, expenseRatio, noi}
    required DateTime selectedMonth,
    bool isSpanish = false,
  }) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      build: (_) => _buildComparisonPage(
        properties: properties,
        selectedMonth: selectedMonth,
        isSpanish: isSpanish,
      ),
    ));
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'RentalExpenses_Compare_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildComparisonPage({
    required List<Map<String, dynamic>> properties,
    required DateTime selectedMonth,
    bool isSpanish = false,
  }) {
    final now = DateTime.now();
    final monthFmt = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en');

    // Determine winner by net income
    int winnerIdx = 0;
    for (int i = 1; i < properties.length; i++) {
      final net = (properties[i]['netIncome'] as double?) ?? 0;
      final bestNet = (properties[winnerIdx]['netIncome'] as double?) ?? 0;
      if (net > bestNet) winnerIdx = i;
    }

    final colWidth = (PdfPageFormat.a4.availableWidth - 72) / properties.length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(
                isSpanish ? 'Comparación de Propiedades' : 'Property Comparison',
                style: pw.TextStyle(
                    fontSize: AppTextSize.title,
                    fontWeight: pw.FontWeight.bold,
                    color: _orange)),
              pw.Text(
                monthFmt.format(selectedMonth),
                style: const pw.TextStyle(fontSize: AppTextSize.xs, color: PdfColors.grey700)),
            ]),
            pw.Text(_date.format(now),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        pw.Container(
            height: 2,
            color: _orange,
            margin: const pw.EdgeInsets.only(top: 6, bottom: 14)),

        // Header row
        pw.Row(children: [
          pw.SizedBox(width: 120),
          ...List.generate(properties.length, (i) {
            final isWinner = i == winnerIdx;
            return pw.Container(
              width: colWidth,
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              color: isWinner ? _navy : PdfColors.grey200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    properties[i]['name'] as String? ?? '',
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: isWinner ? PdfColors.white : PdfColors.grey800),
                    textAlign: pw.TextAlign.center,
                  ),
                  if ((properties[i]['address'] as String? ?? '').isNotEmpty)
                    pw.Text(
                      properties[i]['address'] as String,
                      style: pw.TextStyle(
                          fontSize: 7,
                          color: isWinner ? PdfColors.grey200 : PdfColors.grey600),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (isWinner)
                    pw.Text(
                      isSpanish ? '★ GANADOR' : '★ WINNER',
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

        // Metric rows
        ..._comparisonMetricRow(
          label: isSpanish ? 'Alquiler mensual' : 'Monthly Rent',
          properties: properties,
          key: 'rent',
          isCurrency: true,
          higherIsBetter: true,
          winnerIdx: winnerIdx,
          colWidth: colWidth,
        ),
        ..._comparisonMetricRow(
          label: isSpanish ? 'Total gastos' : 'Total Expenses',
          properties: properties,
          key: 'expenses',
          isCurrency: true,
          higherIsBetter: false,
          winnerIdx: winnerIdx,
          colWidth: colWidth,
        ),
        ..._comparisonMetricRow(
          label: isSpanish ? 'Flujo neto mensual' : 'Monthly Net Income',
          properties: properties,
          key: 'netIncome',
          isCurrency: true,
          higherIsBetter: true,
          winnerIdx: winnerIdx,
          colWidth: colWidth,
          bold: true,
          highlightWinner: true,
        ),
        ..._comparisonMetricRow(
          label: isSpanish ? 'Flujo neto anual' : 'Annual Net Income',
          properties: properties,
          key: 'netIncome',
          isCurrency: true,
          higherIsBetter: true,
          winnerIdx: winnerIdx,
          colWidth: colWidth,
          multiplier: 12,
        ),
        ..._comparisonMetricRow(
          label: isSpanish ? 'Ratio de gastos' : 'Expense Ratio',
          properties: properties,
          key: 'expenseRatio',
          isCurrency: false,
          isPercent: true,
          higherIsBetter: false,
          winnerIdx: winnerIdx,
          colWidth: colWidth,
        ),
        ..._comparisonMetricRow(
          label: 'NOI (${isSpanish ? 'anual' : 'annual'})',
          properties: properties,
          key: 'noi',
          isCurrency: true,
          higherIsBetter: true,
          winnerIdx: winnerIdx,
          colWidth: colWidth,
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
      ],
    );
  }

  static List<pw.Widget> _comparisonMetricRow({
    required String label,
    required List<Map<String, dynamic>> properties,
    required String key,
    required bool isCurrency,
    required bool higherIsBetter,
    required int winnerIdx,
    required double colWidth,
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
            formatted = _cur0.format(raw);
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

  // ── Depreciation export ───────────────────────────────────────────────────

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
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      build: (_) => _buildDepreciationPage(
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
      ),
    ));
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'RentalExpenses_Depreciation_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildDepreciationPage({
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
  }) {
    final now = DateTime.now();
    final monthNames = isSpanish
        ? const ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre']
        : const ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final monthLabel = monthNames[(inServiceMonth - 1).clamp(0, 11)];

    // Cumulative depreciation table: 5, 10, 15, 20, 27.5 years
    final checkpoints = [5, 10, 15, 20, 28]; // 28 ≈ full recovery
    // Assume full annual each year after first-year partial
    // Year 1 = firstYear; years 2..N = annual * (N-1) + firstYear capped at basis
    double _cumAt(int years) {
      if (years <= 0) return 0;
      final full = firstYearDepreciation + annualDepreciation * (years - 1);
      return full > depreciableBasis ? depreciableBasis : full;
    }

    // Estimated marginal tax savings (assume 24% federal bracket)
    const taxRate = 0.24;
    final annualTaxSavings = annualDepreciation * taxRate;
    final firstYearTaxSavings = firstYearDepreciation * taxRate;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(
                isSpanish ? 'Calculadora de Depreciación' : 'Depreciation Calculator',
                style: pw.TextStyle(
                    fontSize: AppTextSize.title,
                    fontWeight: pw.FontWeight.bold,
                    color: _orange)),
              pw.Text(
                propertyName.isNotEmpty
                    ? propertyName
                    : 'MACRS GDS · 27.5 ${isSpanish ? 'años' : 'years'} · ${isSpanish ? 'Residencial' : 'Residential'}',
                style: const pw.TextStyle(fontSize: AppTextSize.xs, color: PdfColors.grey700)),
            ]),
            pw.Text(_date.format(now),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        pw.Container(
            height: 2,
            color: _orange,
            margin: const pw.EdgeInsets.only(top: 6, bottom: 14)),

        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(children: [
            _sectionBox(isSpanish ? 'DATOS DE ENTRADA' : 'INPUT DATA', [
              _row2(isSpanish ? 'Precio de compra' : 'Purchase Price', _cur0.format(purchasePrice)),
              _row2(isSpanish ? 'Valor del terreno' : 'Land Value', _cur0.format(landValue)),
              if (improvements > 0)
                _row2(isSpanish ? 'Mejoras de capital' : 'Capital Improvements', _cur0.format(improvements)),
              _row2(isSpanish ? 'Mes en servicio' : 'In-Service Month', '$monthLabel $inServiceYear'),
              _row2(isSpanish ? 'Método' : 'Method',
                  isSpanish ? 'Línea recta (MACRS GDS)' : 'Straight-Line (MACRS GDS)'),
              _row2(isSpanish ? 'Período' : 'Recovery Period',
                  isSpanish ? '27.5 años (residencial)' : '27.5 years (residential)'),
            ]),
            pw.SizedBox(height: 10),
            _sectionBox(isSpanish ? 'RESULTADO' : 'RESULT', [
              _row2(isSpanish ? 'Base depreciable' : 'Depreciable Basis',
                  _cur0.format(depreciableBasis)),
              _row2(isSpanish ? 'Depreciación anual' : 'Annual Depreciation',
                  _cur2.format(annualDepreciation), bold: true, color: _navy),
              pw.Divider(color: PdfColors.grey300, height: 6),
              _row2(isSpanish ? '1er año (mid-month)' : '1st Year (mid-month)',
                  _cur2.format(firstYearDepreciation), bold: true, color: _orange),
            ]),
          ])),
          pw.SizedBox(width: 14),
          pw.Expanded(child: pw.Column(children: [
            _sectionBox(isSpanish ? 'DEPRECIACIÓN ACUMULADA' : 'CUMULATIVE DEPRECIATION', [
              ...checkpoints.map((yr) {
                final cum = _cumAt(yr);
                final label = yr == 28
                    ? isSpanish ? '27.5 años (total)' : '27.5 yrs (full)'
                    : '${yr} ${isSpanish ? 'años' : 'yrs'}';
                return _row2(label, _cur0.format(cum),
                    bold: yr == 28, color: yr == 28 ? _navy : null);
              }),
            ]),
            pw.SizedBox(height: 10),
            _sectionBox(isSpanish ? 'AHORRO FISCAL ESTIMADO (24%)' : 'EST. TAX SAVINGS (24% bracket)', [
              _row2(isSpanish ? 'Ahorro anual' : 'Annual Savings',
                  _cur2.format(annualTaxSavings), bold: true, color: _navy),
              _row2(isSpanish ? 'Ahorro 1er año' : '1st Year Savings',
                  _cur2.format(firstYearTaxSavings)),
              _row2(isSpanish ? 'Ahorro total (27.5 años)' : 'Total Savings (27.5 yrs)',
                  _cur0.format(depreciableBasis * taxRate)),
            ]),
          ])),
        ]),

        pw.Spacer(),
        pw.Column(children: [
          pw.Divider(color: PdfColors.grey300, height: 12),
          pw.Text(
            isSpanish
                ? 'Estimación. MACRS GDS, convención de medio mes. El terreno no es depreciable. Consulta un profesional fiscal. Ahorro fiscal basado en tasa del 24%.'
                : 'Estimate only. MACRS GDS, mid-month convention. Land is not depreciable. Consult a tax professional. Tax savings based on 24% federal rate.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        ]),
      ],
    );
  }

  // ── Mileage Log export ────────────────────────────────────────────────────

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
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 28),
      header: (_) => _buildMileageHeader(
        propertyName: propertyName,
        year: year,
        totalMiles: totalMiles,
        rate: rate,
        deduction: deduction,
        isSpanish: isSpanish,
      ),
      footer: (_) => pw.Column(children: [
        pw.Divider(color: PdfColors.grey300, height: 8),
        pw.Text(
          isSpanish
              ? 'Generado por Rental Expenses Calculator · Método de millaje estándar del IRS. No es consejo fiscal.'
              : 'Generated by Rental Expenses Calculator · IRS standard mileage method. Not tax advice.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
      ]),
      build: (_) => [_buildMileageBody(trips: trips, year: year, isSpanish: isSpanish)],
    ));
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'RentalExpenses_Mileage_${year}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  static pw.Widget _buildMileageHeader({
    required String propertyName,
    required int year,
    required double totalMiles,
    required double rate,
    required double deduction,
    bool isSpanish = false,
  }) {
    final now = DateTime.now();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(
                isSpanish ? 'Registro de Millaje de Negocios' : 'Business Mileage Log',
                style: pw.TextStyle(
                    fontSize: AppTextSize.title,
                    fontWeight: pw.FontWeight.bold,
                    color: _orange)),
              pw.Text(
                propertyName.isNotEmpty
                    ? '$propertyName · $year'
                    : '$year',
                style: const pw.TextStyle(fontSize: AppTextSize.xs, color: PdfColors.grey700)),
            ]),
            pw.Text(_date.format(now),
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ],
        ),
        pw.Container(
            height: 2,
            color: _orange,
            margin: const pw.EdgeInsets.only(top: 6, bottom: 10)),
        // Summary strip
        pw.Row(children: [
          pw.Expanded(child: _summaryTile(
            isSpanish ? 'Total millas' : 'Total Miles',
            '${totalMiles.toStringAsFixed(1)} mi',
          )),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _summaryTile(
            isSpanish ? 'Tasa IRS $year' : 'IRS Rate $year',
            '\$${rate.toStringAsFixed(3)}/mi',
          )),
          pw.SizedBox(width: 8),
          pw.Expanded(child: _summaryTile(
            isSpanish ? 'Deducción' : 'Deduction',
            _cur2.format(deduction),
            highlight: true,
          )),
        ]),
        pw.SizedBox(height: 10),
      ],
    );
  }

  static pw.Widget _summaryTile(String label, String value, {bool highlight = false}) =>
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

  static pw.Widget _buildMileageBody({
    required List<Map<String, dynamic>> trips,
    required int year,
    bool isSpanish = false,
  }) {
    if (trips.isEmpty) {
      return pw.Center(
        child: pw.Text(
          isSpanish ? 'Sin trayectos registrados.' : 'No trips recorded.',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
        ),
      );
    }

    // Group by purpose category for summary
    final Map<String, double> byCategory = {};
    for (final t in trips) {
      final purpose = (t['purpose'] as String? ?? '').trim();
      final cat = purpose.isNotEmpty ? purpose : (isSpanish ? 'Sin motivo' : 'No purpose');
      byCategory[cat] = (byCategory[cat] ?? 0) + ((t['miles'] as double?) ?? 0);
    }

    final dateFmt = DateFormat('yyyy-MM-dd');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Category summary
        if (byCategory.length > 1) ...[
          _sectionBox(isSpanish ? 'POR CATEGORÍA' : 'BY CATEGORY', [
            ...byCategory.entries.map((e) =>
                _row2(e.key, '${e.value.toStringAsFixed(1)} mi')),
          ]),
          pw.SizedBox(height: 12),
        ],

        // Trip list header
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _navy,
          child: pw.Row(children: [
            pw.SizedBox(width: 80,
                child: pw.Text(isSpanish ? 'Fecha' : 'Date',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
            pw.SizedBox(width: 8),
            pw.Expanded(child: pw.Text(isSpanish ? 'Motivo' : 'Purpose',
                style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 60,
                child: pw.Text(isSpanish ? 'Millas' : 'Miles',
                    style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    textAlign: pw.TextAlign.right)),
          ]),
        ),

        // Trip rows
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
              pw.SizedBox(width: 80,
                  child: pw.Text(
                      tripDate != null ? dateFmt.format(tripDate) : '',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: pw.Text(
                  purpose.isNotEmpty ? purpose : '—',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800))),
              pw.SizedBox(width: 8),
              pw.SizedBox(width: 60,
                  child: pw.Text(
                      '${miles.toStringAsFixed(1)} mi',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: _navy),
                      textAlign: pw.TextAlign.right)),
            ]),
          );
        }),

        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: PdfColors.grey200,
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(
                isSpanish ? 'TOTAL' : 'TOTAL',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
            pw.Text(
                '${trips.fold<double>(0, (s, t) => s + ((t['miles'] as double?) ?? 0)).toStringAsFixed(1)} mi',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _navy)),
          ]),
        ),
      ],
    );
  }

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
    final s = isSpanishNotifier.value
        ? const AppStringsEs()
        : const AppStringsEn();
    setState(() => _loading = true);
    final earned = await adService.showRewarded();
    if (!mounted) return;
    setState(() => _loading = false);
    if (earned) {
      Navigator.pop(context);
      await widget.onExport();
    } else
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.adNotAvailable)));
  }

  @override
  Widget build(BuildContext context) {
    final adReady = adService.isRewardedReady;
    final isEs = isSpanishNotifier.value;
    final s = isEs ? const AppStringsEs() : const AppStringsEn();
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
        Text(s.exportPdfReport,
            style: const TextStyle(
                fontSize: AppTextSize.subtitle, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(s.chooseUnlockPdf,
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
                          Text(s.watchShortVideo,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppTextSize.bodyMd)),
                          const SizedBox(height: 2),
                          Text(s.exportOnceFree,
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
              label: Text(s.premiumUnlimited,
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
            child: Text(s.notNow,
                style: const TextStyle(color: Color(0xFF64748B)))),
      ]),
    );
  }
}
