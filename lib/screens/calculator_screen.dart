import 'dart:async';
import 'dart:convert';
import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/services/pdf_export_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../widgets/insight_card.dart';
import '../widgets/paywall_hard.dart';
import '../widgets/paywall_soft.dart';
import '../widgets/save_scenario_button.dart';
import '../core/insight_engine.dart';

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
  final double vacancyLoss; // stored as $
  final double utilities;
  final double landscaping;
  final double otherExpenses;
  final DateTime savedAt;
  // ── Investor metrics (optional) ─────────────────────────────────────────
  final double propertyValue; // purchase price / current market value
  final double cashInvested; // down payment + closing costs + rehab

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
    this.propertyValue = 0,
    this.cashInvested = 0,
  });

  double get totalExpenses =>
      mortgage +
      propertyTaxes +
      insurance +
      hoaFees +
      propertyMgmt +
      maintenance +
      vacancyLoss +
      utilities +
      landscaping +
      otherExpenses;

  double get monthlyCashFlow => rentIncome - totalExpenses;
  double get annualCashFlow => monthlyCashFlow * 12;
  double get expenseRatio =>
      rentIncome > 0 ? (totalExpenses / rentIncome * 100) : 0;
  double get breakEvenRent => totalExpenses;

  /// NOI = Annual (Rent - expenses EXCLUDING mortgage)
  double get noi => (rentIncome - (totalExpenses - mortgage)) * 12;

  /// Cap Rate = Annual NOI / Property Value × 100
  double? get capRate => propertyValue > 0 ? (noi / propertyValue * 100) : null;

  /// Gross Yield = Annual Rent / Property Value × 100
  double? get grossYield =>
      propertyValue > 0 ? (rentIncome * 12 / propertyValue * 100) : null;

  /// Cash-on-Cash ROI = Annual Cash Flow / Cash Invested × 100
  double? get cocRoi =>
      cashInvested > 0 ? (annualCashFlow / cashInvested * 100) : null;

  Map<String, double> get breakdown => {
        'Mortgage': mortgage,
        'Property Taxes': propertyTaxes,
        'Insurance': insurance,
        'HOA Fees': hoaFees,
        'Property Mgmt': propertyMgmt,
        'Maintenance': maintenance,
        'Vacancy Loss': vacancyLoss,
        'Utilities': utilities,
        'Landscaping': landscaping,
        'Other': otherExpenses,
      };

  Map<String, double> get breakdownES => {
        'Hipoteca': mortgage,
        'Impuestos': propertyTaxes,
        'Seguro': insurance,
        'HOA': hoaFees,
        'Adm. propiedad': propertyMgmt,
        'Mantenimiento': maintenance,
        'Vacante': vacancyLoss,
        'Servicios': utilities,
        'Jardinería': landscaping,
        'Otros': otherExpenses,
      };

  Map<String, dynamic> toJson() => {
        'propertyName': propertyName,
        'rentIncome': rentIncome,
        'mortgage': mortgage,
        'propertyTaxes': propertyTaxes,
        'insurance': insurance,
        'hoaFees': hoaFees,
        'propertyMgmt': propertyMgmt,
        'maintenance': maintenance,
        'vacancyLoss': vacancyLoss,
        'utilities': utilities,
        'landscaping': landscaping,
        'otherExpenses': otherExpenses,
        'savedAt': savedAt.toIso8601String(),
        'propertyValue': propertyValue,
        'cashInvested': cashInvested,
      };

  factory ExpenseCalc.fromJson(Map<String, dynamic> j) => ExpenseCalc(
        propertyName: j['propertyName'] as String,
        rentIncome: (j['rentIncome'] as num).toDouble(),
        mortgage: (j['mortgage'] as num).toDouble(),
        propertyTaxes: (j['propertyTaxes'] as num).toDouble(),
        insurance: (j['insurance'] as num).toDouble(),
        hoaFees: (j['hoaFees'] as num).toDouble(),
        propertyMgmt: (j['propertyMgmt'] as num).toDouble(),
        maintenance: (j['maintenance'] as num).toDouble(),
        vacancyLoss: (j['vacancyLoss'] as num).toDouble(),
        utilities: (j['utilities'] as num).toDouble(),
        landscaping: (j['landscaping'] as num).toDouble(),
        otherExpenses: (j['otherExpenses'] as num).toDouble(),
        savedAt: DateTime.parse(j['savedAt'] as String),
        propertyValue: (j['propertyValue'] as num?)?.toDouble() ?? 0,
        cashInvested: (j['cashInvested'] as num?)?.toDouble() ?? 0,
      );
}

