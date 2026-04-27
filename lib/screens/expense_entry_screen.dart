import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/paywall_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../models/expense_model.dart';
import '../models/property_model.dart';
import '../services/property_database_service.dart';
import '../widgets/banner_ad_widget.dart';

class ExpenseEntryScreen extends StatefulWidget {
  final Property property;
  final MonthlyExpense? existing;
  final DateTime targetMonth;

  const ExpenseEntryScreen({
    super.key,
    required this.property,
    this.existing,
    required this.targetMonth,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  late DateTime _selectedMonth;

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

  bool _mgmtIsPercent = false;
  bool _vacIsPercent  = false;
  bool _isSaving = false;

  // Live results
  double _totalExpenses = 0;
  double _monthlyCF    = 0;
  double _expenseRatio = 0;
  double _breakEven    = 0;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(widget.targetMonth.year, widget.targetMonth.month);
    final e = widget.existing;
    if (e != null) {
      _mortCtrl.text  = e.mortgage      > 0 ? e.mortgage.toStringAsFixed(2) : '';
      _taxCtrl.text   = e.propertyTaxes > 0 ? e.propertyTaxes.toStringAsFixed(2) : '';
      _insCtrl.text   = e.insurance     > 0 ? e.insurance.toStringAsFixed(2) : '';
      _hoaCtrl.text   = e.hoaFees       > 0 ? e.hoaFees.toStringAsFixed(2) : '';
      _mgmtCtrl.text  = e.propertyMgmt  > 0 ? e.propertyMgmt.toStringAsFixed(2) : '';
      _maintCtrl.text = e.maintenance   > 0 ? e.maintenance.toStringAsFixed(2) : '';
      _vacCtrl.text   = e.vacancyLoss   > 0 ? e.vacancyLoss.toStringAsFixed(2) : '';
      _utilCtrl.text  = e.utilities     > 0 ? e.utilities.toStringAsFixed(2) : '';
      _landCtrl.text  = e.landscaping   > 0 ? e.landscaping.toStringAsFixed(2) : '';
      _otherCtrl.text = e.otherExpenses > 0 ? e.otherExpenses.toStringAsFixed(2) : '';
    }
    for (final c in _allControllers) {
      c.addListener(_recalculate);
    }
    _recalculate();
  }

  List<TextEditingController> get _allControllers => [
    _mortCtrl, _taxCtrl, _insCtrl, _hoaCtrl, _mgmtCtrl,
    _maintCtrl, _vacCtrl, _utilCtrl, _landCtrl, _otherCtrl,
  ];

  double _parseD(TextEditingController c) {
    final v = c.text;
    if (v.isEmpty) return 0.0;
    final s = (v.contains('.') && v.contains(','))
        ? v.replaceAll(',', '')
        : v.replaceAll(',', '.');
    return double.tryParse(s) ?? 0.0;
  }

  void _recalculate() {
    final rent = widget.property.monthlyRent;
    final mort = _parseD(_mortCtrl);
    final tax  = _parseD(_taxCtrl);
    final ins  = _parseD(_insCtrl);
    final hoa  = _parseD(_hoaCtrl);
    final mgmtRaw = _parseD(_mgmtCtrl);
    final mgmt = _mgmtIsPercent ? (rent * mgmtRaw / 100) : mgmtRaw;
    final maint = _parseD(_maintCtrl);
    final vacRaw = _parseD(_vacCtrl);
    final vac = _vacIsPercent ? (rent * vacRaw / 100) : vacRaw;
    final util  = _parseD(_utilCtrl);
    final land  = _parseD(_landCtrl);
    final other = _parseD(_otherCtrl);

    final total = mort + tax + ins + hoa + mgmt + maint + vac + util + land + other;
    setState(() {
      _totalExpenses = total;
      _monthlyCF    = rent - total;
      _expenseRatio = rent > 0 ? (total / rent * 100) : 0;
      _breakEven    = total;
    });
  }

  Future<void> _pickMonth(bool isSpanish) async {
    // Show a year/month picker via a dialog
    int pickedYear  = _selectedMonth.year;
    int pickedMonth = _selectedMonth.month;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _MonthPickerDialog(
        initialYear: pickedYear,
        initialMonth: pickedMonth,
        isSpanish: isSpanish,
        onConfirm: (y, m) {
          setState(() => _selectedMonth = DateTime(y, m));
        },
      ),
    );
  }

