/// A single business-mileage trip linked to a rental property.
/// IRS standard mileage method (Schedule E line 6 — Auto and travel).
class MileageTrip {
  final String id;
  final String propertyId;
  final DateTime date;
  final double miles; // one-way miles already doubled if round-trip
  final String purpose; // visit, repair, etc.

  const MileageTrip({
    required this.id,
    required this.propertyId,
    required this.date,
    required this.miles,
    required this.purpose,
  });

  int get year => date.year;

  Map<String, dynamic> toMap() => {
        'id': id,
        'property_id': propertyId,
        'date': date.toIso8601String(),
        'miles': miles,
        'purpose': purpose,
      };

  factory MileageTrip.fromMap(Map<String, dynamic> m) => MileageTrip(
        id: m['id'] as String,
        propertyId: m['property_id'] as String,
        date: DateTime.parse(m['date'] as String),
        miles: (m['miles'] as num).toDouble(),
        purpose: m['purpose'] as String? ?? '',
      );
}
