/// Official IRS Schedule E Part I expense categories.
class IrsCategories {
  IrsCategories._();

  static const advertising = 'Advertising';
  static const autoTravel = 'Auto & Travel';
  static const cleaningMaintenance = 'Cleaning & Maintenance';
  static const commissions = 'Commissions';
  static const insurance = 'Insurance';
  static const legalProfessional = 'Legal & Professional Fees';
  static const managementFees = 'Management Fees';
  static const mortgageInterest = 'Mortgage Interest';
  static const otherInterest = 'Other Interest';
  static const repairs = 'Repairs';
  static const supplies = 'Supplies';
  static const taxes = 'Taxes';
  static const utilities = 'Utilities';
  static const depreciation = 'Depreciation';
  static const other = 'Other';

  static const List<String> all = [
    advertising,
    autoTravel,
    cleaningMaintenance,
    commissions,
    insurance,
    legalProfessional,
    managementFees,
    mortgageInterest,
    otherInterest,
    repairs,
    supplies,
    taxes,
    utilities,
    depreciation,
    other,
  ];

  /// Spanish translations in the same order as [all].
  static const List<String> allEs = [
    'Publicidad',
    'Auto y Viajes',
    'Limpieza y Mantenimiento',
    'Comisiones',
    'Seguro',
    'Honorarios Legales y Prof.',
    'Gastos de Administración',
    'Intereses Hipotecarios',
    'Otros Intereses',
    'Reparaciones',
    'Suministros',
    'Impuestos',
    'Servicios Públicos',
    'Depreciación',
    'Otros',
  ];

  static String translate(String category, bool isSpanish) {
    if (!isSpanish) return category;
    final idx = all.indexOf(category);
    if (idx == -1) return category;
    return allEs[idx];
  }
}
