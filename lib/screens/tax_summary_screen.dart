import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/constants/irs_categories.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../models/property_model.dart';
import '../models/schedule_e_entry_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';
import '../widgets/paywall_soft.dart';
import '../widgets/save_scenario_button.dart';

class TaxSummaryScreen extends StatefulWidget {
  const TaxSummaryScreen({super.key});

  @override
  State<TaxSummaryScreen> createState() => _TaxSummaryScreenState();
}

class _TaxSummaryScreenState extends State<TaxSummaryScreen> {
  // AmountFormatter replaces NumberFormat _fmt
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
  String? _currentHash;

  @override
  void initState() {
    super.initState();
    _selectedYear = _now.year;
    _years = List.generate(4, (i) => _now.year - i);
    AnalyticsService.instance.logScreenView('tax_summary');
    AnalyticsService.instance.logTaxSummaryViewed();
    _load();
  }

  @override
  void dispose() {
    smartHistoryService.cancelPendingSave('rentalexpenses', 'tax_summary');
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
    // Initialize income controllers if needed, and reset text on year change
    for (final p in props) {
      if (!_incomeControllers.containsKey(p.id)) {
        _incomeControllers[p.id] = TextEditingController(
            text: (p.monthlyRent * 12).toStringAsFixed(2));
      } else {
        _incomeControllers[p.id]?.text =
            (p.monthlyRent * 12).toStringAsFixed(2);
      }
    }
    if (mounted) {
      setState(() {
        _properties = props;
        _entriesMap = map;
        _loading = false;
      });
      // Schedule SmartHistory auto-save after data is loaded
      if (props.isNotEmpty) {
        double grossIncome = 0;
        double totalExpenses = 0;
        for (final p in props) {
          grossIncome += (p.monthlyRent * 12);
          totalExpenses += (map[p.id] ?? []).fold(0.0, (sum, e) {
            final annual = e.isRecurring && e.recurrenceType == 'monthly'
                ? e.amount * 12
                : e.amount;
            return sum + annual;
          });
        }
        _scheduleSmartHistorySave(grossIncome, totalExpenses);
      }
    }
  }

  // ── SmartHistory helpers ────────────────────────────────────────────────────

  double _roundTo(double v, double step) => (v / step).round() * step;

  void _scheduleSmartHistorySave(
      double grossIncome, double totalExpenses) {
    final taxableIncome = grossIncome - totalExpenses;
    final hash = ResultHasher.hashInputs({
      'year': _selectedYear.toDouble(),
      'gross': _roundTo(grossIncome, 500),
      'expenses': _roundTo(totalExpenses, 500),
    });
    _currentHash = hash;
    smartHistoryService.scheduleAutoSave(
      appKey: 'rentalexpenses',
      screenId: 'tax_summary',
      inputHash: hash,
      l1: {
        'year': _selectedYear,
        'gross_income': grossIncome,
        'total_expenses': totalExpenses,
        'taxable_income': taxableIncome,
        'net_income': taxableIncome,
      },
      l2: {
        'inputs': {
          'year': _selectedYear,
          'property_count': _properties.length,
          'gross_income': grossIncome,
          'total_expenses': totalExpenses,
        },
        'results': {
          'taxable_income': taxableIncome,
          'net_income': taxableIncome,
        },
      },
    );
  }

