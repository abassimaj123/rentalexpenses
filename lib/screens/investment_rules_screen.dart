import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:calcwise_core/calcwise_core.dart'
    show
        AppSpacing,
        AppRadius,
        AppTextSize,
        CalcwiseTheme,
        CalcwiseAdFooter,
        CalcwisePageEntrance,
        CalcwiseStaggerItem;
import '../core/firebase/analytics_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart' show isSpanishNotifier;

class InvestmentRulesScreen extends StatefulWidget {
  const InvestmentRulesScreen({super.key});

  @override
  State<InvestmentRulesScreen> createState() => _InvestmentRulesScreenState();
}

class _InvestmentRulesScreenState extends State<InvestmentRulesScreen> {
  final _rentCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _noiCtrl = TextEditingController();

  double? _onePercent;
  double? _onePercentTarget;
  double? _fiftyPercent;
  double? _capEx;
  double? _capRate;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('investment_rules');
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _priceCtrl.dispose();
    _noiCtrl.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) {
    final raw = c.text.replaceAll(',', '').replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(raw) ?? 0;
  }

  void _calculate() {
    final rent = _parse(_rentCtrl);
    final price = _parse(_priceCtrl);
    final noi = _parse(_noiCtrl);
    AnalyticsService.instance.maybeLogFirstCalculate();
    setState(() {
      if (rent > 0 && price > 0) {
        _onePercent = rent / price * 100;
        _onePercentTarget = price * 0.01;
      } else {
        _onePercent = null;
        _onePercentTarget = null;
      }

      if (rent > 0) {
        _fiftyPercent = rent * 0.5;
        _capEx = rent * 0.10;
      } else {
        _fiftyPercent = null;
        _capEx = null;
      }

      if (noi > 0 && price > 0) {
        _capRate = noi / price * 100;
      } else {
        _capRate = null;
      }
    });
  }

  String _fmt(double v) {
    if (v >= 1000) {
      return '\$${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    }
    return '\$${v.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (context, isSpanish, _) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        final ct = CalcwiseTheme.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(s.investmentRulesTitle),
            elevation: 0,
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // ── Inputs ──────────────────────────────────────────
                    _SectionLabel(
                        isSpanish ? 'DATOS DE LA PROPIEDAD' : 'PROPERTY DATA'),
                    const SizedBox(height: AppSpacing.sm),
                    _InputField(
                      controller: _rentCtrl,
                      label: s.monthlyRentIncome,
                      prefix: '\$',
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InputField(
                      controller: _priceCtrl,
                      label: s.propertyValue,
                      prefix: '\$',
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _InputField(
                      controller: _noiCtrl,
                      label: isSpanish ? 'NOI anual (\$)' : 'Annual NOI (\$)',
                      prefix: '\$',
                      onChanged: (_) => _calculate(),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (_onePercent != null) ...[
                      CalcwisePageEntrance(
                        child: Column(
                        children: [
                          // ── 1% Rule ─────────────────────────────────
                          CalcwiseStaggerItem(
                            index: 0,
                            child: _RuleCard(
                              icon: Icons.looks_one_rounded,
                              color: _onePercent! >= 1.0
                                  ? Colors.green.shade600
                                  : Colors.orange.shade700,
                              title: isSpanish ? 'Regla del 1%' : '1% Rule',
                              subtitle: isSpanish
                                  ? 'El alquiler mensual debe ser ≥ 1% del precio de compra'
                                  : 'Monthly rent should be ≥ 1% of purchase price',
                              passed: _onePercent! >= 1.0,
                              metrics: [
                                _Metric(
                                  label: isSpanish ? 'Tu ratio' : 'Your ratio',
                                  value:
                                      '${_onePercent!.toStringAsFixed(2)}%',
                                  highlight: true,
                                ),
                                _Metric(
                                  label: isSpanish
                                      ? 'Alquiler objetivo (1%)'
                                      : 'Target rent (1%)',
                                  value: _fmt(_onePercentTarget!),
                                ),
                              ],
                              verdict: _onePercent! >= 1.0
                                  ? (isSpanish
                                      ? '✅ Supera la prueba del 1%'
                                      : '✅ Passes the 1% test')
                                  : (isSpanish
                                      ? '⚠️ Por debajo del objetivo — revisar precio o alquiler'
                                      : '⚠️ Below target — review price or rent'),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // ── 50% Rule ────────────────────────────────
                          CalcwiseStaggerItem(
                            index: 1,
                            child: _RuleCard(
                              icon: Icons.pie_chart_rounded,
                              color: Colors.blue.shade700,
                              title: isSpanish ? 'Regla del 50%' : '50% Rule',
                              subtitle: isSpanish
                                  ? 'Estima el 50% del alquiler para gastos operativos (sin hipoteca)'
                                  : 'Estimate 50% of rent for operating expenses (excl. mortgage)',
                              passed: null,
                              metrics: [
                                _Metric(
                                  label: isSpanish
                                      ? 'Gastos estimados (50%)'
                                      : 'Estimated expenses (50%)',
                                  value: _fmt(_fiftyPercent!),
                                  highlight: true,
                                ),
                                _Metric(
                                  label: isSpanish
                                      ? 'Flujo máx. disponible'
                                      : 'Max cash available',
                                  value: _fmt(_fiftyPercent!),
                                ),
                              ],
                              verdict: isSpanish
                                  ? 'ℹ️ Reserva ${_fmt(_fiftyPercent!)} /mes para cubrir gastos sin hipoteca'
                                  : 'ℹ️ Budget ${_fmt(_fiftyPercent!)} /mo for expenses excl. mortgage',
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // ── CapEx Rule ──────────────────────────────
                          CalcwiseStaggerItem(
                            index: 2,
                            child: _RuleCard(
                              icon: Icons.build_rounded,
                              color: Colors.purple.shade600,
                              title: isSpanish
                                  ? 'Reserva CapEx (10%)'
                                  : 'CapEx Reserve (10%)',
                              subtitle: isSpanish
                                  ? 'Reserva el 10% del alquiler para reparaciones mayores y reemplazos'
                                  : 'Reserve 10% of rent for major repairs and capital replacements',
                              passed: null,
                              metrics: [
                                _Metric(
                                  label: isSpanish
                                      ? 'Reserva mensual'
                                      : 'Monthly reserve',
                                  value: _fmt(_capEx!),
                                  highlight: true,
                                ),
                                _Metric(
                                  label: isSpanish
                                      ? 'Reserva anual'
                                      : 'Annual reserve',
                                  value: _fmt(_capEx! * 12),
                                ),
                              ],
                              verdict: isSpanish
                                  ? 'ℹ️ Aparta ${_fmt(_capEx!)} /mes para techo, HVAC, electrodomésticos'
                                  : 'ℹ️ Set aside ${_fmt(_capEx!)} /mo for roof, HVAC, appliances',
                            ),
                          ),

                          if (_capRate != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            CalcwiseStaggerItem(
                              index: 3,
                              child: _RuleCard(
                                icon: Icons.trending_up_rounded,
                                color: _capRate! >= 6.0
                                    ? Colors.green.shade600
                                    : Colors.orange.shade700,
                                title: isSpanish ? 'Cap Rate' : 'Cap Rate',
                                subtitle: isSpanish
                                    ? 'NOI anual ÷ precio de compra. Objetivo: > 6%'
                                    : 'Annual NOI ÷ purchase price. Target: > 6%',
                                passed: _capRate! >= 6.0,
                                metrics: [
                                  _Metric(
                                    label: 'Cap Rate',
                                    value: '${_capRate!.toStringAsFixed(2)}%',
                                    highlight: true,
                                  ),
                                ],
                                verdict: _capRate! >= 6.0
                                    ? (isSpanish
                                        ? '✅ Cap rate sólido — rendimiento competitivo'
                                        : '✅ Strong cap rate — competitive yield')
                                    : (isSpanish
                                        ? '⚠️ Cap rate bajo — evaluar rentabilidad a largo plazo'
                                        : '⚠️ Low cap rate — evaluate long-term profitability'),
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ],

                    if (_onePercent == null)
                      _EmptyState(
                        isSpanish
                            ? 'Ingresa el alquiler y el precio de la propiedad para ver los resultados'
                            : 'Enter monthly rent and property price to see results',
                      ),

                    const SizedBox(height: AppSpacing.lg),
                    _Disclaimer(
                      isSpanish
                          ? 'Estas reglas son estimaciones rápidas para inversores. Consulta siempre a un profesional financiero antes de invertir.'
                          : 'These rules are quick heuristics for investors. Always consult a financial professional before investing.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
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

// ── Private widgets ─────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: AppTextSize.xs,
        fontWeight: FontWeight.w600,
        color: ct.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String prefix;
  final ValueChanged<String> onChanged;
  const _InputField({
    required this.controller,
    required this.label,
    required this.prefix,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
      ),
      onChanged: onChanged,
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final bool highlight;
  const _Metric({required this.label, required this.value, this.highlight = false});
}

class _RuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool? passed;
  final List<_Metric> metrics;
  final String verdict;

  const _RuleCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.passed,
    required this.metrics,
    required this.verdict,
  });

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: AppTextSize.body,
                            fontWeight: FontWeight.w700,
                            color: ct.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: AppTextSize.xs,
                            color: ct.textSecondary)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: metrics.map((m) => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label,
                        style: TextStyle(
                            fontSize: AppTextSize.xs,
                            color: ct.textSecondary)),
                    Text(m.value,
                        style: TextStyle(
                            fontSize: m.highlight ? 20 : AppTextSize.body,
                            fontWeight: m.highlight
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: m.highlight ? color : ct.textPrimary)),
                  ],
                ),
              )).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(verdict,
                  style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: ct.textPrimary,
                      height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);
  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: Column(children: [
          Icon(Icons.calculate_outlined, size: 48, color: ct.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: ct.textSecondary, fontSize: AppTextSize.sm)),
        ]),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  final String text;
  const _Disclaimer(this.text);
  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ct.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 16, color: ct.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: AppTextSize.xs,
                  color: ct.textSecondary,
                  height: 1.4)),
        ),
      ]),
    );
  }
}
