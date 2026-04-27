class Property {
  final String id;
  final String name;
  final String address;
  final double monthlyRent;
  final double squareFootage;
  final DateTime createdDate;

  const Property({
    required this.id,
    required this.name,
    required this.address,
    required this.monthlyRent,
    required this.squareFootage,
    required this.createdDate,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'monthlyRent': monthlyRent,
    'squareFootage': squareFootage,
    'createdDate': createdDate.toIso8601String(),
  };

  factory Property.fromMap(Map<String, dynamic> m) => Property(
    id: m['id'] as String,
    name: m['name'] as String,
    address: m['address'] as String,
    monthlyRent: (m['monthlyRent'] as num).toDouble(),
    squareFootage: (m['squareFootage'] as num).toDouble(),
    createdDate: DateTime.parse(m['createdDate'] as String),
  );

  Property copyWith({String? name, String? address, double? monthlyRent, double? squareFootage}) => Property(
    id: id,
    name: name ?? this.name,
    address: address ?? this.address,
    monthlyRent: monthlyRent ?? this.monthlyRent,
    squareFootage: squareFootage ?? this.squareFootage,
    createdDate: createdDate,
  );
}
