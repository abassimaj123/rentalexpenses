import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../core/freemium/freemium_service.dart';
import '../core/theme/app_theme.dart';
import '../models/payment_log_model.dart';
import '../models/tenant_model.dart';
import '../services/property_database_service.dart';
import '../widgets/paywall_hard.dart';

class PaymentLogScreen extends StatefulWidget {
  final Tenant tenant;
  final bool isSpanish;

  const PaymentLogScreen({
    super.key,
    required this.tenant,
    required this.isSpanish,
  });

  @override
  State<PaymentLogScreen> createState() => _PaymentLogScreenState();
}

class _PaymentLogScreenState extends State<PaymentLogScreen> {
  final _moneyFmt = NumberFormat('#,##0.00', 'en_US');

  List<PaymentLog> _logs = [];
  double _thisMonthTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final logs = await PropertyDatabaseService.instance
        .getPaymentLogsForTenant(widget.tenant.id);
    final monthTotal = await PropertyDatabaseService.instance
        .getTotalPaidForTenant(widget.tenant.id, now.year, now.month);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _thisMonthTotal = monthTotal;
      _loading = false;
    });
  }

  // ── Grouping helpers ─────────────────────────────────────────────────────────

  /// Groups logs into months. Free users only see current month.
  Map<String, List<PaymentLog>> _groupedLogs(bool isPremium) {
    final now = DateTime.now();
    final filtered = isPremium
        ? _logs
        : _logs.where((l) {
            return l.paymentDate.year == now.year &&
                l.paymentDate.month == now.month;
          }).toList();

    final map = <String, List<PaymentLog>>{};
    for (final log in filtered) {
      final key = DateFormat(
        widget.isSpanish ? 'MMMM yyyy' : 'MMMM yyyy',
        widget.isSpanish ? 'es' : 'en',
      ).format(log.paymentDate);
      map.putIfAbsent(key, () => []).add(log);
    }
    return map;
  }

  // ── Add / Edit dialog ────────────────────────────────────────────────────────

  Future<void> _showAddDialog({PaymentLog? existing}) async {
    final amountCtrl = TextEditingController(
      text: existing != null
          ? existing.amount.toStringAsFixed(2)
          : (widget.tenant.monthlyRent > 0
              ? widget.tenant.monthlyRent.toStringAsFixed(2)
              : ''),
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    DateTime selectedDate = existing?.paymentDate ?? DateTime.now();
    bool isPaid = existing?.isPaid ?? true;
    final isSpanish = widget.isSpanish;

    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setLocal) => AlertDialog(
          title: Text(existing != null
              ? (isSpanish ? 'Editar Pago' : 'Edit Payment')
              : (isSpanish ? 'Agregar Pago' : 'Add Payment')),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))
                ],
                decoration: InputDecoration(
                  labelText: isSpanish ? 'Monto' : 'Amount',
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Date picker row
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: d,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2040),
                  );
                  if (picked != null) setLocal(() => selectedDate = picked);
                },
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 16,
                          color: CalcwiseTheme.of(context).textSecondary),
                      const SizedBox(width: AppSpacing.smPlus),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isSpanish ? 'Fecha' : 'Date',
                            style: TextStyle(
                                fontSize: AppTextSize.xs,
                                color: CalcwiseTheme.of(context).textSecondary),
                          ),
                          Text(
                            DateFormat(
                              isSpanish ? 'd MMM yyyy' : 'MMM d, yyyy',
                              isSpanish ? 'es' : 'en',
                            ).format(selectedDate),
                            style: const TextStyle(
                                fontSize: AppTextSize.body,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Icon(Icons.edit_rounded,
                          size: 14,
                          color: CalcwiseTheme.of(context).textSecondary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText:
                      isSpanish ? 'Nota (opcional)' : 'Note (optional)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  isSpanish ? 'Marcar como pagado' : 'Mark as paid',
                  style: const TextStyle(fontSize: AppTextSize.body),
                ),
                value: isPaid,
                activeThumbColor: AppTheme.primary,
                onChanged: (v) => setLocal(() => isPaid = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(80, 40)),
              onPressed: () async {
                final raw = amountCtrl.text.replaceAll(',', '.');
                final amount = double.tryParse(raw) ?? 0.0;
                if (amount <= 0) return;
                final log = PaymentLog(
                  id: existing?.id,
                  tenantId: widget.tenant.id,
                  amount: amount,
                  paymentDate: selectedDate,
                  isPaid: isPaid,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                  createdAt: existing?.createdAt ?? DateTime.now(),
                );
                if (existing != null) {
                  await PropertyDatabaseService.instance.updatePaymentLog(log);
                } else {
                  await PropertyDatabaseService.instance.insertPaymentLog(log);
                }
                if (d.mounted) Navigator.pop(d);
                _load();
              },
              child: Text(isSpanish ? 'Guardar' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLog(PaymentLog log) async {
    await PropertyDatabaseService.instance.deletePaymentLog(log.id!);
    _load();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isSpanish = widget.isSpanish;
    final isPremium = freemiumService.hasFullAccess;
    final rent = widget.tenant.monthlyRent;
    final fullyPaid = rent > 0 && _thisMonthTotal >= rent;
    final partiallyPaid = _thisMonthTotal > 0 && _thisMonthTotal < rent;

    final balanceColor = fullyPaid
        ? AppTheme.success
        : (partiallyPaid ? AppTheme.warning : AppTheme.dangerRed);

    return Scaffold(
      appBar: AppBar(
        title: Text(isSpanish ? 'Historial de Pagos' : 'Payment History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppTheme.divider),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(isSpanish ? 'Agregar Pago' : 'Add Payment'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: _BalanceCard(
                          isSpanish: isSpanish,
                          monthTotal: _thisMonthTotal,
                          rent: rent,
                          balanceColor: balanceColor,
                          moneyFmt: _moneyFmt,
                          fullyPaid: fullyPaid,
                        ),
                      ),
                      if (_logs.isEmpty)
                        SliverFillRemaining(
                          child: _EmptyState(isSpanish: isSpanish),
                        )
                      else
                        _buildLogList(isSpanish, isPremium),
                    ],
                  ),
          ),
          const CalcwiseAdFooter(),
        ],
      ),
    );
  }

  Widget _buildLogList(bool isSpanish, bool isPremium) {
    final grouped = _groupedLogs(isPremium);
    final hasHistoryLocked = !isPremium && _logs.length != grouped.values.fold(0, (s, l) => s + l.length);

    final sections = grouped.entries.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, idx) {
          // Premium upsell at the bottom when history is locked
          if (idx == sections.length) {
            if (!hasHistoryLocked) return null;
            return _PremiumHistoryBanner(
              isSpanish: isSpanish,
              onTap: () => PaywallHard.show(context),
            );
          }
          final entry = sections[idx];
          return _MonthSection(
            monthLabel: entry.key,
            logs: entry.value,
            isSpanish: isSpanish,
            moneyFmt: _moneyFmt,
            onEdit: (log) => _showAddDialog(existing: log),
            onDelete: (log) async {
              final confirmed = await _confirmDelete(log);
              if (confirmed && mounted) {
                await _deleteLog(log);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isSpanish ? 'Pago eliminado' : 'Payment deleted',
                      ),
                      action: SnackBarAction(
                        label: isSpanish ? 'Deshacer' : 'Undo',
                        onPressed: () async {
                          await PropertyDatabaseService.instance
                              .insertPaymentLog(log);
                          _load();
                        },
                      ),
                    ),
                  );
                }
              }
            },
          );
        },
        childCount: sections.length + (hasHistoryLocked ? 1 : 0),
      ),
    );
  }

  Future<bool> _confirmDelete(PaymentLog log) async {
    final isSpanish = widget.isSpanish;
    final result = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(isSpanish ? 'Eliminar pago' : 'Delete payment'),
        content: Text(
          isSpanish
              ? '¿Eliminar este registro de pago?'
              : 'Delete this payment record?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: Text(isSpanish ? 'Cancelar' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.dangerRed,
                minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(d, true),
            child: Text(isSpanish ? 'Eliminar' : 'Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

// ── Balance card ─────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final bool isSpanish;
  final double monthTotal;
  final double rent;
  final Color balanceColor;
  final NumberFormat moneyFmt;
  final bool fullyPaid;

  const _BalanceCard({
    required this.isSpanish,
    required this.monthTotal,
    required this.rent,
    required this.balanceColor,
    required this.moneyFmt,
    required this.fullyPaid,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthName = DateFormat(
      'MMMM yyyy',
      isSpanish ? 'es' : 'en',
    ).format(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.mdPlus),
        decoration: BoxDecoration(
          color: balanceColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border:
              Border.all(color: balanceColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: balanceColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                fullyPaid
                    ? Icons.check_circle_rounded
                    : Icons.pending_rounded,
                color: balanceColor,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSpanish ? 'Este Mes — $monthName' : 'This Month — $monthName',
                    style: TextStyle(
                      fontSize: AppTextSize.sm,
                      color: CalcwiseTheme.of(context).textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: AppTextSize.bodyMd),
                      children: [
                        TextSpan(
                          text: '\$${moneyFmt.format(monthTotal)} ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balanceColor,
                          ),
                        ),
                        TextSpan(
                          text: isSpanish ? 'pagado de ' : 'paid of ',
                          style: TextStyle(
                              color: CalcwiseTheme.of(context).textSecondary),
                        ),
                        TextSpan(
                          text: '\$${moneyFmt.format(rent)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
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

// ── Month section ─────────────────────────────────────────────────────────────

class _MonthSection extends StatelessWidget {
  final String monthLabel;
  final List<PaymentLog> logs;
  final bool isSpanish;
  final NumberFormat moneyFmt;
  final void Function(PaymentLog) onEdit;
  final void Function(PaymentLog) onDelete;

  const _MonthSection({
    required this.monthLabel,
    required this.logs,
    required this.isSpanish,
    required this.moneyFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              monthLabel.toUpperCase(),
              style: TextStyle(
                fontSize: AppTextSize.xs,
                fontWeight: FontWeight.bold,
                color: CalcwiseTheme.of(context).textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...logs.map((log) => _PaymentLogTile(
                log: log,
                isSpanish: isSpanish,
                moneyFmt: moneyFmt,
                onEdit: () => onEdit(log),
                onDelete: () => onDelete(log),
              )),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ── Payment log tile ──────────────────────────────────────────────────────────

class _PaymentLogTile extends StatelessWidget {
  final PaymentLog log;
  final bool isSpanish;
  final NumberFormat moneyFmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PaymentLogTile({
    required this.log,
    required this.isSpanish,
    required this.moneyFmt,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat(
      isSpanish ? 'd MMM yyyy' : 'MMM d, yyyy',
      isSpanish ? 'es' : 'en',
    );
    final chipColor = log.isPaid ? AppTheme.success : AppTheme.dangerRed;
    final chipLabel = log.isPaid
        ? (isSpanish ? 'Pagado' : 'Paid')
        : (isSpanish ? 'Pendiente' : 'Unpaid');

    return Dismissible(
      key: ValueKey(log.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppTheme.dangerRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppTheme.dangerRed),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // we handle deletion manually
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.mdPlus),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.mdPlus),
                  ),
                  child: Icon(
                    Icons.payments_rounded,
                    color: chipColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${moneyFmt.format(log.amount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: AppTextSize.bodyMd,
                        ),
                      ),
                      Text(
                        dateFmt.format(log.paymentDate),
                        style: TextStyle(
                          fontSize: AppTextSize.sm,
                          color: CalcwiseTheme.of(context).textSecondary,
                        ),
                      ),
                      if (log.note != null && log.note!.isNotEmpty)
                        Text(
                          log.note!,
                          style: TextStyle(
                            fontSize: AppTextSize.sm,
                            color: CalcwiseTheme.of(context).textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.smPlus, vertical: 4),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: chipColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    chipLabel,
                    style: TextStyle(
                      fontSize: AppTextSize.xs,
                      fontWeight: FontWeight.bold,
                      color: chipColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

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
            Icon(
              Icons.payments_outlined,
              size: 72,
              color: CalcwiseTheme.of(context)
                  .textSecondary
                  .withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isSpanish
                  ? 'Sin pagos registrados'
                  : 'No payments recorded yet',
              style: const TextStyle(
                  fontSize: AppTextSize.subtitle,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isSpanish
                  ? 'Registra tu primer pago'
                  : 'Tap + to record your first payment',
              style: TextStyle(
                  color: CalcwiseTheme.of(context).textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Premium history banner ────────────────────────────────────────────────────

class _PremiumHistoryBanner extends StatelessWidget {
  final bool isSpanish;
  final VoidCallback onTap;

  const _PremiumHistoryBanner({
    required this.isSpanish,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 100),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.mdPlus),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: AppSpacing.smPlus),
              Expanded(
                child: Text(
                  isSpanish
                      ? 'Ver historial completo (Premium)'
                      : 'View full history (Premium)',
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
      ),
    );
  }
}
