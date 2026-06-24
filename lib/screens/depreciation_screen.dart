import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/calc/depreciation_calc.dart';
import '../core/constants/irs_categories.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/services/pdf_export_service.dart';
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

/// Straight-line depreciation calculator for US residential rental property
/// (27.5-year MACRS GDS, mid-month convention). See [DepreciationCalc].
class DepreciationScreen extends StatefulWidget {
  const DepreciationScreen({super.key});

  @override
  State<DepreciationScreen> createState() => _DepreciationScreenState();
}

class _DepreciationScreenState extends State<DepreciationScreen> {
  final _now = DateTime.now();

  final _purchaseCtrl = TextEditingController();
  final _landCtrl = TextEditingController();
  final _improvementsCtrl = TextEditingController();

  List<Property> _properties = [];
  Property? _selectedProperty;
  late int _inServiceMonth;
  late int _inServiceYear;
  bool _loading = true;
  String? _currentHash;

  @override
  void initState() {
    super.initState();
    _inServiceMonth = _now.month;
    _inServiceYear = _now.year;
    AnalyticsService.instance.logScreenView('depreciation');
    _load();
    _purchaseCtrl.addListener(_onInputChanged);
    _landCtrl.addListener(_onInputChanged);
    _improvementsCtrl.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    smartHistoryService.cancelPendingSave('rentalexpenses', 'depreciation');
    _purchaseCtrl.dispose();
    _landCtrl.dispose();
    _improvementsCtrl.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    if (_basis > 0) _scheduleAutoSave();
  }

  Future<void> _load() async {
    final props = await PropertyDatabaseService.instance.getAllProperties();
    if (mounted) {
      setState(() {
        _properties = props;
        _selectedProperty = props.isNotEmpty ? props.first : null;
        _loading = false;
      });
    }
  }

