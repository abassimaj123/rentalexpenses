import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/ads/ad_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/paywall_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/paywall_hard.dart';

// ── Data model ────────────────────────────────────────────────────────────────

class ExpenseCalc {
  final String propertyName;
  final double rentIncome;
  final double mortgage;
  final double propertyTaxes;
  final double insurance;
  final double hoaFees;
  final double propertyMgmt; // stored as $
  final double maintenance;
  final double vacancyLoss;  // stored as $
  final double utilities;
  final double landscaping;
  final double otherExpenses;
  final DateTime savedAt;

  ExpenseCalc({
    required this.propertyName,
    required this.rentIncome,
    required this.mortgage,
    required this.propertyTaxes,
    required this.insurance,
    required this.hoaFees,
    required this.propertyMgmt,
    required this.maintenance,
    required this.vacancyLoss,
    required this.utilities,
    required this.landscaping,
    required this.otherExpenses,
    required this.savedAt,
  });

  double get totalExpenses =>
      mortgage + propertyTaxes + insurance + hoaFees + propertyMgmt +
      maintenance + vacancyLoss + utilities + landscaping + otherExpenses;

  double get monthlyCashFlow => rentIncome - totalExpenses;
  double get annualCashFlow  => monthlyCashFlow * 12;
  double get expenseRatio    => rentIncome > 0 ? (totalExpenses / rentIncome * 100) : 0;
  double get breakEvenRent   => totalExpenses;

  /// NOI = Annual (Rent - expenses EXCLUDING mortgage)
  double get noi =>
      (rentIncome - (totalExpenses - mortgage)) * 12;

  Map<String, double> get breakdown => {
    'Mortgage':            mortgage,
    'Property Taxes':      propertyTaxes,
    'Insurance':           insurance,
    'HOA Fees':            hoaFees,
    'Property Mgmt':       propertyMgmt,
    'Maintenance':         maintenance,
    'Vacancy Loss':        vacancyLoss,
    'Utilities':           utilities,
    'Landscaping':         landscaping,
    'Other':               otherExpenses,
  };

  Map<String, double> get breakdownES => {
    'Hipoteca':            mortgage,
    'Impuestos':           propertyTaxes,
    'Seguro':              insurance,
    'HOA':                 hoaFees,
    'Adm. propiedad':      propertyMgmt,
    'Mantenimiento':       maintenance,
    'Vacante':             vacancyLoss,
    'Servicios':           utilities,
    'Jardinería':          landscaping,
    'Otros':               otherExpenses,
  };

  Map<String, dynamic> toJson() => {
    'propertyName':  propertyName,
    'rentIncome':    rentIncome,
    'mortgage':      mortgage,
    'propertyTaxes': propertyTaxes,
    'insurance':     insurance,
    'hoaFees':       hoaFees,
    'propertyMgmt':  propertyMgmt,
    'maintenance':   maintenance,
    'vacancyLoss':   vacancyLoss,
    'utilities':     utilities,
    'landscaping':   landscaping,
    'otherExpenses': otherExpenses,
    'savedAt':       savedAt.toIso8601String(),
  };

  factory ExpenseCalc.fromJson(Map<String, dynamic> j) => ExpenseCalc(
    propertyName:  j['propertyName']  as String,
    rentIncome:    (j['rentIncome']    as num).toDouble(),
    mortgage:      (j['mortgage']      as num).toDouble(),
    propertyTaxes: (j['propertyTaxes'] as num).toDouble(),
    insurance:     (j['insurance']     as num).toDouble(),
    hoaFees:       (j['hoaFees']       as num).toDouble(),
    propertyMgmt:  (j['propertyMgmt']  as num).toDouble(),
    maintenance:   (j['maintenance']   as num).toDouble(),
    vacancyLoss:   (j['vacancyLoss']   as num).toDouble(),
    utilities:     (j['utilities']     as num).toDouble(),
    landscaping:   (j['landscaping']   as num).toDouble(),
    otherExpenses: (j['otherExpenses'] as num).toDouble(),
    savedAt:       DateTime.parse(j['savedAt'] as String),
  );
}

// ── History helpers ───────────────────────────────────────────────────────────

