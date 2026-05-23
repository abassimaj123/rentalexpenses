class PaymentLog {
  final int? id;
  final String tenantId;
  final double amount;
  final DateTime paymentDate;
  final bool isPaid;
  final String? note;
  final DateTime createdAt;

  const PaymentLog({
    this.id,
    required this.tenantId,
    required this.amount,
    required this.paymentDate,
    required this.isPaid,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'tenant_id': tenantId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String(),
        'is_paid': isPaid ? 1 : 0,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory PaymentLog.fromMap(Map<String, dynamic> m) => PaymentLog(
        id: m['id'] as int?,
        tenantId: m['tenant_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        paymentDate: DateTime.parse(m['payment_date'] as String),
        isPaid: (m['is_paid'] as int) == 1,
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  PaymentLog copyWith({
    int? id,
    String? tenantId,
    double? amount,
    DateTime? paymentDate,
    bool? isPaid,
    String? note,
    DateTime? createdAt,
  }) =>
      PaymentLog(
        id: id ?? this.id,
        tenantId: tenantId ?? this.tenantId,
        amount: amount ?? this.amount,
        paymentDate: paymentDate ?? this.paymentDate,
        isPaid: isPaid ?? this.isPaid,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );
}
