class MonthlyExpense {
  final String id;
  final String propertyId;
  final int year;
  final int month;
  final double mortgage;
  final double propertyTaxes;
  final double insurance;
  final double hoaFees;
  final double propertyMgmt;
  final double maintenance;
  final double vacancyLoss;
  final double utilities;
  final double landscaping;
  final double otherExpenses;

  const MonthlyExpense({
    required this.id,
    required this.propertyId,
    required this.year,
    required this.month,
    this.mortgage = 0,
    this.propertyTaxes = 0,
    this.insurance = 0,
    this.hoaFees = 0,
    this.propertyMgmt = 0,
    this.maintenance = 0,
    this.vacancyLoss = 0,
    this.utilities = 0,
    this.landscaping = 0,
    this.otherExpenses = 0,
  });

  double get totalExpenses => mortgage + propertyTaxes + insurance + hoaFees +
      propertyMgmt + maintenance + vacancyLoss + utilities + landscaping + otherExpenses;

  DateTime get date => DateTime(year, month);

  Map<String, dynamic> toMap() => {
    'id': id,
    'propertyId': propertyId,
    'year': year,
    'month': month,
    'mortgage': mortgage,
    'propertyTaxes': propertyTaxes,
    'insurance': insurance,
    'hoaFees': hoaFees,
    'propertyMgmt': propertyMgmt,
    'maintenance': maintenance,
    'vacancyLoss': vacancyLoss,
    'utilities': utilities,
    'landscaping': landscaping,
    'otherExpenses': otherExpenses,
  };

  factory MonthlyExpense.fromMap(Map<String, dynamic> m) => MonthlyExpense(
    id: m['id'] as String,
    propertyId: m['propertyId'] as String,
    year: m['year'] as int,
    month: m['month'] as int,
    mortgage: (m['mortgage'] as num).toDouble(),
    propertyTaxes: (m['propertyTaxes'] as num).toDouble(),
    insurance: (m['insurance'] as num).toDouble(),
    hoaFees: (m['hoaFees'] as num).toDouble(),
    propertyMgmt: (m['propertyMgmt'] as num).toDouble(),
    maintenance: (m['maintenance'] as num).toDouble(),
    vacancyLoss: (m['vacancyLoss'] as num).toDouble(),
    utilities: (m['utilities'] as num).toDouble(),
    landscaping: (m['landscaping'] as num).toDouble(),
    otherExpenses: (m['otherExpenses'] as num).toDouble(),
  );

  MonthlyExpense copyWith({
    double? mortgage, double? propertyTaxes, double? insurance, double? hoaFees,
    double? propertyMgmt, double? maintenance, double? vacancyLoss,
    double? utilities, double? landscaping, double? otherExpenses,
  }) => MonthlyExpense(
    id: id, propertyId: propertyId, year: year, month: month,
    mortgage: mortgage ?? this.mortgage,
    propertyTaxes: propertyTaxes ?? this.propertyTaxes,
    insurance: insurance ?? this.insurance,
    hoaFees: hoaFees ?? this.hoaFees,
    propertyMgmt: propertyMgmt ?? this.propertyMgmt,
    maintenance: maintenance ?? this.maintenance,
    vacancyLoss: vacancyLoss ?? this.vacancyLoss,
    utilities: utilities ?? this.utilities,
    landscaping: landscaping ?? this.landscaping,
    otherExpenses: otherExpenses ?? this.otherExpenses,
  );
}