  Future<void> _save(bool isSpanish) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final rent = widget.property.monthlyRent;
      final mgmtRaw = _parseD(_mgmtCtrl);
      final mgmt = _mgmtIsPercent ? (rent * mgmtRaw / 100) : mgmtRaw;
      final vacRaw = _parseD(_vacCtrl);
      final vac = _vacIsPercent ? (rent * vacRaw / 100) : vacRaw;

      final existing = widget.existing;
      final id = existing?.id ??
          '${widget.property.id}_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}';

      final expense = MonthlyExpense(
        id: id,
        propertyId: widget.property.id,
        year: _selectedMonth.year,
        month: _selectedMonth.month,
        mortgage: _parseD(_mortCtrl),
        propertyTaxes: _parseD(_taxCtrl),
        insurance: _parseD(_insCtrl),
        hoaFees: _parseD(_hoaCtrl),
        propertyMgmt: mgmt,
        maintenance: _parseD(_maintCtrl),
        vacancyLoss: vac,
        utilities: _parseD(_utilCtrl),
        landscaping: _parseD(_landCtrl),
        otherExpenses: _parseD(_otherCtrl),
      );

      if (existing != null) {
        await PropertyDatabaseService.instance.updateExpense(expense);
      } else {
        await PropertyDatabaseService.instance.insertExpense(expense);
      }