const _prefKey = 'expense_history_v1';

Future<List<ExpenseCalc>> loadHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_prefKey) ?? [];
  return raw.map((s) {
    try { return ExpenseCalc.fromJson(jsonDecode(s) as Map<String, dynamic>); }
    catch (_) { return null; }
  }).whereType<ExpenseCalc>().toList();
}

Future<void> saveToHistory(ExpenseCalc calc) async {
  final prefs  = await SharedPreferences.getInstance();
  final limit  = freemiumService.historyLimit;
  final raw    = prefs.getStringList(_prefKey) ?? [];
  final list   = raw.map((s) {
    try { return ExpenseCalc.fromJson(jsonDecode(s) as Map<String, dynamic>); }
    catch (_) { return null; }
  }).whereType<ExpenseCalc>().toList();

  list.insert(0, calc);
  if (list.length > limit) list.removeRange(limit, list.length);
  await prefs.setStringList(
      _prefKey, list.map((c) => jsonEncode(c.toJson())).toList());
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CalculatorScreen extends StatefulWidget {
  /// If non-null, the screen loads this calculation on init.
  final ExpenseCalc? preload;
  const CalculatorScreen({super.key, this.preload});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  // Controllers
  final _nameCtrl  = TextEditingController();
  final _rentCtrl  = TextEditingController();
  final _mortCtrl  = TextEditingController();
  final _taxCtrl   = TextEditingController();
  final _insCtrl   = TextEditingController();
  final _hoaCtrl   = TextEditingController();
  final _mgmtCtrl  = TextEditingController();
  final _maintCtrl = TextEditingController();
  final _vacCtrl   = TextEditingController();
  final _utilCtrl  = TextEditingController();
  final _landCtrl  = TextEditingController();
  final _otherCtrl = TextEditingController();

  // Toggles
  bool _mgmtIsPercent = true;   // true = % of rent, false = $
  bool _vacIsPercent  = true;   // vacancy loss % of rent

  // Computed result
  ExpenseCalc? _result;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    if (widget.preload != null) _populateFrom(widget.preload!);
    for (final c in _allControllers) {
      c.addListener(_clearSaved);
    }
  }

  List<TextEditingController> get _allControllers => [
    _nameCtrl, _rentCtrl, _mortCtrl, _taxCtrl, _insCtrl, _hoaCtrl,
    _mgmtCtrl, _maintCtrl, _vacCtrl, _utilCtrl, _landCtrl, _otherCtrl,
  ];

  void _clearSaved() => setState(() => _saved = false);

  void _populateFrom(ExpenseCalc c) {
    _nameCtrl.text  = c.propertyName;
    _rentCtrl.text  = c.rentIncome    > 0 ? c.rentIncome.toStringAsFixed(2) : '';
    _mortCtrl.text  = c.mortgage      > 0 ? c.mortgage.toStringAsFixed(2) : '';
    _taxCtrl.text   = c.propertyTaxes > 0 ? c.propertyTaxes.toStringAsFixed(2) : '';
    _insCtrl.text   = c.insurance     > 0 ? c.insurance.toStringAsFixed(2) : '';
    _hoaCtrl.text   = c.hoaFees       > 0 ? c.hoaFees.toStringAsFixed(2) : '';
    _maintCtrl.text = c.maintenance   > 0 ? c.maintenance.toStringAsFixed(2) : '';
    _utilCtrl.text  = c.utilities     > 0 ? c.utilities.toStringAsFixed(2) : '';
    _landCtrl.text  = c.landscaping   > 0 ? c.landscaping.toStringAsFixed(2) : '';
    _otherCtrl.text = c.otherExpenses > 0 ? c.otherExpenses.toStringAsFixed(2) : '';
    // For loaded entries, always show raw $ values for mgmt & vacancy
    _mgmtIsPercent = false;
    _vacIsPercent  = false;
    _mgmtCtrl.text = c.propertyMgmt > 0 ? c.propertyMgmt.toStringAsFixed(2) : '';
    _vacCtrl.text  = c.vacancyLoss  > 0 ? c.vacancyLoss.toStringAsFixed(2) : '';
  }

  double _parseD(TextEditingController c) {
    final v = c.text;
    if (v.isEmpty) return 0.0;
    final s = (v.contains('.') && v.contains(','))
        ? v.replaceAll(',', '')
        : v.replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  void _calculate(bool isSpanish) {
    final rent     = _parseD(_rentCtrl);
    final mortgage = _parseD(_mortCtrl);
    final taxes    = _parseD(_taxCtrl);
    final ins      = _parseD(_insCtrl);
    final hoa      = _parseD(_hoaCtrl);
    final maintenance = _parseD(_maintCtrl);
    final utilities   = _parseD(_utilCtrl);
    final landscaping = _parseD(_landCtrl);
    final other       = _parseD(_otherCtrl);

    final mgmtRaw = _parseD(_mgmtCtrl);
    final mgmtDollar = _mgmtIsPercent ? (rent * mgmtRaw / 100) : mgmtRaw;

    final vacRaw = _parseD(_vacCtrl);
    final vacDollar = _vacIsPercent ? (rent * vacRaw / 100) : vacRaw;

    final calc = ExpenseCalc(
      propertyName:  _nameCtrl.text.trim().isEmpty
          ? (isSpanish ? 'Mi Propiedad' : 'My Property')
          : _nameCtrl.text.trim(),
      rentIncome:    rent,
      mortgage:      mortgage,
      propertyTaxes: taxes,
      insurance:     ins,
      hoaFees:       hoa,
      propertyMgmt:  mgmtDollar,
      maintenance:   maintenance,
      vacancyLoss:   vacDollar,
      utilities:     utilities,
      landscaping:   landscaping,
      otherExpenses: other,
      savedAt:       DateTime.now(),
    );

    setState(() {
      _result = calc;
      _saved  = false;
    });

    AdService.instance.onCalculation();
    final trigger = paywallService.recordAction();
    if (trigger != PaywallTrigger.none && mounted) PaywallHard.show(context);
  }

  Future<void> _save(bool isSpanish) async {
    if (_result == null) return;
    final isPremium = freemiumService.isPremium;
    final history   = await loadHistory();
    if (!isPremium && history.length >= FreemiumService.freeHistoryLimit) {
      if (mounted) PaywallHard.show(context);
      return;
    }
    await saveToHistory(_result!);
    if (mounted) setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isSpanish ? 'Guardado en historial' : 'Saved to history'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _reset() {
    for (final c in _allControllers) c.clear();
    setState(() { _result = null; _saved = false; });
  }

  @override
  void dispose() {
    for (final c in _allControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish
                ? 'Gastos de Alquiler'
                : 'Rental Expenses'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: isSpanish ? 'Reiniciar' : 'Reset',
                onPressed: _reset,
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // ── Property Setup ──────────────────────────────────
                    _SectionLabel(isSpanish ? 'Información de la Propiedad' : 'Property Setup'),
                    _buildCard([
                      _TextField(
                        ctrl: _nameCtrl,
                        label: isSpanish ? 'Nombre de la propiedad' : 'Property Name',
                        hint: isSpanish ? 'Ej: Casa Principal' : 'e.g. Main St Duplex',
                        isNumeric: false,
                        prefix: null,
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        ctrl: _rentCtrl,
                        label: isSpanish ? 'Ingreso mensual de alquiler' : 'Monthly Rent Income',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Expense Categories ──────────────────────────────
                    _SectionLabel(isSpanish ? 'Gastos Mensuales' : 'Monthly Expenses'),
                    _buildCard([
                      _TextField(
                        ctrl: _mortCtrl,
                        label: isSpanish ? 'Pago de hipoteca' : 'Mortgage Payment',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        ctrl: _taxCtrl,
                        label: isSpanish
                            ? 'Impuestos de propiedad (anual ÷ 12)'
                            : 'Property Taxes (annual ÷ 12)',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        ctrl: _insCtrl,
                        label: isSpanish ? 'Seguro de propietario' : 'Homeowner\'s Insurance',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        ctrl: _hoaCtrl,
                        label: isSpanish ? 'Cuotas HOA' : 'HOA Fees',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                    ]),
                    const SizedBox(height: 12),

                    // Property Mgmt toggle card
                    _buildCard([
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSpanish
                                  ? 'Adm. de propiedad'
                                  : 'Property Management',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.labelGray),
                            ),
                          ),
                          _ToggleChip(
                            labelA: '%',
                            labelB: '\$',
                            isA: _mgmtIsPercent,
                            onChanged: (v) =>
                                setState(() => _mgmtIsPercent = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _TextField(
                        ctrl: _mgmtCtrl,
                        label: _mgmtIsPercent
                            ? (isSpanish ? '% del alquiler' : '% of rent')
                            : (isSpanish ? 'Cantidad mensual' : 'Monthly amount'),
                        hint: '0.00',
                        isNumeric: true,
                        prefix: _mgmtIsPercent ? null : '\$',
                        suffix: _mgmtIsPercent ? '%' : null,
                      ),
                    ]),
                    const SizedBox(height: 12),

                    _buildCard([
                      _TextField(
                        ctrl: _maintCtrl,
                        label: isSpanish ? 'Mantenimiento / Reparaciones' : 'Maintenance / Repairs',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                      const SizedBox(height: 12),
                      // Vacancy toggle
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              isSpanish ? 'Pérdida por vacante' : 'Vacancy Loss',
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.labelGray),
                            ),
                          ),
                          _ToggleChip(
                            labelA: '%',
                            labelB: '\$',
                            isA: _vacIsPercent,
                            onChanged: (v) =>
                                setState(() => _vacIsPercent = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _TextField(
                        ctrl: _vacCtrl,
                        label: _vacIsPercent
                            ? (isSpanish ? '% del alquiler' : '% of rent')
                            : (isSpanish ? 'Pérdida mensual (\$)' : 'Monthly loss (\$)'),
                        hint: '0.00',
                        isNumeric: true,
                        prefix: _vacIsPercent ? null : '\$',
                        suffix: _vacIsPercent ? '%' : null,
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        ctrl: _utilCtrl,
                        label: isSpanish ? 'Servicios públicos' : 'Utilities',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        ctrl: _landCtrl,
                        label: isSpanish ? 'Jardinería / Paisajismo' : 'Landscaping',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                      const SizedBox(height: 12),
                      _TextField(
                        ctrl: _otherCtrl,
                        label: isSpanish ? 'Otros gastos' : 'Other Expenses',
                        hint: '0.00',
                        isNumeric: true,
                        prefix: '\$',
                      ),
                    ]),
                    const SizedBox(height: 20),

                    // ── Calculate button ────────────────────────────────
                    ElevatedButton.icon(
                      onPressed: () => _calculate(isSpanish),
                      icon: const Icon(Icons.calculate_rounded),
                      label: Text(
                        isSpanish ? 'Calcular Gastos' : 'Calculate Expenses',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Results ─────────────────────────────────────────
                    if (_result != null) ...[
                      _ResultsSection(
                        calc: _result!,
                        fmt: _fmt,
                        isSpanish: isSpanish,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saved ? null : () => _save(isSpanish),
                              icon: Icon(_saved
                                  ? Icons.check_circle_rounded
                                  : Icons.save_rounded),
                              label: Text(_saved
                                  ? (isSpanish ? 'Guardado' : 'Saved')
                                  : (isSpanish ? 'Guardar' : 'Save')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _saved ? AppTheme.success : AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
              const BannerAdWidget(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      );
}

// ── Results Section ───────────────────────────────────────────────────────────

class _ResultsSection extends StatelessWidget {
  final ExpenseCalc calc;
  final NumberFormat fmt;
  final bool isSpanish;

  const _ResultsSection({
    required this.calc,
    required this.fmt,
    required this.isSpanish,
  });

  @override
  Widget build(BuildContext context) {
    final cf = calc.monthlyCashFlow;
    final cfColor = cf >= 0 ? AppTheme.success : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(isSpanish ? 'Resultados' : 'Results'),

        // Summary cards
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ResultRow(
                  label: isSpanish
                      ? 'Total gastos mensuales'
                      : 'Total Monthly Expenses',
                  value: '\$${fmt.format(calc.totalExpenses)}',
                  bold: true,
                ),
                const Divider(height: 24, color: AppTheme.divider),
                _ResultRow(
                  label: isSpanish
                      ? 'Flujo de caja mensual'
                      : 'Monthly Cash Flow',
                  value: '${cf < 0 ? '-' : ''}\$${fmt.format(cf.abs())}',
                  valueColor: cfColor,
                  bold: true,
                ),
                const SizedBox(height: 8),
                _ResultRow(
                  label: isSpanish
                      ? 'Flujo de caja anual'
                      : 'Annual Cash Flow',
                  value: '${calc.annualCashFlow < 0 ? '-' : ''}\$${fmt.format(calc.annualCashFlow.abs())}',
                  valueColor: cfColor,
                ),
                const SizedBox(height: 8),
                _ResultRow(
                  label: isSpanish
                      ? 'Ratio de gastos'
                      : 'Expense Ratio',
                  value: '${calc.expenseRatio.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 8),
                _ResultRow(
                  label: isSpanish
                      ? 'Alquiler mínimo necesario'
                      : 'Break-Even Rent',
                  value: '\$${fmt.format(calc.breakEvenRent)}',
                ),
                const SizedBox(height: 8),
                _ResultRow(
                  label: isSpanish
                      ? 'Ingreso operativo neto (NOI anual)'
                      : 'Net Operating Income (Annual NOI)',
                  value: '\$${fmt.format(calc.noi)}',
                  valueColor: calc.noi >= 0 ? AppTheme.success : Colors.red,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Cash flow indicator banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: cfColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cfColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                cf >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: cfColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                cf >= 0
                    ? (isSpanish
                        ? 'Flujo de caja positivo — propiedad rentable'
                        : 'Positive cash flow — property is profitable')
                    : (isSpanish
                        ? 'Flujo de caja negativo — revisar gastos'
                        : 'Negative cash flow — review your expenses'),
                style: TextStyle(
                    color: cfColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Expense breakdown
        _SectionLabel(
            isSpanish ? 'Desglose de Gastos' : 'Expense Breakdown'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _BreakdownList(calc: calc, fmt: fmt, isSpanish: isSpanish),
          ),
        ),
      ],
    );
  }
}

class _BreakdownList extends StatelessWidget {
  final ExpenseCalc calc;
  final NumberFormat fmt;
  final bool isSpanish;

  const _BreakdownList({
    required this.calc,
    required this.fmt,
    required this.isSpanish,
  });

  static const List<Color> _palette = [
    Color(0xFFC8102E),
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
    Color(0xFF65A30D),
    Color(0xFF9333EA),
    Color(0xFF0D9488),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = (isSpanish ? calc.breakdownES : calc.breakdown).entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = calc.totalExpenses;

    if (entries.isEmpty) {
      return Text(
        isSpanish ? 'Sin gastos ingresados' : 'No expenses entered',
        style: const TextStyle(color: AppTheme.labelGray),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _BreakdownRow(
            label: entries[i].key,
            amount: entries[i].value,
            pct: total > 0 ? entries[i].value / total * 100 : 0,
            color: _palette[i % _palette.length],
            fmt: fmt,
          ),
        ],
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double amount;
  final double pct;
  final Color color;
  final NumberFormat fmt;

  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.pct,
    required this.color,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13)),
            ),
            Text(
              '\$${fmt.format(amount)}',
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Text(
                '${pct.toStringAsFixed(1)}%',
                textAlign: TextAlign.end,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.labelGray),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 5,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.labelGray,
              letterSpacing: 0.6),
        ),
      );
}

class _TextField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool isNumeric;
  final String? prefix;
  final String? suffix;

  const _TextField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.isNumeric,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters:
          isNumeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))] : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String labelA;
  final String labelB;
  final bool isA;
  final ValueChanged<bool> onChanged;

  const _ToggleChip({
    required this.labelA,
    required this.labelB,
    required this.isA,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(value: true,  label: Text(labelA)),
        ButtonSegment(value: false, label: Text(labelB)),
      ],
      selected: {isA},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppTheme.primary;
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  const _ResultRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15 : 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
