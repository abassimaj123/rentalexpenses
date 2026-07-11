import 'package:calcwise_core/calcwise_core.dart' hide PaywallHard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../models/expense_model.dart';
import '../models/property_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';
import 'property_detail_screen.dart';
import 'settings_screen.dart';

enum _SortMode { profitability, name, newest }

class PropertyListScreen extends StatefulWidget {
  const PropertyListScreen({super.key});

  @override
  State<PropertyListScreen> createState() => _PropertyListScreenState();
}

class _PropertyListScreenState extends State<PropertyListScreen> {
  // AmountFormatter replaces NumberFormat _fmt

  List<Property> _properties = [];
  // latest expense per property id
  final Map<String, MonthlyExpense?> _latestExpense = {};
  bool _loading = true;
  _SortMode _sort = _SortMode.newest;

  static const int _freePropertyLimit = 3;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('property_list');
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final props = await PropertyDatabaseService.instance.getAllProperties();
    final Map<String, MonthlyExpense?> latest = {};
    for (final p in props) {
      final expenses =
          await PropertyDatabaseService.instance.getExpensesForProperty(p.id);
      latest[p.id] = expenses.isEmpty ? null : expenses.first;
    }
    if (mounted) {
      setState(() {
        _properties = props;
        _latestExpense.addAll(latest);
        _loading = false;
      });
    }
  }

  List<Property> get _sorted {
    final list = List<Property>.from(_properties);
    switch (_sort) {
      case _SortMode.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortMode.newest:
        list.sort((a, b) => b.createdDate.compareTo(a.createdDate));
        break;
      case _SortMode.profitability:
        list.sort((a, b) {
          final cfA = _cashFlow(a);
          final cfB = _cashFlow(b);
          return cfB.compareTo(cfA);
        });
        break;
    }
    return list;
  }

  double _cashFlow(Property p) {
    final e = _latestExpense[p.id];
    return p.monthlyRent - (e?.totalExpenses ?? 0);
  }

  double _expenseRatio(Property p) {
    final e = _latestExpense[p.id];
    if (p.monthlyRent <= 0 || e == null) return 0;
    return e.totalExpenses / p.monthlyRent * 100;
  }

  Future<void> _addProperty(bool isSpanish) async {
    HapticFeedback.mediumImpact();
    final isPremium = freemiumService.hasFullAccess;
    if (!isPremium && _properties.length >= _freePropertyLimit) {
      await PaywallHard.show(context, isSpanish: isSpanishNotifier.value);
      return;
    }
    await _showPropertyDialog(context, isSpanish);
  }

  Future<void> _showPropertyDialog(BuildContext ctx, bool isSpanish,
      {Property? existing}) async {
    await showDialog<void>(
      context: ctx,
      builder: (d) => PropertyFormDialog(
        isSpanish: isSpanish,
        existing: existing,
        onSaved: _load,
      ),
    );
  }

  Future<void> _deleteProperty(Property p, bool isSpanish) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(s.deleteProperty),
        content: Text(s.deletePropertyConfirm(p.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(s.delete,
                style: const TextStyle(color: AppTheme.dangerRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await PropertyDatabaseService.instance.deleteProperty(p.id);
      historyRefreshNotifier.value++;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        return Scaffold(
          appBar: AppBar(
            title: Text(s.myProperties),
            actions: [
              // Premium badge — always visible in AppBar
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.hasFullAccessNotifier,
                builder: (_, isPremium, __) {
                  if (isPremium) {
                    return const Padding(
                      padding: EdgeInsets.only(right: AppSpacing.xs),
                      child: Icon(Icons.verified_rounded,
                          color: CalcwiseSemanticColors.warnIcon, size: 22),
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.star_outline,
                        color: CalcwiseSemanticColors.warnIcon),
                    tooltip: s.goPremium,
                    onPressed: () => PaywallHard.show(context, isSpanish: isSpanishNotifier.value),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: s.settings,
                onPressed: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const SettingsScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: AppDuration.base,
                  ),
                ),
              ),
              PopupMenuButton<_SortMode>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: s.sortLabel,
                initialValue: _sort,
                onSelected: (m) => setState(() => _sort = m),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _SortMode.profitability,
                    child: Row(children: [
                      Icon(
                          _sort == _SortMode.profitability
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: AppTheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(s.sortByProfitability),
                    ]),
                  ),
                  PopupMenuItem(
                    value: _SortMode.name,
                    child: Row(children: [
                      Icon(
                          _sort == _SortMode.name
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: AppTheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(s.sortByName),
                    ]),
                  ),
                  PopupMenuItem(
                    value: _SortMode.newest,
                    child: Row(children: [
                      Icon(
                          _sort == _SortMode.newest
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: AppTheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(s.sortByNewest),
                    ]),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _addProperty(isSpanish),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: Text(s.addProperty),
          ),
          bottomNavigationBar: const CalcwiseAdFooter(),
          body: CalcwisePageEntrance(
            child: _loading
                    ? const CalcwiseLoadingState(showHeroCard: false)
                    : _properties.isEmpty
                        ? _EmptyState(isSpanish: isSpanish)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                  AppSpacing.lg, AppSpacing.lg, 100),
                              itemCount: _sorted.length,
                              itemBuilder: (ctx, i) {
                                final p = _sorted[i];
                                final cf = _cashFlow(p);
                                final ratio = _expenseRatio(p);
                                final cfColor = cf >= 0
                                    ? AppTheme.success
                                    : AppTheme.dangerRed;
                                final hasData = _latestExpense[p.id] != null;

                                return Dismissible(
                                  key: ValueKey(p.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    return await showDialog<bool>(
                                          context: ctx,
                                          builder: (d) => AlertDialog(
                                            title: Text(s.deleteProperty),
                                            content: Text(s.deletePropertyConfirm(p.name)),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, false),
                                                child: Text(s.cancel),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, true),
                                                child: Text(
                                                  s.delete,
                                                  style: const TextStyle(
                                                      color:
                                                          AppTheme.dangerRed),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ) ??
                                        false;
                                  },
                                  onDismissed: (_) async {
                                    await PropertyDatabaseService.instance
                                        .deleteProperty(p.id);
                                    historyRefreshNotifier.value++;
                                    _load();
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(
                                        right: AppSpacing.xl),
                                    margin: const EdgeInsets.only(
                                        bottom: AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: AppTheme.dangerRed
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.xl),
                                    ),
                                    child: const Icon(Icons.delete_rounded,
                                        color: AppTheme.dangerRed),
                                  ),
                                  child: Card(
                                    margin: const EdgeInsets.only(
                                        bottom: AppSpacing.md),
                                    child: InkWell(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.xl),
                                      onTap: () => Navigator.of(ctx)
                                          .push(
                                            PageRouteBuilder(
                                              pageBuilder: (_, __, ___) =>
                                                  PropertyDetailScreen(
                                                      property: p),
                                              transitionsBuilder:
                                                  (_, anim, __, child) =>
                                                      FadeTransition(
                                                          opacity: anim,
                                                          child: child),
                                              transitionDuration:
                                                  AppDuration.base,
                                            ),
                                          )
                                          .then((_) => _load()),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.all(AppSpacing.lg),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 46,
                                                  height: 46,
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            AppRadius.lg),
                                                  ),
                                                  child: const Icon(
                                                      Icons.home_rounded,
                                                      color: AppTheme.primary),
                                                ),
                                                const SizedBox(
                                                    width: AppSpacing.md),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        p.name,
                                                        style: const TextStyle(
                                                          fontSize: AppTextSize
                                                              .bodyLg,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      if (p.address.isNotEmpty)
                                                        Text(
                                                          p.address,
                                                          style: TextStyle(
                                                            fontSize:
                                                                AppTextSize.sm,
                                                            color: CalcwiseTheme
                                                                    .of(context)
                                                                .textSecondary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                    Icons.chevron_right_rounded,
                                                    color: CalcwiseTheme.of(
                                                            context)
                                                        .textSecondary),
                                              ],
                                            ),
                                            Divider(
                                                height: 20,
                                                color: CalcwiseTheme.of(context)
                                                    .cardBorder),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _MiniStat(
                                                    label: s.monthlyRent,
                                                    value:
                                                        AmountFormatter.ui(p.monthlyRent, 'USD'),
                                                    color: CalcwiseTheme.of(
                                                            context)
                                                        .textSecondary,
                                                  ),
                                                ),
                                                if (hasData) ...[
                                                  Expanded(
                                                    child: _MiniStat(
                                                      label: s.lastMonthCF,
                                                      value:
                                                          '${cf < 0 ? '-' : '+'}${AmountFormatter.ui(cf.abs(), 'USD')}',
                                                      color: cfColor,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: _MiniStat(
                                                      label: s.expenseRatioLabel,
                                                      value:
                                                          '${ratio.toStringAsFixed(1)}%',
                                                      color: ratio < 80
                                                          ? AppTheme.success
                                                          : CalcwiseSemanticColors
                                                              .warnIcon,
                                                    ),
                                                  ),
                                                ] else
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      s.noCF,
                                                      style: TextStyle(
                                                          fontSize:
                                                              AppTextSize.sm,
                                                          color: CalcwiseTheme
                                                                  .of(context)
                                                              .textSecondary),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        );
      },
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

/// Owns its TextEditingControllers via the widget lifecycle so they're only
/// disposed when this dialog's Element actually unmounts — disposing them
/// manually right after `Navigator.pop()` races the dialog's exit transition
/// (the TextFields are still animating out) and crashes with "TextEditingController
/// used after being disposed" / '_dependents.isEmpty'.
class PropertyFormDialog extends StatefulWidget {
  final bool isSpanish;
  final Property? existing;
  final VoidCallback onSaved;

  const PropertyFormDialog({
    required this.isSpanish,
    required this.existing,
    required this.onSaved,
  });

  @override
  State<PropertyFormDialog> createState() => PropertyFormDialogState();
}

class PropertyFormDialogState extends State<PropertyFormDialog> {
  late final TextEditingController nameCtrl;
  late final TextEditingController addrCtrl;
  late final TextEditingController rentCtrl;
  late final TextEditingController sqftCtrl;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    addrCtrl = TextEditingController(text: existing?.address ?? '');
    rentCtrl = TextEditingController(
        text: existing != null && existing.monthlyRent > 0
            ? existing.monthlyRent.toStringAsFixed(2)
            : '');
    sqftCtrl = TextEditingController(
        text: existing != null && existing.squareFootage > 0
            ? existing.squareFootage.toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    addrCtrl.dispose();
    rentCtrl.dispose();
    sqftCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    final existing = widget.existing;
    final now = DateTime.now();
    if (existing != null) {
      final updated = existing.copyWith(
        name: name,
        address: addrCtrl.text.trim(),
        monthlyRent: double.tryParse(rentCtrl.text) ?? existing.monthlyRent,
        squareFootage:
            double.tryParse(sqftCtrl.text) ?? existing.squareFootage,
      );
      await PropertyDatabaseService.instance.updateProperty(updated);
    } else {
      final prop = Property(
        id: 'prop_${now.millisecondsSinceEpoch}',
        name: name,
        address: addrCtrl.text.trim(),
        monthlyRent: double.tryParse(rentCtrl.text) ?? 0,
        squareFootage: double.tryParse(sqftCtrl.text) ?? 0,
        createdDate: now,
      );
      await PropertyDatabaseService.instance.insertProperty(prop);
      await AnalyticsService.instance.logPropertyAdded();
    }
    if (mounted) Navigator.pop(context);
    historyRefreshNotifier.value++;
    widget.onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.isSpanish ? const AppStringsEs() : const AppStringsEn();
    return AlertDialog(
      title: Text(widget.existing != null ? s.editProperty : s.addProperty),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                  labelText: s.propertyName,
                  hintText: s.propertyNameDialogHint),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: addrCtrl,
              decoration: InputDecoration(
                  labelText: s.addressOptional, hintText: '123 Main St'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: rentCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: s.monthlyRent,
                  prefixText: '\$',
                  hintText: '0.00'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: sqftCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              decoration: InputDecoration(
                  labelText: s.squareFootageOptional, hintText: '0'),
            ),
          ],
        ),
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

class _EmptyState extends StatelessWidget {
  final bool isSpanish;
  const _EmptyState({required this.isSpanish});

  @override
  Widget build(BuildContext context) {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_work_rounded,
                size: 80,
                color: CalcwiseTheme.of(context)
                    .textSecondary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: AppSpacing.xl),
            Text(
              s.noPropertiesYet,
              style: const TextStyle(
                  fontSize: AppTextSize.title, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.smPlus),
            Text(
              s.noPropertiesSubtitle,
              style: TextStyle(
                  color: CalcwiseTheme.of(context).textSecondary,
                  fontSize: AppTextSize.body),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxlPlus),
            const Icon(Icons.arrow_downward_rounded,
                color: AppTheme.primary, size: 32),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: AppTextSize.xs,
                color: CalcwiseTheme.of(context).textSecondary)),
        const SizedBox(height: AppSpacing.xxs),
        Text(value,
            style: TextStyle(
                fontSize: AppTextSize.body,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}
