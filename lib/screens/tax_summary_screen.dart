import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/irs_categories.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../models/property_model.dart';
import '../models/schedule_e_entry_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';

class TaxSummaryScreen extends StatefulWidget {
  const TaxSummaryScreen({super.key});

  @override
  State<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends State<TaxSummaryScreen> {
  final _fmt = NumberFormat('#,##0.00', 'en_US');
  final _now = DateTime.now();

  late int _selectedYear;
  List<int> _years = [];

  List<Property> _properties = [];
  // propertyId → list of entries for selected year
  Map<String, List<ScheduleEEntry>> _entriesMap = {};
  // manual rental income override per property
  Map<String, TextEditingController> _incomeControllers = {};

  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _selectedYear = _now.year;
    _years = List.generate(4, (i) => _now.year - i);
    AnalyticsService.instance.logTaxSummaryViewed();
    _load();
  }

  @override
  void dispose() {
    for (final c in _incomeControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final props = await PropertyDatabaseService.instance.getAllProperties();
    final Map<String, List<ScheduleEEntry>> map = {};
    for (final p in props) {
      map[p.id] = await PropertyDatabaseService.instance
          .getScheduleEEntriesForProperty(p.id, _selectedYear);
    }
    // Initialize income controllers if needed
    for (final p in props) {
      if (!_incomeControllers.containsKey(p.id)) {
        _incomeControllers[p.id] = TextEditingController(
            text: (p.monthlyRent * 12).toStringAsFixed(2));
      }
    }
    if (mounted) {
      setState(() {
        _properties = props;
        _entriesMap = map;
        _loading = false;
      });
    }
  }

  double _totalIncome(Property p) {
    final raw = _incomeControllers[p.id]?.text ?? '';
    return double.tryParse(raw.replaceAll(',', '.')) ?? (p.monthlyRent * 12);
  }

  double _totalExpensesForProperty(String propertyId) {
    final entries = _entriesMap[propertyId] ?? [];
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }

  double _netForProperty(Property p) =>
      _totalIncome(p) - _totalExpensesForProperty(p.id);

  Map<String, double> _categoryTotals(String propertyId) {
    final entries = _entriesMap[propertyId] ?? [];
    final map = <String, double>{};
    for (final e in entries) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> _addOrEditEntry(
      BuildContext ctx, bool isSpanish, Property property,
      {ScheduleEEntry? existing}) async {
    String selectedCategory = existing?.category ?? IrsCategories.all.first;
    final amountCtrl = TextEditingController(
        text: existing != null && existing.amount > 0
            ? existing.amount.toStringAsFixed(2)
            : '');
    bool isRecurring = existing?.isRecurring ?? false;
    String recurrenceType = existing?.recurrenceType ?? 'monthly';

    await showDialog<void>(
      context: ctx,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(existing != null
              ? (isSpanish ? 'Editar gasto' : 'Edit Expense')
              : (isSpanish ? 'Agregar gasto' : 'Add Expense')),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: isSpanish ? 'Categoría IRS' : 'IRS Category',
                ),
                items: IrsCategories.all.map((c) {
                  return DropdownMenuItem(
                    value: c,
                    child: Text(
                      IrsCategories.translate(c, isSpanish),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) =>
                    setLocal(() => selectedCategory = v ?? selectedCategory),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isSpanish ? 'Monto (\$)' : 'Amount (\$)',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isSpanish ? 'Gasto recurrente' : 'Recurring expense',
                  style: const TextStyle(fontSize: AppTextSize.body),
                ),
                value: isRecurring,
                activeThumbColor: AppTheme.primary,
                onChanged: (v) => setLocal(() => isRecurring = v),
              ),
              if (isRecurring)
                DropdownButtonFormField<String>(
                  initialValue: recurrenceType,
                  decoration: InputDecoration(
                    labelText: isSpanish ? 'Frecuencia' : 'Frequency',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text(isSpanish ? 'Mensual' : 'Monthly'),
                    ),
                    DropdownMenuItem(
                      value: 'annual',
                      child: Text(isSpanish ? 'Anual' : 'Annual'),
                    ),
                  ],
                  onChanged: (v) =>
                      setLocal(() => recurrenceType = v ?? 'monthly'),
                ),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () async {
                  await PropertyDatabaseService.instance
                      .deleteScheduleEEntry(existing.id);
                  if (d.mounted) Navigator.pop(d);
                  _load();
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(isSpanish ? 'Eliminar' : 'Delete'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: () async {
                final amount =
                    double.tryParse(amountCtrl.text.replaceAll(',', '.')) ??
                        0.0;
                if (amount <= 0) return;
                final id = existing?.id ??
                    'sche_${property.id}_${_selectedYear}_${selectedCategory.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
                final entry = ScheduleEEntry(
                  id: id,
                  propertyId: property.id,
                  year: _selectedYear,
                  category: selectedCategory,
                  amount: amount,
                  isRecurring: isRecurring,
                  recurrenceType: isRecurring ? recurrenceType : null,
                );
                if (existing != null) {
                  await PropertyDatabaseService.instance
                      .updateScheduleEEntry(entry);
                } else {
                  await PropertyDatabaseService.instance
                      .insertScheduleEEntry(entry);
                }
                if (d.mounted) Navigator.pop(d);
                _load();
              },
              child: Text(isSpanish ? 'Guardar' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext ctx, bool isSpanish) async {
    if (!freemiumService.hasFullAccess) {
      await PaywallHard.show(ctx);
      return;
    }
    setState(() => _exporting = true);
    try {
      final doc = pw.Document();
      final genDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(40),
          build: (pctx) {
            final widgets = <pw.Widget>[];

            for (final property in _properties) {
              final catTotals = _categoryTotals(property.id);
              final totalInc = _totalIncome(property);
              final totalExp = _totalExpensesForProperty(property.id);
              final net = totalInc - totalExp;

              widgets.addAll([
                pw.Text(
                  'Schedule E — Rental Income and Expenses $_selectedYear',
                  style: pw.TextStyle(
                      fontSize: AppTextSize.bodyLg,
                      fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Property: ${property.name}',
                  style: pw.TextStyle(
                      fontSize: AppTextSize.md, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Address: ${property.address}',
                  style: const pw.TextStyle(fontSize: AppTextSize.xs),
                ),
                pw.SizedBox(height: 14),

                // Part I header
                pw.Container(
                  padding: const pw.EdgeInsets.all(AppSpacing.sm),
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.grey200,
                  ),
                  child: pw.Text(
                    'Part I — Income or Loss From Rental Real Estate and Royalties',
                    style: pw.TextStyle(
                        fontSize: AppTextSize.xs,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 6),

                // Income row
                pw.TableHelper.fromTextArray(
                  headers: ['Item', 'Amount'],
                  data: [
                    ['Rental Income', '\$${_fmt.format(totalInc)}'],
                  ],
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  cellHeight: 20,
                ),
                pw.SizedBox(height: 8),

                // Expenses by category
                pw.Text(
                  'Expenses',
                  style: pw.TextStyle(
                      fontSize: AppTextSize.xs, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.TableHelper.fromTextArray(
                  headers: ['Category', 'Amount'],
                  data: [
                    ...IrsCategories.all
                        .where((c) =>
                            catTotals.containsKey(c) && catTotals[c]! > 0)
                        .map((c) => [c, '\$${_fmt.format(catTotals[c]!)}']),
                    ['Total Expenses', '\$${_fmt.format(totalExp)}'],
                  ],
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  cellHeight: 20,
                ),
                pw.SizedBox(height: 8),

                // Net result
                pw.Container(
                  padding: const pw.EdgeInsets.all(AppSpacing.smPlus),
                  decoration: pw.BoxDecoration(
                    color: net >= 0 ? PdfColors.green50 : PdfColors.red50,
                    border: pw.Border.all(
                        color:
                            net >= 0 ? PdfColors.green300 : PdfColors.red300),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        net >= 0 ? 'Net Rental Income' : 'Net Rental Loss',
                        style: pw.TextStyle(
                            fontSize: AppTextSize.sm,
                            fontWeight: pw.FontWeight.bold,
                            color: net >= 0
                                ? PdfColors.green800
                                : PdfColors.red800),
                      ),
                      pw.Text(
                        '${net < 0 ? '-' : ''}\$${_fmt.format(net.abs())}',
                        style: pw.TextStyle(
                            fontSize: AppTextSize.sm,
                            fontWeight: pw.FontWeight.bold,
                            color: net >= 0
                                ? PdfColors.green800
                                : PdfColors.red800),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
              ]);
            }

            // Footer note
            widgets.addAll([
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Text(
                'Generated: $genDate',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.Text(
                'Generated by RentalExpenses app. Consult a tax professional before filing.',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ]);

            return widgets;
          },
        ),
      );

      await AnalyticsService.instance.logScheduleEExported();
      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        // Portfolio totals
        double grandIncome = 0;
        double grandExpenses = 0;
        for (final p in _properties) {
          grandIncome += _totalIncome(p);
          grandExpenses += _totalExpensesForProperty(p.id);
        }
        final grandNet = grandIncome - grandExpenses;

        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish
                ? 'Resumen Fiscal Schedule E'
                : 'Tax Summary — Schedule E'),
            actions: [
              if (_exporting)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  tooltip: isSpanish
                      ? 'Exportar Schedule E PDF'
                      : 'Export Schedule E PDF',
                  onPressed: () => _exportPdf(context, isSpanish),
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
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          // Year selector
                          _SectionLabel(isSpanish ? 'AÑO FISCAL' : 'TAX YEAR'),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedYear,
                                decoration: InputDecoration(
                                  labelText: isSpanish ? 'Año' : 'Year',
                                  prefixIcon:
                                      const Icon(Icons.calendar_today_rounded),
                                ),
                                items: _years
                                    .map((y) => DropdownMenuItem(
                                          value: y,
                                          child: Text('$y'),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _selectedYear = v);
                                  _load();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Portfolio net summary
                          if (_properties.isNotEmpty) ...[
                            _SectionLabel(isSpanish
                                ? 'RESUMEN PORTAFOLIO'
                                : 'PORTFOLIO NET'),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  children: [
                                    _NetRow(
                                      label: isSpanish
                                          ? 'Total ingresos'
                                          : 'Total Rental Income',
                                      value: '\$${_fmt.format(grandIncome)}',
                                      color: AppTheme.success,
                                    ),
                                    const SizedBox(height: 8),
                                    _NetRow(
                                      label: isSpanish
                                          ? 'Total gastos'
                                          : 'Total Expenses',
                                      value: '\$${_fmt.format(grandExpenses)}',
                                      color: Colors.red,
                                    ),
                                    Divider(
                                        height: 20,
                                        color: CalcwiseTheme.of(context)
                                            .cardBorder),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            grandNet >= 0
                                                ? (isSpanish
                                                    ? 'Ingreso neto total'
                                                    : 'Net Rental Income')
                                                : (isSpanish
                                                    ? 'Pérdida neta total'
                                                    : 'Net Rental Loss'),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: AppTextSize.bodyMd),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: (grandNet >= 0
                                                    ? AppTheme.success
                                                    : Colors.red)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.md),
                                          ),
                                          child: Text(
                                            '${grandNet < 0 ? '-' : ''}\$${_fmt.format(grandNet.abs())}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: AppTextSize.bodyLg,
                                              color: grandNet >= 0
                                                  ? AppTheme.success
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (grandNet >= 0
                                                  ? AppTheme.success
                                                  : Colors.red)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          grandNet >= 0
                                              ? (isSpanish
                                                  ? 'Net Income'
                                                  : 'Net Income')
                                              : (isSpanish
                                                  ? 'Net Loss'
                                                  : 'Net Loss'),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: grandNet >= 0
                                                ? AppTheme.success
                                                : Colors.red,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Per-property Schedule E breakdown
                          if (_properties.isEmpty)
                            _EmptyState(isSpanish: isSpanish)
                          else
                            ..._properties.map((p) {
                              final catTotals = _categoryTotals(p.id);
                              final totalExp = _totalExpensesForProperty(p.id);
                              final net = _netForProperty(p);
                              final incCtrl = _incomeControllers[p.id];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _SectionLabel(p.name.toUpperCase()),
                                  Card(
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.all(AppSpacing.lg),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (p.address.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 10),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                      Icons.location_on_rounded,
                                                      size: 14,
                                                      color:
                                                          AppTheme.labelGray),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      p.address,
                                                      style: const TextStyle(
                                                          fontSize:
                                                              AppTextSize.sm,
                                                          color: AppTheme
                                                              .labelGray),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                          // Rental income field
                                          TextField(
                                            controller: incCtrl,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            onChanged: (_) => setState(() {}),
                                            decoration: InputDecoration(
                                              labelText: isSpanish
                                                  ? 'Ingreso anual por alquiler'
                                                  : 'Annual Rental Income',
                                              prefixText: '\$',
                                              helperText: isSpanish
                                                  ? 'Prellenado con alquiler mensual × 12'
                                                  : 'Pre-filled from monthly rent × 12',
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Part I Schedule E label
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.md),
                                            ),
                                            child: Text(
                                              isSpanish
                                                  ? 'Parte I — Gastos (Schedule E)'
                                                  : 'Part I — Expenses (Schedule E)',
                                              style: const TextStyle(
                                                fontSize: AppTextSize.sm,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                          // Category rows
                                          if (catTotals.isEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              child: Text(
                                                isSpanish
                                                    ? 'Sin gastos registrados. Toca + para agregar.'
                                                    : 'No expenses yet. Tap + to add.',
                                                style: TextStyle(
                                                    color: CalcwiseTheme.of(
                                                            context)
                                                        .textSecondary,
                                                    fontSize: AppTextSize.md),
                                              ),
                                            )
                                          else
                                            ...IrsCategories.all
                                                .where((c) =>
                                                    catTotals.containsKey(c) &&
                                                    catTotals[c]! > 0)
                                                .map((c) {
                                              final entries =
                                                  (_entriesMap[p.id] ?? [])
                                                      .where((e) =>
                                                          e.category == c)
                                                      .toList();
                                              return InkWell(
                                                onTap: entries.isNotEmpty
                                                    ? () => _addOrEditEntry(
                                                          context,
                                                          isSpanish,
                                                          p,
                                                          existing:
                                                              entries.first,
                                                        )
                                                    : null,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.receipt_rounded,
                                                          size: 15,
                                                          color: AppTheme
                                                              .labelGray),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          IrsCategories
                                                              .translate(
                                                                  c, isSpanish),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize: 13),
                                                        ),
                                                      ),
                                                      Text(
                                                        '\$${_fmt.format(catTotals[c]!)}',
                                                        style: const TextStyle(
                                                            fontSize:
                                                                AppTextSize.md,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w600),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }),

                                          Divider(
                                              height: 16,
                                              color: CalcwiseTheme.of(context)
                                                  .cardBorder),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  isSpanish
                                                      ? 'Total gastos'
                                                      : 'Total Expenses',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ),
                                              Text(
                                                '\$${_fmt.format(totalExp)}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  net >= 0
                                                      ? (isSpanish
                                                          ? 'Ingreso neto'
                                                          : 'Net Income')
                                                      : (isSpanish
                                                          ? 'Pérdida neta'
                                                          : 'Net Loss'),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: net >= 0
                                                        ? AppTheme.success
                                                        : Colors.red,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${net < 0 ? '-' : ''}\$${_fmt.format(net.abs())}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: AppTextSize.bodyMd,
                                                  color: net >= 0
                                                      ? AppTheme.success
                                                      : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),

                                          // Add expense button
                                          OutlinedButton.icon(
                                            onPressed: () => _addOrEditEntry(
                                                context, isSpanish, p),
                                            icon: const Icon(Icons.add_rounded,
                                                size: 18),
                                            label: Text(isSpanish
                                                ? 'Agregar gasto IRS'
                                                : 'Add IRS Expense'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppTheme.primary,
                                              side: const BorderSide(
                                                  color: AppTheme.primary),
                                              minimumSize: const Size(
                                                  double.infinity, 44),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              );
                            }),

                          // Export PDF button
                          if (_properties.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: _exporting
                                  ? null
                                  : () => _exportPdf(context, isSpanish),
                              icon: _exporting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.picture_as_pdf_rounded),
                              label: Text(isSpanish
                                  ? 'Exportar Schedule E PDF'
                                  : 'Export Schedule E PDF'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isSpanish
                                  ? 'Consulta a un profesional fiscal antes de presentar tu declaración.'
                                  : 'Consult a tax professional before filing your return.',
                              style: TextStyle(
                                  fontSize: AppTextSize.xs,
                                  color:
                                      CalcwiseTheme.of(context).textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
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

// ── Small widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
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

class _NetRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _NetRow(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: AppTextSize.body,
                  color: CalcwiseTheme.of(context).textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.w600,
                color: color)),
      ],
    );
  }
}

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
            Icon(Icons.receipt_long_rounded,
                size: 72,
                color: CalcwiseTheme.of(context)
                    .textSecondary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              isSpanish ? 'Sin propiedades' : 'No properties',
              style: const TextStyle(
                  fontSize: AppTextSize.subtitle, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSpanish
                  ? 'Agrega propiedades en la pestaña Propiedades.'
                  : 'Add properties in the Properties tab.',
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