  double get _purchase =>
      double.tryParse(_purchaseCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _land => double.tryParse(_landCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _improvements =>
      double.tryParse(_improvementsCtrl.text.replaceAll(',', '.')) ?? 0;

  bool get _hasNegativeInput => _purchase < 0 || _land < 0 || _improvements < 0;

  double get _basis => DepreciationCalc.depreciableBasis(
        purchasePrice: _purchase,
        landValue: _land,
        improvements: _improvements,
      );

  double get _annual => DepreciationCalc.annualDepreciation(
        purchasePrice: _purchase,
        landValue: _land,
        improvements: _improvements,
      );

  double get _firstYear => DepreciationCalc.firstYearDepreciation(
        purchasePrice: _purchase,
        landValue: _land,
        inServiceMonth: _inServiceMonth,
        improvements: _improvements,
      );

  // ── SmartHistory helpers ────────────────────────────────────────────────────

  double _roundTo(double v, double step) => (v / step).round() * step;

  void _scheduleAutoSave() {
    final hash = ResultHasher.hashInputs({
      'purchase': _roundTo(_purchase, 5000),
      'land': _roundTo(_land, 5000),
      'improvements': _roundTo(_improvements, 5000),
      'in_service_year': _inServiceYear.toDouble(),
    });
    _currentHash = hash;
    smartHistoryService.scheduleAutoSave(
      appKey: 'rentalexpenses',
      screenId: 'depreciation',
      inputHash: hash,
      l1: {
        'purchase_price': _purchase,
        'land_value': _land,
        'annual_depreciation': _annual,
        'accumulated_depreciation': _firstYear,
      },
      l2: {
        'inputs': {
          'purchase_price': _purchase,
          'land_value': _land,
          'improvements': _improvements,
          'in_service_month': _inServiceMonth,
          'in_service_year': _inServiceYear,
        },
        'results': {
          'depreciable_basis': _basis,
          'annual_depreciation': _annual,
          'first_year_depreciation': _firstYear,
        },
      },
    );
  }

  Future<void> _saveScenario(String? label) async {
    final hash = _currentHash;
    if (hash == null || _basis <= 0) return;
    await smartHistoryService.saveScenario(
      appKey: 'rentalexpenses',
      screenId: 'depreciation',
      inputHash: hash,
      l1: {
        'purchase_price': _purchase,
        'land_value': _land,
        'annual_depreciation': _annual,
        'accumulated_depreciation': _firstYear,
      },
      l2: {
        'inputs': {
          'purchase_price': _purchase,
          'land_value': _land,
          'improvements': _improvements,
          'in_service_month': _inServiceMonth,
          'in_service_year': _inServiceYear,
        },
        'results': {
          'depreciable_basis': _basis,
          'annual_depreciation': _annual,
          'first_year_depreciation': _firstYear,
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
    if (_basis <= 0) return;
    HapticFeedback.mediumImpact();

    Future<void> doExport() => PdfExportService.exportDepreciation(
          context: context,
          purchasePrice: _purchase,
          landValue: _land,
          improvements: _improvements,
          depreciableBasis: _basis,
          annualDepreciation: _annual,
          firstYearDepreciation: _firstYear,
          inServiceMonth: _inServiceMonth,
          inServiceYear: _inServiceYear,
          propertyName: _selectedProperty?.name ?? '',
          isSpanish: isSpanish,
        );

    if (freemiumService.hasFullAccess) {
      await doExport();
      await AnalyticsService.instance.logPdfExported();
    } else {
      await PdfExportService.showUnlockOrPay(context, doExport);
    }
  }

  Future<void> _addToScheduleE(bool isSpanish) async {
    if (!freemiumService.hasFullAccess) {
      await PaywallHard.show(context);
      return;
    }
    final property = _selectedProperty;
    if (property == null) return;
    if (_basis <= 0) return;

    final entry = ScheduleEEntry(
      id: 'sche_dep_${property.id}_${_inServiceYear}_${DateTime.now().millisecondsSinceEpoch}',
      propertyId: property.id,
      year: _inServiceYear,
      category: IrsCategories.depreciation,
      amount: double.parse(_firstYear.toStringAsFixed(2)),
    );
    await PropertyDatabaseService.instance.insertScheduleEEntry(entry);
    await AnalyticsService.instance.logDepreciationAddedToScheduleE();
    if (!mounted) return;
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.depreciationAddedScheduleE(_inServiceYear))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        final months = isSpanish
            ? const [
                'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
                'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre',
                'Diciembre'
              ]
            : const [
                'January', 'February', 'March', 'April', 'May', 'June',
                'July', 'August', 'September', 'October', 'November', 'December'
              ];
        final years = List.generate(6, (i) => _now.year - i);
        final invalid = _hasNegativeInput;

        return Scaffold(
          appBar: AppBar(title: Text(s.depreciationCalculator)),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const CalcwiseLoadingState()
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          _SectionLabel(s.usResidential27),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _moneyField(_purchaseCtrl, s.purchasePrice),
                                  const SizedBox(height: AppSpacing.md),
                                  _moneyField(_landCtrl, s.landValue),
                                  const SizedBox(height: AppSpacing.md),
                                  _moneyField(_improvementsCtrl, s.capitalImprovements),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: _inServiceMonth,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: s.inServiceMonth,
                                          ),
                                          items: [
                                            for (var m = 1; m <= 12; m++)
                                              DropdownMenuItem(
                                                value: m,
                                                child: Text(months[m - 1],
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                          ],
                                          onChanged: (v) {
                                            setState(() => _inServiceMonth =
                                                v ?? _inServiceMonth);
                                            if (_basis > 0) _scheduleAutoSave();
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: _inServiceYear,
                                          decoration: InputDecoration(
                                            labelText: s.year,
                                          ),
                                          items: years
                                              .map((y) => DropdownMenuItem(
                                                    value: y,
                                                    child: Text('$y'),
                                                  ))
                                              .toList(),
                                          onChanged: (v) {
                                            setState(() => _inServiceYear =
                                                v ?? _inServiceYear);
                                            if (_basis > 0) _scheduleAutoSave();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          if (invalid)
                            Card(
                              color: CalcwiseSemanticColors.error(
                                      Theme.of(context).brightness)
                                  .withValues(alpha: 0.08),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Text(
                                  s.valuesCannotBeNegative,
                                  style: TextStyle(
                                      color: CalcwiseSemanticColors.error(
                                          Theme.of(context).brightness)),
                                ),
                              ),
                            )
                          else ...[
                            _SectionLabel(s.result),
                            CalcwisePageEntrance(child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  children: [
                                    _ResultRow(
                                      label: s.depreciableBasis,
                                      value: '\$${AmountFormatter.formatNumber(_basis)}',
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _ResultRow(
                                      label: s.annualDepreciation27,
                                      value: '\$${AmountFormatter.formatNumber(_annual)}',
                                    ),
                                    Divider(
                                        height: 22,
                                        color: CalcwiseTheme.of(context)
                                            .cardBorder),
                                    _ResultRow(
                                      label: s.firstYearMidMonth(_inServiceYear),
                                      value: '\$${AmountFormatter.formatNumber(_firstYear)}',
                                      bold: true,
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            )), // CalcwisePageEntrance closes
                            const SizedBox(height: AppSpacing.lg),

                            if (_properties.isEmpty)
                              Text(
                                s.addPropertyForScheduleE,
                                style: TextStyle(
                                    color: CalcwiseTheme.of(context)
                                        .textSecondary),
                              )
                            else ...[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedProperty?.id,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: s.property,
                                ),
                                items: _properties
                                    .map((p) => DropdownMenuItem(
                                          value: p.id,
                                          child: Text(p.name,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _selectedProperty = _properties
                                      .firstWhere((p) => p.id == v);
                                }),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton.icon(
                                onPressed: _basis > 0
                                    ? () => _addToScheduleE(isSpanish)
                                    : null,
                                icon: const Icon(Icons.add_chart_rounded),
                                label: Text(s.addToScheduleE),
                                style: ElevatedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 48)),
                              ),
                            ],
                          ],
                          if (_basis > 0) ...[
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
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            s.depreciationDisclaimer,
                            style: TextStyle(
                                fontSize: AppTextSize.xs,
                                color: CalcwiseTheme.of(context).textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
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

  Widget _moneyField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
      ],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, prefixText: '\$'),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _ResultRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: AppTextSize.body,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: CalcwiseTheme.of(context).textSecondary)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: bold ? AppTextSize.bodyLg : AppTextSize.body,
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                color: color)),
      ],
    );
  }
}
