import '../core/ads/ad_footer.dart';
import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/firebase/analytics_service.dart';
import '../core/freemium/freemium_service.dart';
import '../core/freemium/iap_service.dart';
import '../core/theme/app_theme.dart';
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
  final _fmt = NumberFormat('#,##0.00', 'en_US');

  List<Property> _properties = [];
  // latest expense per property id
  final Map<String, MonthlyExpense?> _latestExpense = {};
  bool _loading = true;
  _SortMode _sort = _SortMode.newest;

  static const int _freePropertyLimit = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final props = await PropertyDatabaseService.instance.getAllProperties();
    final Map<String, MonthlyExpense?> latest = {};
    for (final p in props) {
      final expenses = await PropertyDatabaseService.instance.getExpensesForProperty(p.id);
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
    final isPremium = freemiumService.isPremium;
    if (!isPremium && _properties.length >= _freePropertyLimit) {
      await PaywallHard.show(context);
      return;
    }
    await _showPropertyDialog(context, isSpanish);
  }

  Future<void> _showPropertyDialog(BuildContext ctx, bool isSpanish,
      {Property? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final addrCtrl = TextEditingController(text: existing?.address ?? '');
    final rentCtrl = TextEditingController(
        text: existing != null && existing.monthlyRent > 0
            ? existing.monthlyRent.toStringAsFixed(2) : '');
    final sqftCtrl = TextEditingController(
        text: existing != null && existing.squareFootage > 0
            ? existing.squareFootage.toStringAsFixed(0) : '');

    await showDialog<void>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(existing != null
            ? (isSpanish ? 'Editar Propiedad' : 'Edit Property')
            : (isSpanish ? 'Nueva Propiedad' : 'New Property')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                    labelText: isSpanish ? 'Nombre de la propiedad' : 'Property Name',
                    hintText: isSpanish ? 'Ej: Casa Principal' : 'e.g. Main St Duplex'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addrCtrl,
                decoration: InputDecoration(
                    labelText: isSpanish ? 'Dirección' : 'Address',
                    hintText: isSpanish ? 'Ej: 123 Calle Principal' : '123 Main St'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: isSpanish ? 'Alquiler mensual' : 'Monthly Rent',
                    prefixText: '\$',
                    hintText: '0.00'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sqftCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                decoration: InputDecoration(
                    labelText: isSpanish ? 'Superficie (ft²)' : 'Square Footage (ft²)',
                    hintText: '0'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final now = DateTime.now();
              if (existing != null) {
                final updated = existing.copyWith(
                  name: name,
                  address: addrCtrl.text.trim(),
                  monthlyRent: double.tryParse(rentCtrl.text) ?? existing.monthlyRent,
                  squareFootage: double.tryParse(sqftCtrl.text) ?? existing.squareFootage,
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
              if (d.mounted) Navigator.pop(d);
              _load();
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
            child: Text(isSpanish ? 'Guardar' : 'Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProperty(Property p, bool isSpanish) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(isSpanish ? 'Eliminar propiedad' : 'Delete property'),
        content: Text(isSpanish
            ? '¿Eliminar "${p.name}" y todos sus gastos? Esta acción no se puede deshacer.'
            : 'Delete "${p.name}" and all its expense entries? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(d, true),
            child: Text(isSpanish ? 'Eliminar' : 'Delete',
                style: const TextStyle(color: AppTheme.dangerRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await PropertyDatabaseService.instance.deleteProperty(p.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(isSpanish ? 'Mis Propiedades' : 'My Properties'),
            actions: [
              // Premium badge — always visible in AppBar
              ValueListenableBuilder<bool>(
                valueListenable: freemiumService.isPremiumNotifier,
                builder: (_, isPremium, __) {
                  if (isPremium) {
                    return const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.verified_rounded,
                          color: Colors.amber, size: 22),
                    );
                  }
                  return IconButton(
                    icon: const Icon(Icons.star_outline, color: Colors.amber),
                    tooltip: isSpanish ? 'Obtener Premium' : 'Go Premium',
                    onPressed: () => IAPService.instance.buy(),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: isSpanish ? 'Ajustes' : 'Settings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
              PopupMenuButton<_SortMode>(
                icon: const Icon(Icons.sort_rounded),
                tooltip: isSpanish ? 'Ordenar' : 'Sort',
                initialValue: _sort,
                onSelected: (m) => setState(() => _sort = m),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: _SortMode.profitability,
                    child: Row(children: [
                      Icon(_sort == _SortMode.profitability
                          ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(isSpanish ? 'Por rentabilidad' : 'By profitability'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: _SortMode.name,
                    child: Row(children: [
                      Icon(_sort == _SortMode.name
                          ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(isSpanish ? 'Por nombre' : 'By name'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: _SortMode.newest,
                    child: Row(children: [
                      Icon(_sort == _SortMode.newest
                          ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18, color: AppTheme.primary),
                      const SizedBox(width: 8),
                      Text(isSpanish ? 'Más recientes' : 'Newest first'),
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
            label: Text(isSpanish ? 'Agregar propiedad' : 'Add property'),
          ),
          body: Column(
            children: [
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _properties.isEmpty
                        ? _EmptyState(isSpanish: isSpanish)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                              itemCount: _sorted.length,
                              itemBuilder: (ctx, i) {
                                final p = _sorted[i];
                                final cf    = _cashFlow(p);
                                final ratio = _expenseRatio(p);
                                final cfColor = cf >= 0 ? AppTheme.success : AppTheme.dangerRed;
                                final hasData = _latestExpense[p.id] != null;

                                return Dismissible(
                                  key: ValueKey(p.id),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    return await showDialog<bool>(
                                          context: ctx,
                                          builder: (d) => AlertDialog(
                                            title: Text(isSpanish
                                                ? 'Eliminar propiedad'
                                                : 'Delete property'),
                                            content: Text(isSpanish
                                                ? '¿Eliminar "${p.name}" y todos sus gastos?'
                                                : 'Delete "${p.name}" and all its expense data?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, false),
                                                child: Text(isSpanish
                                                    ? 'Cancelar'
                                                    : 'Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d, true),
                                                child: Text(
                                                  isSpanish
                                                      ? 'Eliminar'
                                                      : 'Delete',
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
                                    _load();
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    margin:
                                        const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.dangerRed
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.delete_rounded,
                                        color: AppTheme.dangerRed),
                                  ),
                                  child: Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => Navigator.of(ctx).push(
                                        PageRouteBuilder(
                    pageBuilder: (_, __, ___) => PropertyDetailScreen(property: p),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 250),
                  ),
                                        ).then((_) => _load()),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 46,
                                                  height: 46,
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: const Icon(Icons.home_rounded,
                                                      color: AppTheme.primary),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        p.name,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      if (p.address.isNotEmpty)
                                                        Text(
                                                          p.address,
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            color: CalcwiseTheme.of(context).textSecondary,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(Icons.chevron_right_rounded,
                                                    color: CalcwiseTheme.of(context).textSecondary),
                                              ],
                                            ),
                                            Divider(height: 20, color: CalcwiseTheme.of(context).cardBorder),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: _MiniStat(
                                                    label: isSpanish ? 'Alquiler' : 'Rent',
                                                    value: '\$${_fmt.format(p.monthlyRent)}',
                                                    color: CalcwiseTheme.of(context).textSecondary,
                                                  ),
                                                ),
                                                if (hasData) ...[
                                                  Expanded(
                                                    child: _MiniStat(
                                                      label: isSpanish ? 'Flujo mensual' : 'Monthly CF',
                                                      value: '${cf < 0 ? '-' : '+'}\$${_fmt.format(cf.abs())}',
                                                      color: cfColor,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: _MiniStat(
                                                      label: isSpanish ? 'Ratio gastos' : 'Exp. Ratio',
                                                      value: '${ratio.toStringAsFixed(1)}%',
                                                      color: ratio < 80 ? AppTheme.success : Colors.orange,
                                                    ),
                                                  ),
                                                ] else
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      isSpanish
                                                          ? 'Sin datos de gastos aún'
                                                          : 'No expense data yet',
                                                      style: TextStyle(
                                                          fontSize: 12, color: CalcwiseTheme.of(context).textSecondary),
                                                      textAlign: TextAlign.center,
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
              const AdFooter(),
            ],
          ),
        );
      },
    );
  }
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSpanish;
  const _EmptyState({required this.isSpanish});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_work_rounded, size: 80,
                color: CalcwiseTheme.of(context).textSecondary.withValues(alpha: 0.35)),
            const SizedBox(height: 20),
            Text(
              isSpanish ? 'Agrega tu primera propiedad' : 'Add your first property',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              isSpanish
                  ? 'Registra tus propiedades y lleva el seguimiento de sus gastos e ingresos mes a mes.'
                  : 'Track your rental properties and monitor income vs. expenses month by month.',
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            const Icon(Icons.arrow_downward_rounded, color: AppTheme.primary, size: 32),
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
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: CalcwiseTheme.of(context).textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
