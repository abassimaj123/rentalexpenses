import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/calc/depreciation_calc.dart';
import '../core/constants/irs_categories.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../models/property_model.dart';
import '../models/schedule_e_entry_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';

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

  @override
  void initState() {
    super.initState();
    _inServiceMonth = _now.month;
    _inServiceYear = _now.year;
    _load();
  }

  @override
  void dispose() {
    _purchaseCtrl.dispose();
    _landCtrl.dispose();
    _improvementsCtrl.dispose();
    super.dispose();
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSpanish
            ? 'Depreciación agregada al Schedule E ($_inServiceYear)'
            : 'Depreciation added to Schedule E ($_inServiceYear)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
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
          appBar: AppBar(
            title: Text(isSpanish
                ? 'Calculadora de Depreciación'
                : 'Depreciation Calculator'),
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const CalcwiseLoadingState()
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          _SectionLabel(isSpanish
                              ? 'RESIDENCIAL US — 27.5 AÑOS'
                              : 'US RESIDENTIAL — 27.5 YEARS'),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _moneyField(
                                    _purchaseCtrl,
                                    isSpanish
                                        ? 'Precio de compra (\$)'
                                        : 'Purchase price (\$)',
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _moneyField(
                                    _landCtrl,
                                    isSpanish
                                        ? 'Valor del terreno (\$) — no depreciable'
                                        : 'Land value (\$) — not depreciable',
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  _moneyField(
                                    _improvementsCtrl,
                                    isSpanish
                                        ? 'Mejoras de capital (\$) — opcional'
                                        : 'Capital improvements (\$) — optional',
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: [
                                      Expanded(
                                        child:
                                            DropdownButtonFormField<int>(
                                          initialValue: _inServiceMonth,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                            labelText: isSpanish
                                                ? 'Mes en servicio'
                                                : 'In-service month',
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
                                          onChanged: (v) => setState(() =>
                                              _inServiceMonth =
                                                  v ?? _inServiceMonth),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      Expanded(
                                        child: DropdownButtonFormField<int>(
                                          initialValue: _inServiceYear,
                                          decoration: InputDecoration(
                                            labelText:
                                                isSpanish ? 'Año' : 'Year',
                                          ),
                                          items: years
                                              .map((y) => DropdownMenuItem(
                                                    value: y,
                                                    child: Text('$y'),
                                                  ))
                                              .toList(),
                                          onChanged: (v) => setState(() =>
                                              _inServiceYear =
                                                  v ?? _inServiceYear),
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
                                  isSpanish
                                      ? 'Los valores no pueden ser negativos.'
                                      : 'Values cannot be negative.',
                                  style: TextStyle(
                                      color: CalcwiseSemanticColors.error(
                                          Theme.of(context).brightness)),
                                ),
                              ),
                            )
                          else ...[
                            _SectionLabel(
                                isSpanish ? 'RESULTADO' : 'RESULT'),
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Column(
                                  children: [
                                    _ResultRow(
                                      label: isSpanish
                                          ? 'Base depreciable'
                                          : 'Depreciable basis',
                                      value:
                                          '\$${AmountFormatter.formatNumber(_basis)}',
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    _ResultRow(
                                      label: isSpanish
                                          ? 'Depreciación anual (÷ 27.5)'
                                          : 'Annual depreciation (÷ 27.5)',
                                      value:
                                          '\$${AmountFormatter.formatNumber(_annual)}',
                                    ),
                                    Divider(
                                        height: 22,
                                        color: CalcwiseTheme.of(context)
                                            .cardBorder),
                                    _ResultRow(
                                      label: isSpanish
                                          ? '1er año (mid-month, $_inServiceYear)'
                                          : '1st year (mid-month, $_inServiceYear)',
                                      value:
                                          '\$${AmountFormatter.formatNumber(_firstYear)}',
                                      bold: true,
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            if (_properties.isEmpty)
                              Text(
                                isSpanish
                                    ? 'Agrega una propiedad para guardar la depreciación en el Schedule E.'
                                    : 'Add a property to save depreciation to Schedule E.',
                                style: TextStyle(
                                    color: CalcwiseTheme.of(context)
                                        .textSecondary),
                              )
                            else ...[
                              DropdownButtonFormField<String>(
                                initialValue: _selectedProperty?.id,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: isSpanish
                                      ? 'Propiedad'
                                      : 'Property',
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
                                label: Text(isSpanish
                                    ? 'Agregar al Schedule E'
                                    : 'Add to Schedule E'),
                                style: ElevatedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 48)),
                              ),
                            ],
                          ],
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            isSpanish
                                ? 'Estimación de depreciación lineal (MACRS GDS, 27.5 años, convención de medio mes). El terreno no es depreciable. Consulta a un profesional fiscal.'
                                : 'Straight-line depreciation estimate (MACRS GDS, 27.5 years, mid-month convention). Land is not depreciable. Consult a tax professional.',
                            style: TextStyle(
                                fontSize: AppTextSize.xs,
                                color:
                                    CalcwiseTheme.of(context).textSecondary),
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