  Future<void> _saveScenario(String? label) async {
    HapticFeedback.mediumImpact();
    final hash = _currentHash;
    if (hash == null) return;
    double grossIncome = 0;
    double totalExpenses = 0;
    for (final p in _properties) {
      grossIncome += _totalIncome(p);
      totalExpenses += _totalExpensesForProperty(p.id);
    }
    final taxableIncome = grossIncome - totalExpenses;
    await smartHistoryService.saveScenario(
      appKey: 'rentalexpenses',
      screenId: 'tax_summary',
      inputHash: hash,
      l1: {
        'year': _selectedYear,
        'gross_income': grossIncome,
        'total_expenses': totalExpenses,
        'taxable_income': taxableIncome,
        'net_income': taxableIncome,
      },
      l2: {
        'inputs': {
          'year': _selectedYear,
          'property_count': _properties.length,
          'gross_income': grossIncome,
          'total_expenses': totalExpenses,
        },
        'results': {
          'taxable_income': taxableIncome,
          'net_income': taxableIncome,
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

  double _totalIncome(Property p) {
    final raw = _incomeControllers[p.id]?.text ?? '';
    return double.tryParse(raw.replaceAll(',', '')) ?? (p.monthlyRent * 12);
  }

  double _totalExpensesForProperty(String propertyId) {
    final entries = _entriesMap[propertyId] ?? [];
    return entries.fold(0.0, (sum, e) {
      final annual = e.isRecurring && e.recurrenceType == 'monthly'
          ? e.amount * 12
          : e.amount;
      return sum + annual;
    });
  }

  double _netForProperty(Property p) =>
      _totalIncome(p) - _totalExpensesForProperty(p.id);

  Map<String, double> _categoryTotals(String propertyId) {
    final entries = _entriesMap[propertyId] ?? [];
    final map = <String, double>{};
    for (final e in entries) {
      final annual = (e.isRecurring && e.recurrenceType == 'monthly')
          ? e.amount * 12
          : e.amount;
      map[e.category] = (map[e.category] ?? 0) + annual;
    }
    return map;
  }

  Future<void> _addOrEditEntry(
      BuildContext ctx, bool isSpanish, Property property,
      {ScheduleEEntry? existing}) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
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
          title: Text(existing != null ? s.editExpense : s.addExpense),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: s.irsCategory,
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
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '${s.amount} (\$)',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  s.recurringExpense,
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
                    labelText: s.frequency,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'monthly',
                      child: Text(s.monthly),
                    ),
                    DropdownMenuItem(
                      value: 'annual',
                      child: Text(s.annual),
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
                style: TextButton.styleFrom(
                    foregroundColor: CalcwiseSemanticColors.error(
                        Theme.of(d).brightness)),
                child: Text(s.delete),
              ),
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: () async {
                final amount =
                    double.tryParse(amountCtrl.text.replaceAll(',', '')) ??
                        0.0;
                if (amount <= 0) return;
                final id = existing?.id ??
                    'sche_${property.id}_${_selectedYear}_${DateTime.now().millisecondsSinceEpoch}';
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
                if (isRecurring) {
                  AnalyticsService.instance.logRecurringExpenseCreated();
                }
                if (d.mounted) Navigator.pop(d);
                _load();
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(BuildContext ctx, bool isSpanish) async {
    HapticFeedback.mediumImpact();
    if (!freemiumService.hasFullAccess) {
      await PaywallHard.show(ctx);
      return;
    }
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
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
                  isSpanish
                      ? 'Anexo E — Ingresos y Gastos de Alquiler $_selectedYear'
                      : 'Schedule E — Rental Income and Expenses $_selectedYear',
                  style: pw.TextStyle(
                      fontSize: AppTextSize.bodyLg,
                      fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '${s.property}: ${property.name}',
                  style: pw.TextStyle(
                      fontSize: AppTextSize.md, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${s.address}: ${property.address}',
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
                    isSpanish
                        ? 'Parte I — Ingresos o Pérdidas de Bienes Raíces'
                        : 'Part I — Income or Loss From Rental Real Estate and Royalties',
                    style: pw.TextStyle(
                        fontSize: AppTextSize.xs,
                        fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 6),

                // Income row
                pw.TableHelper.fromTextArray(
                  headers: [
                    isSpanish ? 'Artículo' : 'Item',
                    s.amount,
                  ],
                  data: [
                    [
                      isSpanish ? 'Ingresos de Alquiler' : 'Rental Income',
                      '\$${AmountFormatter.formatNumber(totalInc)}',
                    ],
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
                  isSpanish ? 'Gastos' : 'Expenses',
                  style: pw.TextStyle(
                      fontSize: AppTextSize.xs, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 4),
                pw.TableHelper.fromTextArray(
                  headers: [
                    s.category,
                    s.amount,
                  ],
                  data: [
                    ...IrsCategories.all
                        .where((c) =>
                            catTotals.containsKey(c) && catTotals[c]! > 0)
                        .map((c) => [IrsCategories.translate(c, isSpanish), '\$${AmountFormatter.formatNumber(catTotals[c]!)}']),
                    [
                      s.totalExpensesLabel,
                      '\$${AmountFormatter.formatNumber(totalExp)}',
                    ],
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
                        net >= 0 ? s.netRentalIncome : s.netRentalLoss,
                        style: pw.TextStyle(
                            fontSize: AppTextSize.sm,
                            fontWeight: pw.FontWeight.bold,
                            color: net >= 0
                                ? PdfColors.green800
                                : PdfColors.red800),
                      ),
                      pw.Text(
                        '${net < 0 ? '-' : ''}\$${AmountFormatter.formatNumber(net.abs())}',
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
                isSpanish ? 'Generado: $genDate' : 'Generated: $genDate',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
              pw.Text(
                isSpanish
                    ? 'Generado por RentalExpenses. Consulte a un profesional fiscal.'
                    : 'Generated by RentalExpenses app. Consult a tax professional before filing.',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              ),
            ]);

            return widgets;
          },
        ),
      );

      await AnalyticsService.instance.logScheduleEExported();
      AnalyticsService.instance.logPdfExported();
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
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
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
            title: Text(s.taxSummaryTitle),
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
                  tooltip: s.exportScheduleE,
                  onPressed: () => _exportPdf(context, isSpanish),
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: isSpanishNotifier.value ? 'Actualizar' : 'Refresh',
                onPressed: _load,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const CalcwiseLoadingState()
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          // Year selector
                          _SectionLabel(s.taxYearLabel),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.xs),
                              child: DropdownButtonFormField<int>(
                                initialValue: _selectedYear,
                                decoration: InputDecoration(
                                  labelText: s.year,
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
                          const SizedBox(height: AppSpacing.xl),

                          // Portfolio net summary
                          if (_properties.isNotEmpty) ...[
                            _SectionLabel(s.portfolioNet),
                            CalcwisePageEntrance(child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  children: [
                                    _NetRow(
                                      label: s.totalRentalIncome,
                                      value: '\$${AmountFormatter.formatNumber(grandIncome)}',
                                      color: AppTheme.success,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _NetRow(
                                      label: s.totalExpensesLabel,
                                      value: '\$${AmountFormatter.formatNumber(grandExpenses)}',
                                      color: CalcwiseSemanticColors.error(
                                          Theme.of(context).brightness),
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
                                                ? s.netRentalIncome
                                                : s.netRentalLoss,
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
                                                    : CalcwiseSemanticColors
                                                        .errorDark)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                                AppRadius.md),
                                          ),
                                          child: Text(
                                            '${grandNet < 0 ? '-' : ''}\$${AmountFormatter.formatNumber(grandNet.abs())}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: AppTextSize.bodyLg,
                                              color: grandNet >= 0
                                                  ? AppTheme.success
                                                  : CalcwiseSemanticColors
                                                      .errorDark,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: (grandNet >= 0
                                                  ? AppTheme.success
                                                  : CalcwiseSemanticColors
                                                      .errorDark)
                                              .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.xxl),
                                        ),
                                        child: Text(
                                          grandNet >= 0
                                              ? s.netIncomeBadge
                                              : s.netLossBadge,
                                          style: TextStyle(
                                            fontSize: AppTextSize.xs,
                                            fontWeight: FontWeight.bold,
                                            color: grandNet >= 0
                                                ? AppTheme.success
                                                : CalcwiseSemanticColors
                                                    .errorDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )), // CalcwisePageEntrance closes
                            const SizedBox(height: AppSpacing.xl),
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
                                                  const SizedBox(
                                                      width: AppSpacing.xs),
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
                                              labelText: s.annualRentalIncome,
                                              prefixText: '\$',
                                              helperText: s.preFilledMonthlyRent,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.lg),

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
                                              s.partIExpenses,
                                              style: const TextStyle(
                                                fontSize: AppTextSize.sm,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.md),

                                          // Category rows
                                          if (catTotals.isEmpty)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              child: Text(
                                                s.noExpensesYetTapPlus,
                                                style: TextStyle(
                                                    color: CalcwiseTheme.of(
                                                            context)
                                                        .textSecondary,
                                                    fontSize: AppTextSize.md),
                                              ),
                                            )
                                          else
                                            // One row per category (aggregated),
                                            // matching IRS Schedule E and PDF export.
                                            // Sorted by IrsCategories.all order for consistency.
                                            // Tap opens the first entry for editing.
                                            ...(catTotals.entries
                                                .where((e) => e.value > 0)
                                                .toList()
                                              ..sort((a, b) {
                                                final ai = IrsCategories.all.indexOf(a.key);
                                                final bi = IrsCategories.all.indexOf(b.key);
                                                return (ai < 0 ? 999 : ai)
                                                    .compareTo(bi < 0 ? 999 : bi);
                                              }))
                                                .map((cat) {
                                              final firstEntry =
                                                  (_entriesMap[p.id] ?? [])
                                                      .firstWhere(
                                                (e) => e.category == cat.key,
                                                orElse: () => ScheduleEEntry(
                                                  id: '',
                                                  propertyId: p.id,
                                                  year: _selectedYear,
                                                  category: cat.key,
                                                  amount: 0,
                                                ),
                                              );
                                              return InkWell(
                                                onTap: () => _addOrEditEntry(
                                                  context,
                                                  isSpanish,
                                                  p,
                                                  existing: firstEntry.id
                                                          .isEmpty
                                                      ? null
                                                      : firstEntry,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppRadius.md),
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      vertical: AppSpacing.sm),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                          Icons.receipt_rounded,
                                                          size: 15,
                                                          color: AppTheme
                                                              .labelGray),
                                                      const SizedBox(
                                                          width: AppSpacing.sm),
                                                      Expanded(
                                                        child: Text(
                                                          IrsCategories
                                                              .translate(
                                                                  cat.key,
                                                                  isSpanish),
                                                          style: const TextStyle(
                                                              fontSize:
                                                                  AppTextSize
                                                                      .md),
                                                        ),
                                                      ),
                                                      Text(
                                                        '\$${AmountFormatter.formatNumber(cat.value)}',
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
                                                  s.totalExpensesLabel,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ),
                                              Text(
                                                '\$${AmountFormatter.formatNumber(totalExp)}',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  net >= 0
                                                      ? s.netIncomeBadge
                                                      : s.netLossBadge,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: net >= 0
                                                        ? AppTheme.success
                                                        : CalcwiseSemanticColors
                                                            .error(Theme.of(
                                                                    context)
                                                                .brightness),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${net < 0 ? '-' : ''}\$${AmountFormatter.formatNumber(net.abs())}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: AppTextSize.bodyMd,
                                                  color: net >= 0
                                                      ? AppTheme.success
                                                      : CalcwiseSemanticColors
                                                          .error(Theme.of(
                                                                  context)
                                                              .brightness),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: AppSpacing.md),

                                          // Add expense button
                                          OutlinedButton.icon(
                                            onPressed: () => _addOrEditEntry(
                                                context, isSpanish, p),
                                            icon: const Icon(Icons.add_rounded,
                                                size: 18),
                                            label: Text(s.addIrsExpense),
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
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                              );
                            }),

                          // Export PDF button
                          if (_properties.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
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
                              label: Text(s.exportScheduleE),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              s.consultTaxProfessional,
                              style: TextStyle(
                                  fontSize: AppTextSize.xs,
                                  color:
                                      CalcwiseTheme.of(context).textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            SaveScenarioButton(onSave: _saveScenario),
                            const SizedBox(height: AppSpacing.xxl),
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
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_rounded,
                size: 72,
                color: CalcwiseTheme.of(context)
                    .textSecondary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isSpanish ? 'Sin propiedades' : 'No properties',
              style: const TextStyle(
                  fontSize: AppTextSize.subtitle, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.addPropertiesFirst,
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