      paywallService.recordAction();
      await AnalyticsService.instance.logExpenseTracked('monthly_expenses');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isSpanish ? 'Gastos guardados' : 'Expenses saved'),
          duration: const Duration(seconds: 2),
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isSpanish ? 'Error al guardar' : 'Error saving: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        final monthLabel = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en').format(_selectedMonth);
        final cfColor = _monthlyCF >= 0 ? AppTheme.success : Colors.red;

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.existing != null
                ? (isSpanish ? 'Editar Gastos' : 'Edit Expenses')
                : (isSpanish ? 'Agregar Gastos' : 'Add Expenses')),
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Property name banner
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_rounded, color: AppTheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.property.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Month picker
                    _SectionLabel(isSpanish ? 'PERÍODO' : 'PERIOD'),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.calendar_month_rounded, color: AppTheme.primary),
                        title: Text(
                          monthLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.labelGray),
                        onTap: () => _pickMonth(isSpanish),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Expense fields
                    _SectionLabel(isSpanish ? 'GASTOS MENSUALES' : 'MONTHLY EXPENSES'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _NumField(ctrl: _mortCtrl,  label: isSpanish ? 'Hipoteca' : 'Mortgage'),
                            const SizedBox(height: 12),
                            _NumField(ctrl: _taxCtrl,   label: isSpanish ? 'Impuestos de propiedad' : 'Property Taxes'),
                            const SizedBox(height: 12),
                            _NumField(ctrl: _insCtrl,   label: isSpanish ? 'Seguro' : 'Insurance'),
                            const SizedBox(height: 12),
                            _NumField(ctrl: _hoaCtrl,   label: isSpanish ? 'Cuotas HOA' : 'HOA Fees'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Property management toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isSpanish ? 'Adm. de propiedad' : 'Property Management',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.labelGray),
                                  ),
                                ),
                                _ToggleChip(
                                  labelA: '%',
                                  labelB: '\$',
                                  isA: _mgmtIsPercent,
                                  onChanged: (v) => setState(() {
                                    _mgmtIsPercent = v;
                                    _recalculate();
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _NumField(
                              ctrl: _mgmtCtrl,
                              label: _mgmtIsPercent
                                  ? (isSpanish ? '% del alquiler' : '% of rent')
                                  : (isSpanish ? 'Cantidad mensual' : 'Monthly amount'),
                              prefix: _mgmtIsPercent ? null : '\$',
                              suffix: _mgmtIsPercent ? '%' : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NumField(ctrl: _maintCtrl, label: isSpanish ? 'Mantenimiento / Reparaciones' : 'Maintenance / Repairs'),
                            const SizedBox(height: 12),

                            // Vacancy toggle
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isSpanish ? 'Pérdida por vacante' : 'Vacancy Loss',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.labelGray),
                                  ),
                                ),
                                _ToggleChip(
                                  labelA: '%',
                                  labelB: '\$',
                                  isA: _vacIsPercent,
                                  onChanged: (v) => setState(() {
                                    _vacIsPercent = v;
                                    _recalculate();
                                  }),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _NumField(
                              ctrl: _vacCtrl,
                              label: _vacIsPercent
                                  ? (isSpanish ? '% del alquiler' : '% of rent')
                                  : (isSpanish ? 'Pérdida mensual' : 'Monthly loss'),
                              prefix: _vacIsPercent ? null : '\$',
                              suffix: _vacIsPercent ? '%' : null,
                            ),
                            const SizedBox(height: 12),
                            _NumField(ctrl: _utilCtrl,  label: isSpanish ? 'Servicios públicos' : 'Utilities'),
                            const SizedBox(height: 12),
                            _NumField(ctrl: _landCtrl,  label: isSpanish ? 'Jardinería' : 'Landscaping'),
                            const SizedBox(height: 12),
                            _NumField(ctrl: _otherCtrl, label: isSpanish ? 'Otros gastos' : 'Other Expenses'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Live results
                    _SectionLabel(isSpanish ? 'RESULTADOS EN VIVO' : 'LIVE RESULTS'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _ResultRow(
                              label: isSpanish ? 'Total gastos' : 'Total Expenses',
                              value: '\$${_fmt.format(_totalExpenses)}',
                              bold: true,
                            ),
                            const Divider(height: 20, color: AppTheme.divider),
                            _ResultRow(
                              label: isSpanish ? 'Flujo de caja mensual' : 'Monthly Cash Flow',
                              value: '${_monthlyCF < 0 ? '-' : ''}\$${_fmt.format(_monthlyCF.abs())}',
                              valueColor: cfColor,
                              bold: true,
                            ),
                            const SizedBox(height: 8),
                            _ResultRow(
                              label: isSpanish ? 'Ratio de gastos' : 'Expense Ratio',
                              value: '${_expenseRatio.toStringAsFixed(1)}%',
                            ),
                            const SizedBox(height: 8),
                            _ResultRow(
                              label: isSpanish ? 'Alquiler mínimo' : 'Break-Even Rent',
                              value: '\$${_fmt.format(_breakEven)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : () => _save(isSpanish),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(isSpanish ? 'Guardar Gastos' : 'Save Expenses'),
                    ),
                    const SizedBox(height: 24),
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
}

// ── Month Picker Dialog ───────────────────────────────────────────────────────

class _MonthPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final bool isSpanish;
  final void Function(int year, int month) onConfirm;

  const _MonthPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.isSpanish,
    required this.onConfirm,
  });

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year  = widget.initialYear;
    _month = widget.initialMonth;
  }

  static const List<String> _monthsEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static const List<String> _monthsEs = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  Widget build(BuildContext context) {
    final months = widget.isSpanish ? _monthsEs : _monthsEn;
    return AlertDialog(
      title: Text(widget.isSpanish ? 'Seleccionar Mes' : 'Select Month'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() => _year--),
              ),
              Text('$_year', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() => _year++),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(12, (i) {
              final selected = (i + 1) == _month;
              return GestureDetector(
                onTap: () => setState(() => _month = i + 1),
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : AppTheme.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? AppTheme.primary : AppTheme.divider,
                    ),
                  ),
                  child: Text(
                    months[i].substring(0, 3),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isSpanish ? 'Cancelar' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onConfirm(_year, _month);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
          child: Text(widget.isSpanish ? 'OK' : 'OK'),
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
          label,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.labelGray,
              letterSpacing: 0.8),
        ),
      );
}

class _NumField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? prefix;
  final String? suffix;

  const _NumField({
    required this.ctrl,
    required this.label,
    this.prefix,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        hintText: '0.00',
        prefixText: prefix ?? '\$',
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
