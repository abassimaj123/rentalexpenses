import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../core/constants/irs_categories.dart';
import '../core/constants/mileage_rates.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/services/pdf_export_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../models/mileage_trip_model.dart';
import '../models/property_model.dart';
import '../models/schedule_e_entry_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';
import '../widgets/paywall_soft.dart';
import '../widgets/save_scenario_button.dart';

/// Business-mileage log (IRS standard mileage method → Schedule E line 6,
/// "Auto and travel"). Deduction = Σ(miles) × rate-for-year.
class MileageLogScreen extends StatefulWidget {
  const MileageLogScreen({super.key});

  @override
  State<MileageLogScreen> createState() => _MileageLogScreenState();
}

class _MileageLogScreenState extends State<MileageLogScreen> {
  final _now = DateTime.now();

  List<Property> _properties = [];
  Property? _selectedProperty;
  late int _selectedYear;
  List<MileageTrip> _trips = [];
  bool _loading = true;

  // SmartHistory
  String? _currentHash;

  @override
  void initState() {
    super.initState();
    _selectedYear = _now.year;
    AnalyticsService.instance.logScreenView('mileage_log');
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final props = await PropertyDatabaseService.instance.getAllProperties();
    Property? selected = _selectedProperty;
    if (selected == null || !props.any((p) => p.id == selected!.id)) {
      selected = props.isNotEmpty ? props.first : null;
    }
    List<MileageTrip> trips = [];
    if (selected != null) {
      trips = await PropertyDatabaseService.instance
          .getMileageTripsForProperty(selected.id, _selectedYear);
    }
    if (mounted) {
      setState(() {
        _properties = props;
        _selectedProperty = selected;
        _trips = trips;
        _loading = false;
      });
      _scheduleAutoSave();
    }
  }

  double get _totalMiles => _trips.fold(0.0, (s, t) => s + t.miles);
  double get _rate => MileageRates.rateForYear(_selectedYear);
  double get _deduction => _totalMiles * _rate;

