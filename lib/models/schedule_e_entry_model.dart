/// A single IRS Schedule E expense entry (one row per category per property per year).
class ScheduleEEntry {
  final String id;
  final String propertyId;
  final int year;
  final String category; // One of IrsCategories.all
  final double amount;
  final bool isRecurring;
  final String? recurrenceType; // 'monthly' | 'annual' | null

  const ScheduleEEntry({
    required this.id,
    required this.propertyId,
    required this.year,
    required this.category,
    required this.amount,
    this.isRecurring = false,
    this.recurrenceType,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'property_id': propertyId,
        'year': year,
        'category': category,
        'amount': amount,
        'is_recurring': isRecurring ? 1 : 0,
        'recurrence_type': recurrenceType,
      };

  factory ScheduleEEntry.fromMap(Map<String, dynamic> m) => ScheduleEEntry(
        id: m['id'] as String,
        propertyId: m['property_id'] as String,
        year: m['year'] as int,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        isRecurring: (m['is_recurring'] as int? ?? 0) == 1,
        recurrenceType: m['recurrence_type'] as String?,
      );

  ScheduleEEntry copyWith({
    String? category,
    double? amount,
    bool? isRecurring,
    String? recurrenceType,
  }) =>
      ScheduleEEntry(
        id: id,
        propertyId: propertyId,
        year: year,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        isRecurring: isRecurring ?? this.isRecurring,
        recurrenceType: recurrenceType ?? this.recurrenceType,
      );
}