// ── History helpers ───────────────────────────────────────────────────────────

const _prefKey = 'expense_history_v1';

Future<List<ExpenseCalc>> loadHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_prefKey) ?? [];
  return raw
      .map((s) {
        try {
          return ExpenseCalc.fromJson(jsonDecode(s) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      })
      .whereType<ExpenseCalc>()
      .toList();
}

Future<void> saveToHistory(ExpenseCalc calc) async {
  final prefs = await SharedPreferences.getInstance();
  final limit = freemiumService.historyLimit;
  final raw = prefs.getStringList(_prefKey) ?? [];
  final list = raw
      .map((s) {
        try {
          return ExpenseCalc.fromJson(jsonDecode(s) as Map<String, dynamic>);
        } catch (_) {
          return null;
        }
      })
      .whereType<ExpenseCalc>()
      .toList();

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

class _CalculatorScreenState extends State<CalculatorScreen>
    with CalcwiseAutoCalcMixin {
  // AmountFormatter replaces NumberFormat _fmt

  // Controllers
  final _nameCtrl = TextEditingController();
  final _rentCtrl = TextEditingController(text: '2000');
  final _mortCtrl = TextEditingController(text: '1200');
  final _taxCtrl = TextEditingController(text: '200');
  final _insCtrl = TextEditingController(text: '150');
  final _hoaCtrl = TextEditingController(text: '0');
  final _mgmtCtrl = TextEditingController(text: '8');
  final _maintCtrl = TextEditingController(text: '100');
  final _vacCtrl = TextEditingController(text: '5');
  final _utilCtrl = TextEditingController();
  final _landCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();

  final _valueCtrl = TextEditingController(text: '250000'); // property value
  final _investCtrl = TextEditingController(text: '50000'); // cash invested

  // Toggles
  bool _mgmtIsPercent = true; // true = % of rent, false = $
  bool _vacIsPercent = true; // vacancy loss % of rent

  // Computed result
  ExpenseCalc? _result;
  bool _saved = false;

  Timer? _saveDebounce;

  // SmartHistory
  String? _currentHash;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('calculator');
    if (widget.preload != null) _populateFrom(widget.preload!);
    for (final c in _allControllers) {
      c.addListener(_clearSaved);
      c.addListener(_debouncedCalculate);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _debouncedCalculate());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPaywall());
  }

  List<TextEditingController> get _allControllers => [
        _nameCtrl,
        _rentCtrl,
        _mortCtrl,
        _taxCtrl,
        _insCtrl,
        _hoaCtrl,
        _mgmtCtrl,
        _maintCtrl,
        _vacCtrl,
        _utilCtrl,
        _landCtrl,
        _otherCtrl,
        _valueCtrl,
        _investCtrl,
      ];

  void _debouncedCalculate() {
    scheduleCalc(() {
      _calculate(isSpanishNotifier.value);
      _saveDebounce?.cancel();
      _saveDebounce = Timer(const Duration(milliseconds: 2000), () {
        if (mounted && _result != null && !_saved) _save(isSpanishNotifier.value);
      });
    });
  }

  void _clearSaved() => setState(() => _saved = false);

  void _populateFrom(ExpenseCalc c) {
    _nameCtrl.text = c.propertyName;
    _rentCtrl.text = c.rentIncome > 0 ? c.rentIncome.toStringAsFixed(2) : '';
    _mortCtrl.text = c.mortgage > 0 ? c.mortgage.toStringAsFixed(2) : '';
    _taxCtrl.text =
        c.propertyTaxes > 0 ? c.propertyTaxes.toStringAsFixed(2) : '';
    _insCtrl.text = c.insurance > 0 ? c.insurance.toStringAsFixed(2) : '';
    _hoaCtrl.text = c.hoaFees > 0 ? c.hoaFees.toStringAsFixed(2) : '';
    _maintCtrl.text = c.maintenance > 0 ? c.maintenance.toStringAsFixed(2) : '';
    _utilCtrl.text = c.utilities > 0 ? c.utilities.toStringAsFixed(2) : '';
    _landCtrl.text = c.landscaping > 0 ? c.landscaping.toStringAsFixed(2) : '';
    _otherCtrl.text =
        c.otherExpenses > 0 ? c.otherExpenses.toStringAsFixed(2) : '';
    // For loaded entries, always show raw $ values for mgmt & vacancy
    _mgmtIsPercent = false;
    _vacIsPercent = false;
    _mgmtCtrl.text =
        c.propertyMgmt > 0 ? c.propertyMgmt.toStringAsFixed(2) : '';
    _vacCtrl.text = c.vacancyLoss > 0 ? c.vacancyLoss.toStringAsFixed(2) : '';
  }

  bool get _canCalculate => _parseD(_rentCtrl) > 0;

  double _parseD(TextEditingController c) {
    final v = c.text;
    if (v.isEmpty) return 0.0;
    final s = (v.contains('.') && v.contains(','))
        ? v.replaceAll(',', '')
        : v.replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  // ── SmartHistory helpers ────────────────────────────────────────────────────

  double _roundTo(double v, double step) => (v / step).round() * step;

  Map<String, dynamic> _buildL1(ExpenseCalc c) => {
        'property_value': c.propertyValue,
        'monthly_rent': c.rentIncome,
        'monthly_cashflow': c.monthlyCashFlow,
        'cap_rate': c.capRate ?? 0.0,
        'coc_return': c.cocRoi ?? 0.0,
      };

  Map<String, dynamic> _buildL2(ExpenseCalc c) => {
        'inputs': {
          'property_name': c.propertyName,
          'property_value': c.propertyValue,
          'cash_invested': c.cashInvested,
          'monthly_rent': c.rentIncome,
          'mortgage': c.mortgage,
          'property_taxes': c.propertyTaxes,
          'insurance': c.insurance,
          'hoa_fees': c.hoaFees,
          'property_mgmt': c.propertyMgmt,
          'maintenance': c.maintenance,
          'vacancy_loss': c.vacancyLoss,
          'utilities': c.utilities,
          'landscaping': c.landscaping,
          'other_expenses': c.otherExpenses,
        },
        'results': {
          'total_expenses': c.totalExpenses,
          'monthly_cashflow': c.monthlyCashFlow,
          'annual_cashflow': c.annualCashFlow,
          'noi': c.noi,
          'cap_rate': c.capRate ?? 0.0,
          'gross_yield': c.grossYield ?? 0.0,
          'coc_return': c.cocRoi ?? 0.0,
        },
      };

  void _scheduleAutoSave(ExpenseCalc c) {
    final hash = ResultHasher.hashInputs({
      'rent': _roundTo(c.rentIncome, 100),
      'expenses': _roundTo(c.totalExpenses, 100),
      'prop_value': _roundTo(c.propertyValue, 5000),
      'cash_invested': _roundTo(c.cashInvested, 5000),
    });
    _currentHash = hash;
    smartHistoryService.scheduleAutoSave(
      appKey: 'rentalexpenses',
      screenId: 'expenses',
      inputHash: hash,
      l1: _buildL1(c),
      l2: _buildL2(c),
      onSaved: () {
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _saveScenario(String? label) async {
    final c = _result;
    final hash = _currentHash;
    if (c == null || hash == null) return;
    await smartHistoryService.saveScenario(
      appKey: 'rentalexpenses',
      screenId: 'expenses',
      inputHash: hash,
      l1: _buildL1(c),
      l2: _buildL2(c),
      label: label,
    );
    historyRefreshNotifier.value++;
    adService.onSave();
    paywallSession.recordAction().ignore();
  }

  Future<void> _calculate(bool isSpanish) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final rent = _parseD(_rentCtrl);
    final mortgage = _parseD(_mortCtrl);
    final taxes = _parseD(_taxCtrl);
    final ins = _parseD(_insCtrl);
    final hoa = _parseD(_hoaCtrl);
    final maintenance = _parseD(_maintCtrl);
    final utilities = _parseD(_utilCtrl);
    final landscaping = _parseD(_landCtrl);
    final other = _parseD(_otherCtrl);

    final mgmtRaw = _parseD(_mgmtCtrl);
    final mgmtDollar = _mgmtIsPercent ? (rent * mgmtRaw / 100) : mgmtRaw;

    final vacRaw = _parseD(_vacCtrl);
    final vacDollar = _vacIsPercent ? (rent * vacRaw / 100) : vacRaw;

    final calc = ExpenseCalc(
      propertyName: _nameCtrl.text.trim().isEmpty
          ? s.myProperty
          : _nameCtrl.text.trim(),
      rentIncome: rent,
      mortgage: mortgage,
      propertyTaxes: taxes,
      insurance: ins,
      hoaFees: hoa,
      propertyMgmt: mgmtDollar,
      maintenance: maintenance,
      vacancyLoss: vacDollar,
      utilities: utilities,
      landscaping: landscaping,
      otherExpenses: other,
      savedAt: DateTime.now(),
      propertyValue: _parseD(_valueCtrl),
      cashInvested: _parseD(_investCtrl),
    );

    setState(() {
      _result = calc;
      _saved = false;
    });

    _scheduleAutoSave(calc);
    unawaited(AnalyticsService.instance.logCalculate());
    unawaited(AnalyticsService.instance.maybeLogFirstCalculate());
    adService.onAction();
  }

  Future<void> _checkPaywall() async {
    final trigger = await paywallSession.recordAction();
    if (!mounted) return;
    if (trigger != PaywallTrigger.none) PaywallHard.show(context);
  }

  Future<void> _save(bool isSpanish) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    if (_result == null) return;
    final isPremium = freemiumService.hasFullAccess;
    final history = await loadHistory();
    if (!isPremium &&
        history.length >= MonetizationConfig.freeCalculationLimit) {
      if (mounted) {
        await PaywallSoft.show(
          context,
          isSpanish: isSpanish,
          featureTitle: s.unlimitedHistory,
          featureSubtitle: s.unlimitedHistorySubtitle,
        );
      }
      return;
    }
    HapticFeedback.mediumImpact();
    await saveToHistory(_result!);
    adService.onSave();
    if (mounted) setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(s.savedToHistory),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _share(bool isSpanish) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    if (_result == null) return;
    HapticFeedback.lightImpact();
    final c = _result!;
    final cf = c.monthlyCashFlow;
    final lines = <String>[
      s.shareTitle(c.propertyName),
      '',
      s.shareMonthlyRent(AmountFormatter.ui(c.rentIncome, 'USD')),
      s.shareTotalExpenses(AmountFormatter.ui(c.totalExpenses, 'USD')),
      s.shareMonthlyCashFlow(cf < 0 ? '-' : '+', AmountFormatter.ui(cf.abs(), 'USD')),
      s.shareAnnualCashFlow(c.annualCashFlow < 0 ? '-' : '+', AmountFormatter.ui(c.annualCashFlow.abs(), 'USD')),
      s.shareAnnualNOI(AmountFormatter.ui(c.noi, 'USD')),
      if (c.capRate != null)
        '• Cap Rate: ${c.capRate!.toStringAsFixed(2)}%',
      if (c.cocRoi != null)
        isSpanish
            ? '• ROI (Cash-on-Cash): ${c.cocRoi!.toStringAsFixed(2)}%'
            : '• Cash-on-Cash ROI: ${c.cocRoi!.toStringAsFixed(2)}%',
      '',
      s.shareCalculatedWith,
      '',
      s.shareExportPdfCTA,
    ];
    try {
      await Share.share(lines.join('\n'));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.sharedSuccessfully),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.shareFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _exportPdf(bool isSpanish) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final c = _result;
    if (c == null) return;
    HapticFeedback.mediumImpact();

    Future<void> doExport() => PdfExportService.exportReport(
          context: context,
          propertyName: c.propertyName,
          monthlyRent: c.rentIncome,
          annualRent: c.rentIncome * 12,
          expenses: [
            if (c.mortgage > 0)
              {'name': s.mortgage, 'monthly': c.mortgage},
            if (c.propertyTaxes > 0)
              {'name': s.propertyTaxesLabel, 'monthly': c.propertyTaxes},
            if (c.insurance > 0)
              {'name': s.insurance, 'monthly': c.insurance},
            if (c.hoaFees > 0)
              {'name': s.hoaFees, 'monthly': c.hoaFees},
            if (c.propertyMgmt > 0)
              {'name': s.administration, 'monthly': c.propertyMgmt},
            if (c.maintenance > 0)
              {'name': s.maintenance, 'monthly': c.maintenance},
            if (c.vacancyLoss > 0)
              {'name': s.vacancy, 'monthly': c.vacancyLoss},
            if (c.utilities > 0)
              {'name': s.utilities, 'monthly': c.utilities},
            if (c.landscaping > 0)
              {'name': s.landscapingLabel, 'monthly': c.landscaping},
            if (c.otherExpenses > 0)
              {'name': s.other, 'monthly': c.otherExpenses},
          ],
          totalMonthlyExpenses: c.totalExpenses,
          netMonthlyIncome: c.monthlyCashFlow,
          netAnnualIncome: c.annualCashFlow,
          expenseRatio: c.expenseRatio / 100,
          noi: c.noi,
          capRate: c.capRate,
          cashOnCashRoi: c.cocRoi,
          isSpanish: isSpanish,
        );

    if (freemiumService.hasFullAccess) {
      await doExport();
      await AnalyticsService.instance.logPdfExported();
    } else {
      await PdfExportService.showUnlockOrPay(context, doExport);
    }
  }

  void _reset() {
    for (final c in _allControllers) c.clear();
    setState(() {
      _result = null;
      _saved = false;
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    smartHistoryService.cancelPendingSave('rentalexpenses', 'expenses');
    for (final c in _allControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        return Scaffold(
          appBar: AppBar(
            title: Text(s.appTitle),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: s.reset,
                onPressed: _reset,
              ),
            ],
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Results ─────────────────────────────────────────
                            AnimatedSwitcher(
                              duration: AppDuration.base,
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(
                                opacity: anim,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.04),
                                    end: Offset.zero,
                                  ).animate(CurvedAnimation(
                                      parent: anim, curve: Curves.easeOut)),
                                  child: child,
                                ),
                              ),
                              child: _result != null
                                  ? KeyedSubtree(
                                      key: const ValueKey('results'),
                                      child: CalcwisePageEntrance(
                                        child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _ResultsSection(
                                            calc: _result!,
                                            isSpanish: isSpanish,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          InsightCard(
                                            insights: InsightEngine.generate(
                                              monthlyRent: _result!.rentIncome,
                                              totalMonthlyExpenses:
                                                  _result!.totalExpenses,
                                              monthlyCashFlow:
                                                  _result!.monthlyCashFlow,
                                              expenseRatioPct:
                                                  _result!.expenseRatio,
                                              vacancyLoss: _result!.vacancyLoss,
                                              capRate: _result!.capRate,
                                              isSpanish: isSpanish,
                                            ),
                                            isSpanish: isSpanish,
                                          ),
                                          const SizedBox(height: AppSpacing.lg),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: SaveScenarioButton(
                                                    onSave: _saveScenario),
                                              ),
                                              const SizedBox(
                                                  width: AppSpacing.sm),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _exportPdf(isSpanish),
                                                icon: const Icon(
                                                    Icons.picture_as_pdf_rounded),
                                                label: Text(isSpanish
                                                    ? 'PDF'
                                                    : 'PDF'),
                                                style: OutlinedButton.styleFrom(
                                                    minimumSize:
                                                        const Size(0, 44)),
                                              ),
                                              const SizedBox(
                                                  width: AppSpacing.sm),
                                              OutlinedButton.icon(
                                                onPressed: () =>
                                                    _share(isSpanish),
                                                icon: const Icon(
                                                    Icons.share_rounded),
                                                label: Text(isSpanish
                                                    ? 'Compartir'
                                                    : 'Share'),
                                                style: OutlinedButton.styleFrom(
                                                    minimumSize:
                                                        const Size(0, 44)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(
                                              height: AppSpacing.xxl),
                                        ],
                                      ),
                                      ),
                                    )
                                  : const SizedBox.shrink(
                                      key: ValueKey('empty')),
                            ),
                            const SizedBox(height: AppSpacing.xxl),

                            // ── Property Setup ──────────────────────────────────
                            _SectionLabel(s.propertySetup),
                            _buildCard([
                              _TextField(
                                ctrl: _nameCtrl,
                                label: s.propertyNameLabel,
                                hint: s.propertyNameHint,
                                isNumeric: false,
                                prefix: null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _rentCtrl,
                                label: s.monthlyRentIncome,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return s.required;
                                  }
                                  final n =
                                      double.tryParse(v.replaceAll(',', '')) ??
                                          0;
                                  if (n <= 0) return s.mustBePositive;
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Divider(
                                  height: 1,
                                  color: CalcwiseTheme.of(context).cardBorder),
                              const SizedBox(height: AppSpacing.md),
                              // ── Investor Metrics inputs (optional) ──────────
                              Row(children: [
                                const Icon(Icons.analytics_rounded,
                                    size: 14, color: AppTheme.primary),
                                const SizedBox(width: 6),
                                Text(
                                  s.investmentMetricsOptional,
                                  style: const TextStyle(
                                      fontSize: AppTextSize.sm,
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.w600),
                                ),
                              ]),
                              const SizedBox(height: AppSpacing.sm),
                              _TextField(
                                ctrl: _valueCtrl,
                                label: s.propertyValue,
                                hint: s.propertyValueHint,
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _investCtrl,
                                label: s.cashInvested,
                                hint: s.cashInvestedHint,
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                            ]),
                            const SizedBox(height: AppSpacing.xxl),

                            // ── Expense Categories ──────────────────────────────
                            _SectionLabel(s.monthlyExpenses),
                            _buildCard([
                              _TextField(
                                ctrl: _mortCtrl,
                                label: s.mortgagePayment,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _taxCtrl,
                                label: s.propertyTaxes,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _insCtrl,
                                label: s.homeownersInsurance,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _hoaCtrl,
                                label: s.hoaFees,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                            ]),
                            const SizedBox(height: AppSpacing.md),

                            // Property Mgmt toggle card
                            _buildCard([
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.propertyManagement,
                                      style: TextStyle(
                                          fontSize: AppTextSize.md,
                                          color: CalcwiseTheme.of(context)
                                              .textSecondary),
                                    ),
                                  ),
                                  _ToggleChip(
                                    labelA: '%',
                                    labelB: '\$',
                                    isA: _mgmtIsPercent,
                                    onChanged: (v) {
                                      setState(() => _mgmtIsPercent = v);
                                      _debouncedCalculate();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _TextField(
                                ctrl: _mgmtCtrl,
                                label: _mgmtIsPercent
                                    ? s.percentOfRent
                                    : s.monthlyAmount,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: !_mgmtIsPercent,
                                prefix: _mgmtIsPercent ? null : '\$',
                                suffix: _mgmtIsPercent ? '%' : null,
                              ),
                            ]),
                            const SizedBox(height: AppSpacing.md),

                            _buildCard([
                              _TextField(
                                ctrl: _maintCtrl,
                                label: s.maintenanceRepairs,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              // Vacancy toggle
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.vacancyLoss,
                                      style: TextStyle(
                                          fontSize: AppTextSize.md,
                                          color: CalcwiseTheme.of(context)
                                              .textSecondary),
                                    ),
                                  ),
                                  _ToggleChip(
                                    labelA: '%',
                                    labelB: '\$',
                                    isA: _vacIsPercent,
                                    onChanged: (v) {
                                      setState(() => _vacIsPercent = v);
                                      _debouncedCalculate();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _TextField(
                                ctrl: _vacCtrl,
                                label: _vacIsPercent
                                    ? s.percentOfRent
                                    : s.monthlyLoss,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: !_vacIsPercent,
                                prefix: _vacIsPercent ? null : '\$',
                                suffix: _vacIsPercent ? '%' : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _utilCtrl,
                                label: s.utilities,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _landCtrl,
                                label: s.landscaping,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TextField(
                                ctrl: _otherCtrl,
                                label: s.otherExpenses,
                                hint: '0.00',
                                isNumeric: true,
                                isCurrency: true,
                                prefix: '\$',
                              ),
                            ]),
                          ],
                        )),
                      ),
                    ),
                  ),
                const CalcwiseAdFooter(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(List<Widget> children) => Card(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
  final bool isSpanish;

  const _ResultsSection({
    required this.calc,
    required this.isSpanish,
  });

  @override
  Widget build(BuildContext context) {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final cf = calc.monthlyCashFlow;
    final cfColor = cf >= 0 ? AppTheme.success : AppTheme.dangerRed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(s.results),

        // Hero KPI — monthly cash flow
        Semantics(
          label: isSpanish
              ? 'Flujo de caja mensual: ${cf < 0 ? 'menos' : ''} ${AmountFormatter.formatNumber(cf.abs())} dólares'
              : 'Monthly cash flow: ${cf < 0 ? 'negative' : ''} ${AmountFormatter.ui(cf.abs(), 'USD')}',
          child: CalcwiseHeroCard(
            label: s.monthlyCashFlow,
            value: '${cf < 0 ? '-' : ''}${AmountFormatter.ui(cf.abs(), 'USD')}',
            secondary: s.rentMinusTotalExpenses,
            rawValue: cf,
            valueFormatter: (v) => '${v < 0 ? '-' : ''}${AmountFormatter.ui(v.abs(), 'USD')}',
            rawStats: [
              (
                label: s.annualCF,
                value: calc.annualCashFlow,
                formatter: (v) => '${v < 0 ? '-' : ''}${AmountFormatter.ui(v.abs(), 'USD')}',
              ),
              (
                label: s.annualNOI,
                value: calc.noi,
                formatter: (v) => AmountFormatter.ui(v, 'USD'),
              ),
            ],
            stats: [
              (
                label: s.annualCF,
                value:
                    '${calc.annualCashFlow < 0 ? '-' : ''}${AmountFormatter.ui(calc.annualCashFlow.abs(), 'USD')}',
              ),
              (
                label: s.annualNOI,
                value: AmountFormatter.ui(calc.noi, 'USD'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Details card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _ResultRow(
                  label: s.totalMonthlyExpenses,
                  value: AmountFormatter.ui(calc.totalExpenses, 'USD'),
                  bold: true,
                ),
                Divider(
                    height: 24, color: CalcwiseTheme.of(context).cardBorder),
                const SizedBox(height: AppSpacing.sm),
                _ResultRow(
                  label: s.expenseRatio,
                  value: '${calc.expenseRatio.toStringAsFixed(1)}%',
                ),
                const SizedBox(height: AppSpacing.sm),
                _ResultRow(
                  label: s.breakEvenRent,
                  value: AmountFormatter.ui(calc.breakEvenRent, 'USD'),
                ),
                const SizedBox(height: AppSpacing.sm),
                _ResultRow(
                  label: s.netOperatingIncomeAnnual,
                  value: AmountFormatter.ui(calc.noi, 'USD'),
                  valueColor:
                      calc.noi >= 0 ? AppTheme.success : AppTheme.dangerRed,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Investor Metrics card (Cap Rate, Yield, CoC ROI) ─────────
        if (calc.capRate != null || calc.cocRoi != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(s.investmentMetrics),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(children: [
                if (calc.capRate != null) ...[
                  _InvestorMetricRow(
                    label: 'Cap Rate',
                    value: '${calc.capRate!.toStringAsFixed(2)}%',
                    hint: s.annualNOIDivPropertyValue,
                    color: calc.capRate! >= 6
                        ? AppTheme.success
                        : calc.capRate! >= 4
                            ? AppTheme.warning
                            : AppTheme.dangerRed,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (calc.grossYield != null) ...[
                  _InvestorMetricRow(
                    label: s.grossYield,
                    value: '${calc.grossYield!.toStringAsFixed(2)}%',
                    hint: s.annualRentDivPropertyValue,
                    color: calc.grossYield! >= 8
                        ? AppTheme.success
                        : AppTheme.warning,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (calc.cocRoi != null) ...[
                  _InvestorMetricRow(
                    label: 'Cash-on-Cash ROI',
                    value: '${calc.cocRoi!.toStringAsFixed(2)}%',
                    hint: s.annualCashFlowDivCashInvested,
                    color: calc.cocRoi! >= 8
                        ? AppTheme.success
                        : calc.cocRoi! >= 4
                            ? AppTheme.warning
                            : AppTheme.dangerRed,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Divider(
                    height: 12, color: CalcwiseTheme.of(context).cardBorder),
                Text(
                  s.capRateGoodCoCROIExcellent,
                  style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: CalcwiseTheme.of(context).textSecondary),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        // Cash flow indicator banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.mdPlus, horizontal: AppSpacing.lg),
          decoration: BoxDecoration(
            color: cfColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.xl),
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
              const SizedBox(width: AppSpacing.sm),
              Text(
                cf >= 0 ? s.positiveCashFlow : s.negativeCashFlow,
                style: TextStyle(
                    color: cfColor,
                    fontWeight: FontWeight.w600,
                    fontSize: AppTextSize.md),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Expense breakdown
        _SectionLabel(s.expenseBreakdown),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: _BreakdownList(calc: calc, isSpanish: isSpanish),
          ),
        ),
      ],
    );
  }
}

class _BreakdownList extends StatelessWidget {
  final ExpenseCalc calc;
  final bool isSpanish;

  const _BreakdownList({
    required this.calc,
    required this.isSpanish,
  });

  static const List<Color> _palette = AppTheme.categoryPalette;

  @override
  Widget build(BuildContext context) {
    final entries = (isSpanish ? calc.breakdownES : calc.breakdown)
        .entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = calc.totalExpenses;

    if (entries.isEmpty) {
      final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
      return Text(
        s.noExpensesEntered,
        style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          _BreakdownRow(
            label: entries[i].key,
            amount: entries[i].value,
            pct: total > 0 ? entries[i].value / total * 100 : 0,
            color: _palette[i % _palette.length],
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

  const _BreakdownRow({
    required this.label,
    required this.amount,
    required this.pct,
    required this.color,
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
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child:
                  Text(label, style: const TextStyle(fontSize: AppTextSize.md)),
            ),
            Text(
              AmountFormatter.ui(amount, 'USD'),
              style: const TextStyle(
                  fontSize: AppTextSize.md, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              child: Text(
                '${pct.toStringAsFixed(1)}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                    fontSize: AppTextSize.sm,
                    color: CalcwiseTheme.of(context).textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xs),
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
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: AppTextSize.sm,
              fontWeight: FontWeight.bold,
              color: CalcwiseTheme.of(context).textSecondary,
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
  final bool isCurrency;
  final String? Function(String?)? validator;

  const _TextField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.isNumeric,
    this.prefix,
    this.suffix,
    this.isCurrency = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isCurrency
          ? [CurrencyInputFormatter(locale: 'en_US')]
          : (isNumeric
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
              : null),
      autovalidateMode: validator != null
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefix,
        suffixText: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
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
        ButtonSegment(value: true, label: Text(labelA)),
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
          if (states.contains(WidgetState.selected))
            return Theme.of(context).colorScheme.onPrimary;
          return null;
        }),
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

// ── Investor metric row ───────────────────────────────────────────────────────

class _InvestorMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _InvestorMetricRow({
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: AppTextSize.body)),
              Text(hint,
                  style: TextStyle(
                      fontSize: AppTextSize.xs,
                      color: CalcwiseTheme.of(context).textSecondary)),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: AppTextSize.subtitle,
              fontWeight: FontWeight.bold,
              color: color),
        ),
      ],
    );
  }
}