  // ── SmartHistory helpers ────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    if (_deduction <= 0) return;
    final hash = ResultHasher.hashMixed({
      'miles': _totalMiles,
      'rate': _rate,
      'year': _selectedYear,
      'property': _selectedProperty?.id ?? '',
    });
    _currentHash = hash;
    smartHistoryService.scheduleAutoSave(
      appKey: 'rentalexpenses',
      screenId: 'mileage_log',
      inputHash: hash,
      l1: {
        'total_miles': _totalMiles,
        'irs_rate': _rate,
        'deduction': _deduction,
        'year': _selectedYear,
        'property_name': _selectedProperty?.name ?? '',
      },
      l2: {
        'inputs': {
          'total_miles': _totalMiles,
          'irs_rate': _rate,
          'year': _selectedYear,
          'property_id': _selectedProperty?.id ?? '',
          'property_name': _selectedProperty?.name ?? '',
          'trip_count': _trips.length,
        },
        'results': {
          'deduction': _deduction,
        },
      },
    );
  }

  Future<void> _saveScenario(String? label) async {
    final hash = _currentHash;
    if (hash == null || _deduction <= 0) return;
    await smartHistoryService.saveScenario(
      appKey: 'rentalexpenses',
      screenId: 'mileage_log',
      inputHash: hash,
      l1: {
        'total_miles': _totalMiles,
        'irs_rate': _rate,
        'deduction': _deduction,
        'year': _selectedYear,
        'property_name': _selectedProperty?.name ?? '',
      },
      l2: {
        'inputs': {
          'total_miles': _totalMiles,
          'irs_rate': _rate,
          'year': _selectedYear,
          'property_id': _selectedProperty?.id ?? '',
          'property_name': _selectedProperty?.name ?? '',
          'trip_count': _trips.length,
        },
        'results': {
          'deduction': _deduction,
        },
      },
      label: label,
    );
    historyRefreshNotifier.value++;
    adService.onSave();
    final trigger = await paywallSession.recordAction();
    if (!mounted) return;
    if (trigger == PaywallTrigger.soft) PaywallSoft.show(context, isSpanish: isSpanishNotifier.value);
    if (trigger == PaywallTrigger.hard) PaywallHard.show(context, isSpanish: isSpanishNotifier.value);
  }

  Future<void> _exportPdf(bool isSpanish) async {
    if (_deduction <= 0) return;
    HapticFeedback.mediumImpact();

    Future<void> doExport() => PdfExportService.exportMileageLog(
          context: context,
          propertyName: _selectedProperty?.name ?? '',
          year: _selectedYear,
          totalMiles: _totalMiles,
          rate: _rate,
          deduction: _deduction,
          trips: _trips
              .map((t) => <String, dynamic>{
                    'date': t.date,
                    'miles': t.miles,
                    'purpose': t.purpose,
                  })
              .toList(),
          isSpanish: isSpanish,
        );

    if (freemiumService.hasFullAccess) {
      await doExport();
      await AnalyticsService.instance.logPdfExported();
    } else {
      await PdfExportService.showUnlockOrPay(context, doExport);
    }
  }

  @override
  void dispose() {
    smartHistoryService.cancelPendingSave('rentalexpenses', 'mileage_log');
    super.dispose();
  }

  Future<void> _addTripDialog(bool isSpanish) async {
    final property = _selectedProperty;
    if (property == null) return;

    await showDialog<void>(
      context: context,
      builder: (d) => _AddTripDialog(
        isSpanish: isSpanish,
        propertyId: property.id,
        selectedYear: _selectedYear,
        now: _now,
        onSaved: () {
          if (mounted) _load();
        },
      ),
    );
  }

  Future<void> _deleteTrip(MileageTrip trip) async {
    await PropertyDatabaseService.instance.deleteMileageTrip(trip.id);
    if (!mounted) return;
    _load();
  }

  Widget _buildTripCard(MileageTrip t, DateFormat dateFmt, bool isSpanish) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        leading:
            const Icon(Icons.directions_car_rounded, color: AppTheme.primary),
        title: Text(
          '${t.miles.toStringAsFixed(1)} mi'
          '${t.purpose.isNotEmpty ? ' · ${t.purpose}' : ''}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(dateFmt.format(t.date)),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              color: CalcwiseSemanticColors.error(
                  Theme.of(context).brightness)),
          tooltip: isSpanish ? 'Eliminar viaje' : 'Delete trip',
          onPressed: () {
            HapticFeedback.mediumImpact();
            _deleteTrip(t);
          },
        ),
      ),
    );
  }

  Future<void> _addToScheduleE(bool isSpanish) async {
    if (!freemiumService.hasFullAccess) {
      await PaywallHard.show(context, isSpanish: isSpanishNotifier.value);
      return;
    }
    final property = _selectedProperty;
    if (property == null || _deduction <= 0) return;

    final entry = ScheduleEEntry(
      id: 'sche_auto_${property.id}_${_selectedYear}_${DateTime.now().millisecondsSinceEpoch}',
      propertyId: property.id,
      year: _selectedYear,
      category: IrsCategories.autoTravel,
      amount: double.parse(_deduction.toStringAsFixed(2)),
    );
    await PropertyDatabaseService.instance.insertScheduleEEntry(entry);
    await AnalyticsService.instance.logMileageAddedToScheduleE();
    if (!mounted) return;
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.mileageAddedScheduleE(_selectedYear))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        final years = List.generate(4, (i) => _now.year - i);
        final dateFmt = DateFormat('yyyy-MM-dd');

        return Scaffold(
          appBar: AppBar(title: Text(s.mileageLog)),
          floatingActionButton: _selectedProperty == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _addTripDialog(isSpanish),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_road_rounded),
                  label: Text(s.addTrip),
                ),
          bottomNavigationBar: const CalcwiseAdFooter(),
          body: CalcwisePageEntrance(
            child: _loading
                    ? const CalcwiseLoadingState()
                    : _properties.isEmpty
                        ? _EmptyState(isSpanish: isSpanish)
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.lg, AppSpacing.lg, 90),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedProperty?.id,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                        labelText: s.property,
                                      ),
                                      items: _properties
                                          .map((p) => DropdownMenuItem(
                                                value: p.id,
                                                child: Text(p.name,
                                                    overflow: TextOverflow
                                                        .ellipsis),
                                              ))
                                          .toList(),
                                      onChanged: (v) {
                                        setState(() => _selectedProperty =
                                            _properties.firstWhere(
                                                (p) => p.id == v));
                                        _load();
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _selectedYear,
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
                                        if (v == null) return;
                                        setState(() => _selectedYear = v);
                                        _load();
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),

                              // Summary card
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  child: Column(
                                    children: [
                                      _SummaryRow(
                                        label: s.totalMilesYear(_selectedYear),
                                        value: _totalMiles.toStringAsFixed(1),
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      _SummaryRow(
                                        label: s.irsRateYear(_selectedYear),
                                        value: '\$${_rate.toStringAsFixed(3)}/mi',
                                      ),
                                      Divider(
                                          height: 22,
                                          color: CalcwiseTheme.of(context)
                                              .cardBorder),
                                      _SummaryRow(
                                        label: s.deductionLabel,
                                        value: '\$${AmountFormatter.formatNumber(_deduction)}',
                                        bold: true,
                                        color: AppTheme.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              ElevatedButton.icon(
                                onPressed: _deduction > 0
                                    ? () => _addToScheduleE(isSpanish)
                                    : null,
                                icon: const Icon(Icons.add_chart_rounded),
                                label: Text(s.addToScheduleEAutoTravel),
                                style: ElevatedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 48)),
                              ),
                              if (_deduction > 0) ...[
                                const SizedBox(height: AppSpacing.sm),
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
                              const SizedBox(height: AppSpacing.xl),

                              _SectionLabel(s.trips),
                              if (_trips.isEmpty)
                                Card(
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.lg),
                                    child: Text(
                                      s.noTripsYet,
                                      style: TextStyle(
                                          color: CalcwiseTheme.of(context)
                                              .textSecondary),
                                    ),
                                  ),
                                )
                              else if (_trips.length > 20)
                                // Trips accumulate one per drive over the
                                // life of the property — can reach hundreds
                                // for active users. Virtualize past a small
                                // threshold to avoid building every row
                                // eagerly (same fix as HELOCApp's Draw
                                // Schedule jank).
                                SizedBox(
                                  height: 420,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _trips.length,
                                    itemBuilder: (_, i) => _buildTripCard(
                                        _trips[i], dateFmt, isSpanishNotifier.value),
                                  ),
                                )
                              else
                                ..._trips.map((t) => _buildTripCard(
                                    t, dateFmt, isSpanishNotifier.value)),

                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                s.mileageDisclaimer,
                                style: TextStyle(
                                    fontSize: AppTextSize.xs,
                                    color: CalcwiseTheme.of(context)
                                        .textSecondary),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
          ),
        );
      },
    );
  }
}

