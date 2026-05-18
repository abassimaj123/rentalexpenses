import 'dart:io';
import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path_pkg;
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../main.dart';
import '../models/expense_model.dart';
import '../models/property_model.dart';
import '../screens/receipt_viewer_screen.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';

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

  final _mortCtrl = TextEditingController();
  final _taxCtrl = TextEditingController();
  final _insCtrl = TextEditingController();
  final _hoaCtrl = TextEditingController();
  final _mgmtCtrl = TextEditingController();
  final _maintCtrl = TextEditingController();
  final _vacCtrl = TextEditingController();
  final _utilCtrl = TextEditingController();
  final _landCtrl = TextEditingController();
  final _otherCtrl = TextEditingController();

  bool _mgmtIsPercent = false;
  bool _vacIsPercent = false;
  bool _isSaving = false;

  // Feature 2 — recurring
  bool _isRecurring = false;
  String _recurrenceType = 'monthly'; // 'monthly' | 'annual'

  // Feature 3 — receipt photo
  String? _receiptPath; // persisted file path (null = no photo)

  // Live results
  double _totalExpenses = 0;
  double _monthlyCF = 0;
  double _expenseRatio = 0;
  double _breakEven = 0;

  @override
  void initState() {
    super.initState();
    _selectedMonth =
        DateTime(widget.targetMonth.year, widget.targetMonth.month);
    final e = widget.existing;
    if (e != null) {
      _mortCtrl.text = e.mortgage > 0 ? e.mortgage.toStringAsFixed(2) : '';
      _taxCtrl.text =
          e.propertyTaxes > 0 ? e.propertyTaxes.toStringAsFixed(2) : '';
      _insCtrl.text = e.insurance > 0 ? e.insurance.toStringAsFixed(2) : '';
      _hoaCtrl.text = e.hoaFees > 0 ? e.hoaFees.toStringAsFixed(2) : '';
      _mgmtCtrl.text =
          e.propertyMgmt > 0 ? e.propertyMgmt.toStringAsFixed(2) : '';
      _maintCtrl.text =
          e.maintenance > 0 ? e.maintenance.toStringAsFixed(2) : '';
      _vacCtrl.text = e.vacancyLoss > 0 ? e.vacancyLoss.toStringAsFixed(2) : '';
      _utilCtrl.text = e.utilities > 0 ? e.utilities.toStringAsFixed(2) : '';
      _landCtrl.text =
          e.landscaping > 0 ? e.landscaping.toStringAsFixed(2) : '';
      _otherCtrl.text =
          e.otherExpenses > 0 ? e.otherExpenses.toStringAsFixed(2) : '';
      _isRecurring = e.isRecurring;
      _recurrenceType = e.recurrenceType ?? 'monthly';
      _receiptPath = e.receiptPath;
    }
    for (final c in _allControllers) {
      c.addListener(_recalculate);
    }
    _recalculate();
  }

  List<TextEditingController> get _allControllers => [
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
    final tax = _parseD(_taxCtrl);
    final ins = _parseD(_insCtrl);
    final hoa = _parseD(_hoaCtrl);
    final mgmtRaw = _parseD(_mgmtCtrl);
    final mgmt = _mgmtIsPercent ? (rent * mgmtRaw / 100) : mgmtRaw;
    final maint = _parseD(_maintCtrl);
    final vacRaw = _parseD(_vacCtrl);
    final vac = _vacIsPercent ? (rent * vacRaw / 100) : vacRaw;
    final util = _parseD(_utilCtrl);
    final land = _parseD(_landCtrl);
    final other = _parseD(_otherCtrl);

    final total =
        mort + tax + ins + hoa + mgmt + maint + vac + util + land + other;
    setState(() {
      _totalExpenses = total;
      _monthlyCF = rent - total;
      _expenseRatio = rent > 0 ? (total / rent * 100) : 0;
      _breakEven = total;
    });
  }

  Future<void> _pickMonth(bool isSpanish) async {
    // Show a year/month picker via a dialog
    int pickedYear = _selectedMonth.year;
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

  Future<void> _pickReceipt(bool isSpanish) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primary),
                title: Text(isSpanish ? 'Tomar foto' : 'Take photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppTheme.primary),
                title: Text(
                    isSpanish ? 'Elegir de galería' : 'Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    // Copy file to app documents directory so it persists independently
    final docsDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(path_pkg.join(docsDir.path, 'receipts'));
    if (!receiptsDir.existsSync()) receiptsDir.createSync(recursive: true);

    final ext = path_pkg.extension(picked.path).isNotEmpty
        ? path_pkg.extension(picked.path)
        : '.jpg';
    final fileName =
        'receipt_${widget.property.id}_${_selectedMonth.year}_${_selectedMonth.month.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = path_pkg.join(receiptsDir.path, fileName);

    await File(picked.path).copy(destPath);

    // Delete old file if it was replaced
    if (_receiptPath != null && _receiptPath != destPath) {
      final old = File(_receiptPath!);
      if (old.existsSync()) old.deleteSync();
    }

    setState(() => _receiptPath = destPath);
  }

  void _deleteReceipt() {
    if (_receiptPath != null) {
      final f = File(_receiptPath!);
      if (f.existsSync()) f.deleteSync();
    }
    setState(() => _receiptPath = null);
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
        isRecurring: _isRecurring,
        recurrenceType: _isRecurring ? _recurrenceType : null,
        receiptPath: _receiptPath,
      );

      if (existing != null) {
        await PropertyDatabaseService.instance.updateExpense(expense);
      } else {
        await PropertyDatabaseService.instance.insertExpense(expense);
      }

      await paywallSession.recordAction();
      await AnalyticsService.instance.logExpenseTracked('monthly_expenses');
      if (_isRecurring) {
        await AnalyticsService.instance.logRecurringExpenseCreated();
      }

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
          backgroundColor: CalcwiseSemanticColors.errorDark,
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
        final monthLabel = DateFormat('MMMM yyyy', isSpanish ? 'es' : 'en')
            .format(_selectedMonth);
        final cfColor = _monthlyCF >= 0 ? AppTheme.success : CalcwiseSemanticColors.errorDark;

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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    // Property name banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home_rounded,
                              color: AppTheme.primary, size: 18),
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
                        leading: const Icon(Icons.calendar_month_rounded,
                            color: AppTheme.primary),
                        title: Text(
                          monthLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Icon(Icons.edit_rounded,
                            size: 18,
                            color: CalcwiseTheme.of(context).textSecondary),
                        onTap: () => _pickMonth(isSpanish),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Expense fields
                    _SectionLabel(
                        isSpanish ? 'GASTOS MENSUALES' : 'MONTHLY EXPENSES'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            _NumField(
                                ctrl: _mortCtrl,
                                label: isSpanish ? 'Hipoteca' : 'Mortgage'),
                            const SizedBox(height: 12),
                            _NumField(
                                ctrl: _taxCtrl,
                                label: isSpanish
                                    ? 'Impuestos de propiedad'
                                    : 'Property Taxes'),
                            const SizedBox(height: 12),
                            _NumField(
                                ctrl: _insCtrl,
                                label: isSpanish ? 'Seguro' : 'Insurance'),
                            const SizedBox(height: 12),
                            _NumField(
                                ctrl: _hoaCtrl,
                                label: isSpanish ? 'Cuotas HOA' : 'HOA Fees'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Property management toggle
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isSpanish
                                        ? 'Adm. de propiedad'
                                        : 'Property Management',
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
                                  : (isSpanish
                                      ? 'Cantidad mensual'
                                      : 'Monthly amount'),
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
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NumField(
                                ctrl: _maintCtrl,
                                label: isSpanish
                                    ? 'Mantenimiento / Reparaciones'
                                    : 'Maintenance / Repairs'),
                            const SizedBox(height: 12),

                            // Vacancy toggle
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isSpanish
                                        ? 'Pérdida por vacante'
                                        : 'Vacancy Loss',
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
                                  : (isSpanish
                                      ? 'Pérdida mensual'
                                      : 'Monthly loss'),
                              prefix: _vacIsPercent ? null : '\$',
                              suffix: _vacIsPercent ? '%' : null,
                            ),
                            const SizedBox(height: 12),
                            _NumField(
                                ctrl: _utilCtrl,
                                label: isSpanish
                                    ? 'Servicios públicos'
                                    : 'Utilities'),
                            const SizedBox(height: 12),
                            _NumField(
                                ctrl: _landCtrl,
                                label:
                                    isSpanish ? 'Jardinería' : 'Landscaping'),
                            const SizedBox(height: 12),
                            _NumField(
                                ctrl: _otherCtrl,
                                label: isSpanish
                                    ? 'Otros gastos'
                                    : 'Other Expenses'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Feature 2 — Recurring expense toggle
                    _SectionLabel(isSpanish ? 'RECURRENCIA' : 'RECURRENCE'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                isSpanish
                                    ? 'Gasto recurrente'
                                    : 'Recurring expense',
                                style: const TextStyle(
                                    fontSize: AppTextSize.body,
                                    fontWeight: FontWeight.w500),
                              ),
                              subtitle: Text(
                                isSpanish
                                    ? 'Se repite automáticamente'
                                    : 'Repeats automatically',
                                style: TextStyle(
                                    fontSize: AppTextSize.sm,
                                    color: CalcwiseTheme.of(context)
                                        .textSecondary),
                              ),
                              value: _isRecurring,
                              activeThumbColor: AppTheme.primary,
                              onChanged: (v) =>
                                  setState(() => _isRecurring = v),
                            ),
                            if (_isRecurring) ...[
                              Divider(
                                  height: 1,
                                  color: CalcwiseTheme.of(context).cardBorder),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                initialValue: _recurrenceType,
                                decoration: InputDecoration(
                                  labelText:
                                      isSpanish ? 'Frecuencia' : 'Frequency',
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child:
                                        Text(isSpanish ? 'Mensual' : 'Monthly'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'annual',
                                    child: Text(isSpanish ? 'Anual' : 'Annual'),
                                  ),
                                ],
                                onChanged: (v) => setState(
                                    () => _recurrenceType = v ?? 'monthly'),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Feature 3 — Receipt photo attachment
                    _SectionLabel(
                        isSpanish ? 'RECIBO / FOTO' : 'RECEIPT / PHOTO'),
                    _ReceiptSection(
                      isSpanish: isSpanish,
                      receiptPath: _receiptPath,
                      isPremium: freemiumService.hasFullAccess,
                      onAdd: () => _pickReceipt(isSpanish),
                      onDelete: _deleteReceipt,
                      onView: () {
                        if (_receiptPath == null) return;
                        Navigator.of(context).push(PageRouteBuilder(
                          pageBuilder: (_, __, ___) => ReceiptViewerScreen(
                            imagePath: _receiptPath!,
                            onDelete: () {
                              _deleteReceipt();
                            },
                          ),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                          transitionDuration: AppDuration.base,
                        ));
                      },
                      onPremiumTap: () => PaywallHard.show(context),
                    ),
                    const SizedBox(height: 20),

                    // Live results
                    _SectionLabel(
                        isSpanish ? 'RESULTADOS EN VIVO' : 'LIVE RESULTS'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          children: [
                            _ResultRow(
                              label:
                                  isSpanish ? 'Total gastos' : 'Total Expenses',
                              value: '\$${_fmt.format(_totalExpenses)}',
                              bold: true,
                            ),
                            Divider(
                                height: 20,
                                color: CalcwiseTheme.of(context).cardBorder),
                            _ResultRow(
                              label: isSpanish
                                  ? 'Flujo de caja mensual'
                                  : 'Monthly Cash Flow',
                              value:
                                  '${_monthlyCF < 0 ? '-' : ''}\$${_fmt.format(_monthlyCF.abs())}',
                              valueColor: cfColor,
                              bold: true,
                            ),
                            const SizedBox(height: 8),
                            _ResultRow(
                              label: isSpanish
                                  ? 'Ratio de gastos'
                                  : 'Expense Ratio',
                              value: '${_expenseRatio.toStringAsFixed(1)}%',
                            ),
                            const SizedBox(height: 8),
                            _ResultRow(
                              label: isSpanish
                                  ? 'Alquiler mínimo'
                                  : 'Break-Even Rent',
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
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded),
                      label:
                          Text(isSpanish ? 'Guardar Gastos' : 'Save Expenses'),
                    ),
                    const SizedBox(height: 24),
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
    _year = widget.initialYear;
    _month = widget.initialMonth;
  }

  static const List<String> _monthsEn = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  static const List<String> _monthsEs = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre'
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
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => setState(() => _year--),
              ),
              Text('$_year',
                  style: const TextStyle(
                      fontSize: AppTextSize.subtitle,
                      fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
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
                    color: selected
                        ? AppTheme.primary
                        : CalcwiseTheme.of(context).surfaceHigh,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected
                          ? AppTheme.primary
                          : CalcwiseTheme.of(context).cardBorder,
                    ),
                  ),
                  child: Text(
                    months[i].substring(0, 3),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : null,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: AppTextSize.md,
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

// ── Receipt section widget ────────────────────────────────────────────────────

class _ReceiptSection extends StatelessWidget {
  final bool isSpanish;
  final String? receiptPath;
  final bool isPremium;
  final VoidCallback onAdd;
  final VoidCallback onDelete;
  final VoidCallback onView;
  final VoidCallback onPremiumTap;

  const _ReceiptSection({
    required this.isSpanish,
    required this.receiptPath,
    required this.isPremium,
    required this.onAdd,
    required this.onDelete,
    required this.onView,
    required this.onPremiumTap,
  });

  @override
  Widget build(BuildContext context) {
    // Free user: show premium CTA button
    if (!isPremium) {
      return InkWell(
        onTap: onPremiumTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.mdPlus),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSpanish
                      ? 'Agregar Recibo (Premium)'
                      : 'Add Receipt (Premium)',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: AppTextSize.body,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.primary, size: 20),
            ],
          ),
        ),
      );
    }

    // Premium user with no photo yet
    if (receiptPath == null) {
      return OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: Text(isSpanish ? 'Agregar Recibo' : 'Add Receipt'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: const BorderSide(color: AppTheme.primary),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl)),
        ),
      );
    }

    // Premium user with photo attached
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Thumbnail
            GestureDetector(
              onTap: onView,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.mdPlus),
                child: Image.file(
                  File(receiptPath!),
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 72,
                    height: 72,
                    color: CalcwiseTheme.of(context).cardBorder,
                    child: Icon(Icons.broken_image_rounded,
                        color: CalcwiseTheme.of(context).textSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AppTheme.success, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isSpanish ? 'Recibo adjunto' : 'Receipt attached',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTextSize.body,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onView,
                        icon: const Icon(Icons.zoom_in_rounded, size: 16),
                        label: Text(
                          isSpanish ? 'Ver' : 'View',
                          style: const TextStyle(fontSize: AppTextSize.md),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                        ),
                      ),
                      const SizedBox(width: 14),
                      TextButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                        label: Text(
                          isSpanish ? 'Cambiar' : 'Change',
                          style: const TextStyle(fontSize: AppTextSize.md),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              CalcwiseTheme.of(context).textSecondary,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                        ),
                      ),
                      const SizedBox(width: 14),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 16),
                        label: Text(
                          isSpanish ? 'Quitar' : 'Remove',
                          style: const TextStyle(fontSize: AppTextSize.md),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.dangerRed,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
          style: TextStyle(
              fontSize: AppTextSize.xs,
              fontWeight: FontWeight.bold,
              color: CalcwiseTheme.of(context).textSecondary,
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
