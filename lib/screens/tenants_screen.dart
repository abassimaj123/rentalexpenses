import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import '../core/firebase/analytics_service.dart';
import '../core/theme/app_theme.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';
import '../main.dart';
import '../models/property_model.dart';
import '../models/tenant_model.dart';
import '../ui/tenant_colors.dart';
import '../services/property_database_service.dart';

class TenantsScreen extends StatefulWidget {
  final Property property;

  const TenantsScreen({super.key, required this.property});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final _dateFmt = DateFormat('MMM d, yyyy', 'en');
  final _dateFmtEs = DateFormat('d MMM yyyy', 'es');

  List<Tenant> _tenants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('tenants');
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await PropertyDatabaseService.instance
        .getTenantsForProperty(widget.property.id);
    if (mounted)
      setState(() {
        _tenants = list;
        _loading = false;
      });
  }

  String _fmt(DateTime dt, bool isSpanish) =>
      isSpanish ? _dateFmtEs.format(dt) : _dateFmt.format(dt);

  String _statusLabel(LeaseStatus status, bool isSpanish) {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    switch (status) {
      case LeaseStatus.active:
        return s.leaseStatusActive;
      case LeaseStatus.expiringSoon:
        return s.leaseStatusExpiringSoon;
      case LeaseStatus.expired:
        return s.leaseStatusExpired;
    }
  }

  Future<void> _showTenantDialog(BuildContext ctx, bool isSpanish,
      {Tenant? existing}) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final rentCtrl = TextEditingController(
        text: existing != null && existing.monthlyRent > 0
            ? existing.monthlyRent.toStringAsFixed(2)
            : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');

    DateTime leaseStart = existing?.leaseStart ?? DateTime.now();
    DateTime leaseEnd = existing?.leaseEnd ??
        DateTime(
            DateTime.now().year + 1, DateTime.now().month, DateTime.now().day);

    await showDialog<void>(
      context: ctx,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(existing != null ? s.editTenant : s.addTenant),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: s.tenantNameRequired,
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: s.emailOptional,
                  prefixIcon: const Icon(Icons.email_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: s.phoneOptional,
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: rentCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: InputDecoration(
                  labelText: '${s.monthlyRentTenant} (\$)',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _DateRow(
                label: s.leaseStartLabel,
                date: leaseStart,
                isSpanish: isSpanish,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: d,
                    initialDate: leaseStart,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setLocal(() => leaseStart = picked);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              _DateRow(
                label: s.leaseEndLabel,
                date: leaseEnd,
                isSpanish: isSpanish,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: d,
                    initialDate: leaseEnd,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setLocal(() => leaseEnd = picked);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.notes,
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final id = existing?.id ??
                    'tenant_${widget.property.id}_${DateTime.now().millisecondsSinceEpoch}';
                final tenant = Tenant(
                  id: id,
                  propertyId: widget.property.id,
                  name: name,
                  email: emailCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  monthlyRent:
                      double.tryParse(rentCtrl.text.replaceAll(',', '.')) ??
                          0.0,
                  leaseStart: leaseStart,
                  leaseEnd: leaseEnd,
                  notes: notesCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );
                if (existing != null) {
                  await PropertyDatabaseService.instance.updateTenant(tenant);
                } else {
                  await PropertyDatabaseService.instance.insertTenant(tenant);
                  await AnalyticsService.instance.logTenantAdded();
                }
                if (d.mounted) Navigator.pop(d);
                _load();
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    rentCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _confirmDelete(
      BuildContext ctx, bool isSpanish, Tenant t) async {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        title: Text(s.deleteTenant),
        content: Text(s.deleteTenantConfirm(t.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(s.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: CalcwiseSemanticColors.errorDark,
                minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(d, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      await PropertyDatabaseService.instance.deleteTenant(t.id);
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
            title: Text(s.tenants),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _load,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showTenantDialog(context, isSpanish),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_rounded),
            label: Text(s.addTenant),
          ),
          body: CalcwisePageEntrance(
            child: Column(
            children: [
              Expanded(
                child: _loading
                    ? const CalcwiseLoadingState(showHeroCard: false)
                    : _tenants.isEmpty
                        ? _EmptyTenantsState(isSpanish: isSpanish)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                                AppSpacing.lg, AppSpacing.lg, 100),
                            itemCount: _tenants.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (ctx, i) {
                              final t = _tenants[i];
                              final daysLeft = t.daysRemaining;
                              final statusLabel =
                                  _statusLabel(t.status, isSpanish);
                              // AmountFormatter replaces local fmt

                              return Card(
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xl),
                                  onTap: () => _showTenantDialog(ctx, isSpanish,
                                      existing: t),
                                  child: Padding(
                                    padding:
                                        const EdgeInsets.all(AppSpacing.mdPlus),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: t.statusColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        AppRadius.mdPlus),
                                              ),
                                              child: Icon(
                                                Icons.person_rounded,
                                                color: t.statusColor,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(
                                                width: AppSpacing.md),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize:
                                                            AppTextSize.bodyMd),
                                                  ),
                                                  if (t.monthlyRent > 0)
                                                    Text(
                                                      '${AmountFormatter.ui(t.monthlyRent, 'USD')}/mo',
                                                      style: const TextStyle(
                                                          fontSize:
                                                              AppTextSize.sm,
                                                          color: AppTheme
                                                              .labelGray),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            // Status badge
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: t.statusColor
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                    color: t.statusColor
                                                        .withValues(
                                                            alpha: 0.4)),
                                              ),
                                              child: Text(
                                                statusLabel,
                                                style: TextStyle(
                                                  fontSize: AppTextSize.xs,
                                                  fontWeight: FontWeight.bold,
                                                  color: t.statusColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(
                                            height: AppSpacing.smPlus),
                                        Divider(
                                            height: 1,
                                            color: CalcwiseTheme.of(context)
                                                .cardBorder),
                                        const SizedBox(
                                            height: AppSpacing.smPlus),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _LeaseDateTile(
                                                icon: Icons
                                                    .calendar_today_rounded,
                                                label: s.leaseStartLabel,
                                                value: _fmt(
                                                    t.leaseStart, isSpanish),
                                              ),
                                            ),
                                            Expanded(
                                              child: _LeaseDateTile(
                                                icon: Icons
                                                    .event_available_rounded,
                                                label: s.leaseEndLabel,
                                                value:
                                                    _fmt(t.leaseEnd, isSpanish),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (t.status ==
                                            LeaseStatus.expiringSoon) ...[
                                          const SizedBox(height: AppSpacing.sm),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: AppTheme.warning
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.md),
                                              border: Border.all(
                                                  color: AppTheme.warning
                                                      .withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.warning_amber_rounded,
                                                  size: 14,
                                                  color: AppTheme.warning,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  s.expiresInDays(daysLeft),
                                                  style: const TextStyle(
                                                    fontSize: AppTextSize.sm,
                                                    color: AppTheme.warning,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (t.status ==
                                            LeaseStatus.expired) ...[
                                          const SizedBox(height: AppSpacing.sm),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: CalcwiseSemanticColors
                                                  .errorDark
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.md),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  Icons.info_outline_rounded,
                                                  size: 14,
                                                  color: CalcwiseSemanticColors
                                                      .errorDark,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  s.leaseExpiredDaysAgo(-daysLeft),
                                                  style: const TextStyle(
                                                    fontSize: AppTextSize.sm,
                                                    color:
                                                        CalcwiseSemanticColors
                                                            .errorDark,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (t.email.isNotEmpty ||
                                            t.phone.isNotEmpty) ...[
                                          const SizedBox(height: AppSpacing.sm),
                                          Wrap(
                                            spacing: 12,
                                            children: [
                                              if (t.email.isNotEmpty)
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.email_rounded,
                                                        size: 13,
                                                        color: CalcwiseTheme.of(
                                                                context)
                                                            .textSecondary),
                                                    const SizedBox(
                                                        width: AppSpacing.xs),
                                                    Text(t.email,
                                                        style: const TextStyle(
                                                            fontSize:
                                                                AppTextSize.sm,
                                                            color: AppTheme
                                                                .labelGray)),
                                                  ],
                                                ),
                                              if (t.phone.isNotEmpty)
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(Icons.phone_rounded,
                                                        size: 13,
                                                        color: CalcwiseTheme.of(
                                                                context)
                                                            .textSecondary),
                                                    const SizedBox(
                                                        width: AppSpacing.xs),
                                                    Text(t.phone,
                                                        style: const TextStyle(
                                                            fontSize:
                                                                AppTextSize.sm,
                                                            color: AppTheme
                                                                .labelGray)),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ],
                                        const SizedBox(height: AppSpacing.xs),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: IconButton(
                                            icon: Icon(
                                                Icons.delete_outline_rounded,
                                                color: CalcwiseSemanticColors
                                                    .error(Theme.of(context)
                                                        .brightness),
                                                size: 20),
                                            onPressed: () => _confirmDelete(
                                                ctx, isSpanish, t),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
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
}

// ── Small widgets ─────────────────────────────────────────────────────────────

class _LeaseDateTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _LeaseDateTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: CalcwiseTheme.of(context).textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: AppTextSize.xs,
                    color: CalcwiseTheme.of(context).textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: AppTextSize.sm, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool isSpanish;
  final VoidCallback onTap;
  const _DateRow({
    required this.label,
    required this.date,
    required this.isSpanish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = isSpanish
        ? DateFormat('d MMM yyyy', 'es')
        : DateFormat('MMM d, yyyy', 'en');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: CalcwiseTheme.of(context).surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded,
                size: 16, color: CalcwiseTheme.of(context).textSecondary),
            const SizedBox(width: AppSpacing.smPlus),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: AppTextSize.xs,
                        color: CalcwiseTheme.of(context).textSecondary)),
                Text(fmt.format(date),
                    style: const TextStyle(
                        fontSize: AppTextSize.body,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit_rounded,
                size: 14, color: CalcwiseTheme.of(context).textSecondary),
          ],
        ),
      ),
    );
  }
}

class _EmptyTenantsState extends StatelessWidget {
  final bool isSpanish;
  const _EmptyTenantsState({required this.isSpanish});

  @override
  Widget build(BuildContext context) {
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 72,
                color: CalcwiseTheme.of(context)
                    .textSecondary
                    .withValues(alpha: 0.35)),
            const SizedBox(height: AppSpacing.lg),
            Text(
              s.noTenantsYet,
              style: const TextStyle(
                  fontSize: AppTextSize.subtitle, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.noTenantsSubtitle,
              style: TextStyle(color: CalcwiseTheme.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