class _AddTripDialog extends StatefulWidget {
  final bool isSpanish;
  final String propertyId;
  final int selectedYear;
  final DateTime now;
  final VoidCallback onSaved;

  const _AddTripDialog({
    required this.isSpanish,
    required this.propertyId,
    required this.selectedYear,
    required this.now,
    required this.onSaved,
  });

  @override
  State<_AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<_AddTripDialog> {
  late final TextEditingController milesCtrl;
  late final TextEditingController purposeCtrl;
  late DateTime tripDate;
  bool roundTrip = false;

  @override
  void initState() {
    super.initState();
    milesCtrl = TextEditingController();
    purposeCtrl = TextEditingController();
    tripDate = DateTime(widget.selectedYear, widget.now.month, widget.now.day);
  }

  @override
  void dispose() {
    milesCtrl.dispose();
    purposeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final raw = double.tryParse(milesCtrl.text.replaceAll(',', '.')) ?? 0;
    if (raw <= 0) return;
    final miles = roundTrip ? raw * 2 : raw;
    final trip = MileageTrip(
      id: 'mile_${widget.propertyId}_${DateTime.now().millisecondsSinceEpoch}',
      propertyId: widget.propertyId,
      date: tripDate,
      miles: miles,
      purpose: purposeCtrl.text.trim(),
    );
    await PropertyDatabaseService.instance.insertMileageTrip(trip);
    await AnalyticsService.instance.logMileageTripAdded();
    if (mounted) Navigator.pop(context);
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final s =
        widget.isSpanish ? const AppStringsEs() : const AppStringsEn();
    return AlertDialog(
      title: Text(s.addTrip),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: milesCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(labelText: s.milesOneWay),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              s.roundTripX2,
              style: const TextStyle(fontSize: AppTextSize.body),
            ),
            value: roundTrip,
            activeThumbColor: AppTheme.primary,
            onChanged: (v) => setState(() => roundTrip = v),
          ),
          TextField(
            controller: purposeCtrl,
            decoration: InputDecoration(labelText: s.purposeLabel),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_rounded),
            title: Text(DateFormat('yyyy-MM-dd').format(tripDate)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: tripDate,
                firstDate: DateTime(widget.selectedYear, 1, 1),
                lastDate: DateTime(widget.selectedYear, 12, 31),
              );
              if (picked != null) setState(() => tripDate = picked);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.cancel),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
          child: Text(s.save),
        ),
      ],
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _SummaryRow({
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
            Icon(Icons.directions_car_rounded,
                size: 72,
                color: CalcwiseTheme.of(context)
                    .textSecondary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.noPropertiesMileage,
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
