// ignore_for_file: lines_longer_than_80_chars

/// Abstract base for all app strings.
/// Usage in every build() method:
///   final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
abstract class AppStrings {
  const AppStrings();

  // ── App / Shell ─────────────────────────────────────────────────────────────
  String get appTitle;
  String get navProperties;
  String get navCalculator;
  String get navReports;
  String get navTools;
  String get navHistory;

  // ── Common actions ──────────────────────────────────────────────────────────
  String get cancel;
  String get save;
  String get delete;
  String get clear;
  String get ok;
  String get edit;
  String get share;
  String get reset;
  String get add;
  String get close;
  String get confirm;
  String get remove;
  String get view;
  String get change;
  String get exportPdf;
  String get goPremium;
  String get unlockPremium;

  // ── Common field labels ─────────────────────────────────────────────────────
  String get required;
  String get mustBePositive;
  String get property;
  String get properties;
  String get propertyName;
  String get address;
  String get year;
  String get month;
  String get frequency;
  String get deduction;
  String get selectMonth;
  String get period;

  // ── Calculator screen ───────────────────────────────────────────────────────
  String get propertySetup;
  String get monthlyExpenses;
  String get results;
  String get recalculate;
  String get myProperty;
  String get propertyNameLabel;
  String get monthlyRentIncome;
  String get investmentMetricsOptional;
  String get propertyValue;
  String get propertyValueHint;
  String get cashInvested;
  String get cashInvestedHint;
  String get propertyNameHint;
  String get rentHint;
  String get mortgagePayment;
  String get propertyTaxes;
  String get homeownersInsurance;
  String get hoaFees;
  String get propertyManagement;
  String get percentOfRent;
  String get monthlyAmount;
  String get maintenanceRepairs;
  String get vacancyLoss;
  String get monthlyLoss;
  String get utilities;
  String get landscaping;
  String get otherExpenses;
  String get expenseBreakdown;
  String get monthlyCashFlow;
  String get rentMinusTotalExpenses;
  String get annualCF;
  String get annualNOI;
  String get totalMonthlyExpenses;
  String get expenseRatio;
  String get breakEvenRent;
  String get netOperatingIncomeAnnual;
  String get investmentMetrics;
  String get annualRentDivPropertyValue;
  String get annualCashFlowDivCashInvested;
  String get annualNOIDivPropertyValue;
  String get capRateGoodCoCROIExcellent;
  String get capRateLabel;
  String get cocRoiLabel;
  String get perMonthSuffix;
  String get positiveCashFlow;
  String get negativeCashFlow;
  String get noExpensesEntered;
  String get enterExpensesToSeeResults;
  String get grossYield;
  String get savedToHistory;
  String get sharedSuccessfully;
  String get shareFailed;
  String get unlimitedHistory;
  String get unlimitedHistorySubtitle;

  // ── Share text (multi-line) ─────────────────────────────────────────────────
  String shareTitle(String propertyName);
  String shareMonthlyRent(String amount);
  String shareTotalExpenses(String amount);
  String shareMonthlyCashFlow(String sign, String amount);
  String shareAnnualCashFlow(String sign, String amount);
  String shareAnnualNOI(String amount);
  String get shareCalculatedWith;
  String get shareExportPdfCTA;

  // ── Reports screen ──────────────────────────────────────────────────────────
  String get reports;
  String get noPropertiesForReport;
  String get chartPositive;
  String get chartNegative;
  String get monthlyNetIncome;
  String get annualNetIncome;
  String get avgMonthlyCashFlow;
  String get totalProperties;
  String get profitableProperties;
  String get monthlyBreakdown;
  String get noDataForMonth;

  // ── History screen ──────────────────────────────────────────────────────────
  String get history;
  String get historyTitle;
  String get entryDeleted;
  String get clearHistory;
  String get clearHistoryConfirm;
  String get noSavedHistory;
  String get noSavedHistorySubtitle;
  String get loadInCalculator;
  String get monthlyCFLabel;
  String savedNOfNFreeProperties(int limit);
  String get unlockForUnlimitedHistory;

  // ── History detail screen ───────────────────────────────────────────────────
  String get calculationDetail;
  String get income;
  String get rentIncome;
  String get monthlyExpensesSection;
  String get keyMetrics;
  String get annualRent;
  String get annualExpenses;
  String get annualCashFlow;
  String get breakEvenRentLabel;
  String get savedLabel;
  String get capRateGood;
  String get cocRoiExcellent;
  String get breakdown;
  String get category;
  String get amount;
  String get totalExpenses;
  String get mortgage;
  String get propertyTaxesLabel;
  String get insurance;
  String get administration;
  String get maintenance;
  String get vacancy;
  String get landscapingLabel;
  String get other;
  String get totalExpensesLabel;
  String get pdfExportFailed;

  // ── Property list screen ────────────────────────────────────────────────────
  String get myProperties;
  String get sortByProfitability;
  String get sortByName;
  String get sortByNewest;
  String get addProperty;
  String get noPropertiesYet;
  String get noPropertiesSubtitle;
  String get deleteProperty;
  String deletePropertyConfirm(String name);
  String get editProperty;
  String get propertyNameDialogHint;
  String get addressOptional;
  String get monthlyRent;
  String get monthlyRentRequired;
  String get squareFootageOptional;
  String get propertyAdded;
  String get propertyUpdated;
  String get propertyDeleted;
  String get noCF;
  String get lastMonthCF;
  String get expenseRatioLabel;
  String get sortLabel;
  String get premiumFeatureFull;
  String get premiumFeatureSubtitleFull;
  String get getPremium;
  String get propertiesLimitReached;
  String get propertiesLimitSubtitle;

  // ── Property detail screen ──────────────────────────────────────────────────
  String get propertyDetails;
  String get editPropertyDetails;
  String get noExpensesRecorded;
  String get addFirstExpenses;
  String get sqFt;
  String get rentalIncome;
  String get lastRecorded;
  String get monthlyAvg;
  String addExpensesForMonth(String month);
  String get addExpenses;

  // ── Expense entry screen ────────────────────────────────────────────────────
  String get addExpensesTitle;
  String get editExpensesTitle;
  String get hipoteca;
  String get propertyTaxesShort;
  String get insuranceShort;
  String get hoaFeesShort;
  String get maintenanceRepairsShort;
  String get percentOfRentShort;
  String get monthlyLossShort;
  String get utilitiesShort;
  String get landscapingShort;
  String get otherExpensesShort;
  String get recurrence;
  String get recurringExpense;
  String get recurringExpenseSubtitle;
  String get monthly;
  String get annual;
  String get receiptPhoto;
  String get addReceipt;
  String get addReceiptPremium;
  String get receiptAttached;
  String get liveResults;
  String get totalExpensesLive;
  String get monthlyCashFlowLive;
  String get expenseRatioLive;
  String get breakEvenRentLive;
  String get saveExpenses;
  String get expensesSaved;
  String get errorSaving;
  String get takePhoto;
  String get chooseFromGallery;

  // ── Expense history screen ──────────────────────────────────────────────────
  String get expenseHistory;
  String get noExpenseEntriesYet;
  String get noExpenseEntriesSubtitle;
  String get deleteEntry;
  String deleteEntryConfirm(String month);
  String get expensesLabel;
  String get monthlyCFShort;

  // ── Compare properties screen ───────────────────────────────────────────────
  String get compareProperties;
  String get premiumFeature;
  String get premiumFeatureSubtitle;
  String get selectPropertiesMax3;
  String get comparison;
  String get noPropertiesToCompare;
  String get selectAtLeast2;
  String get monthlyRentRow;
  String get totalExpensesRow;
  String get monthlyCFRow;
  String get annualCFRow;
  String get expenseRatioRow;
  String noiAnnual(String period);

  // ── Tax summary screen ──────────────────────────────────────────────────────
  String get taxSummary;
  String get taxSummaryTitle;
  String get scheduleEEntries;
  String get noScheduleEEntries;
  String get noScheduleESubtitle;
  String get netRentalIncome;
  String get netRentalLoss;
  String get totalDeductions;
  String get addDeduction;
  String get deductionAdded;
  String get deductionDeleted;
  String get exportScheduleE;
  String get taxDisclaimer;
  String get taxYearLabel;
  String get portfolioNet;
  String get totalRentalIncome;
  String get netIncomeBadge;
  String get netLossBadge;
  String get editExpense;
  String get addExpense;
  String get irsCategory;
  String get annualRentalIncome;
  String get preFilledMonthlyRent;
  String get partIExpenses;
  String get noExpensesYetTapPlus;
  String get addIrsExpense;
  String get consultTaxProfessional;

  // ── Depreciation screen ─────────────────────────────────────────────────────
  String get depreciationCalculator;
  String get usResidential27;
  String get purchasePrice;
  String get landValue;
  String get capitalImprovements;
  String get inServiceMonth;
  String get result;
  String get depreciableBasis;
  String get annualDepreciation27;
  String firstYearMidMonth(int year);
  String get addToScheduleE;
  String depreciationAddedScheduleE(int year);
  String get depreciationDisclaimer;
  String get valuesCannotBeNegative;
  String get addPropertyForScheduleE;

  // ── Mileage log screen ──────────────────────────────────────────────────────
  String get mileageLog;
  String totalMilesYear(int year);
  String irsRateYear(int year);
  String get deductionLabel;
  String get addToScheduleEAutoTravel;
  String mileageAddedScheduleE(int year);
  String get trips;
  String get noTripsYet;
  String get addTrip;
  String get milesOneWay;
  String get roundTripX2;
  String get purposeLabel;
  String get mileageDisclaimer;
  String get noPropertiesMileage;
  String get addPropertiesFirst;

  // ── Tools screen ───────────────────────────────────────────────────────────
  String get tools;
  String get taxSummaryTool;
  String get taxSummaryToolSubtitle;
  String get depreciationTool;
  String get depreciationToolSubtitle;
  String get mileageLogTool;
  String get mileageLogToolSubtitle;
  String get comparePropertiesTool;
  String get comparePropertiesToolSubtitle;
  String get expenseHistoryTool;
  String get expenseHistoryToolSubtitle;
  String get settingsTool;
  String get settingsToolSubtitle;
  String get investmentRulesTitle;
  String get investmentRulesToolSubtitle;

  // ── Settings screen ─────────────────────────────────────────────────────────
  String get settings;
  String get premiumSection;
  String get premiumTitle;
  String get premiumSubtitle;
  String get premiumActive;
  String get language;
  String get notifications;
  String get monthlyReminder;
  String get monthlyReminderSubtitle;
  String get support;
  String get rateApp;
  String get privacyPolicy;
  String get termsOfUse;
  String get aboutApp;
  String get version;

  // ── Save scenario button ────────────────────────────────────────────────────
  String get saveScenario;
  String get saving;
  String get saveScenarioTitle;
  String get scenarioNameHint;
  String scenarioSaved(String label);
  String get scenarioSavedNoLabel;

  // ── Tenants screen ──────────────────────────────────────────────────────────
  String get tenants;
  String get addTenant;
  String get editTenant;
  String get noTenantsYet;
  String get noTenantsSubtitle;
  String get deleteTenant;
  String deleteTenantConfirm(String name);
  String get tenantName;
  String get tenantPhone;
  String get tenantEmail;
  String get leaseStart;
  String get leaseEnd;
  String get monthlyRentTenant;
  String get leaseStatusActive;
  String get leaseStatusExpiringSoon;
  String get leaseStatusExpired;
  String expiresInDays(int days);
  String leaseExpiredDaysAgo(int days);
  String get tenantNameRequired;
  String get emailOptional;
  String get phoneOptional;
  String get notes;
  String get leaseStartLabel;
  String get leaseEndLabel;

  // ── Insight Engine ──────────────────────────────────────────────────────────
  String get solidCashFlowTitle;
  String solidCashFlowBody(String amount);
  String get thinMarginTitle;
  String thinMarginBody(String amount);
  String get negativeCashFlowInsightTitle;
  String negativeCashFlowInsightBody(String amount);
  String get expensesUnderControlTitle;
  String expensesUnderControlBody(String pct);
  String get highExpenseRatioTitle;
  String highExpenseRatioBody(String pct);
  String get criticalExpenseRatioTitle;
  String criticalExpenseRatioBody(String pct);
  String get strongCapRateTitle;
  String strongCapRateBody(String pct);
  String get moderateCapRateTitle;
  String moderateCapRateBody(String pct);
  String get lowCapRateTitle;
  String lowCapRateBody(String pct);
  String get highVacancyCostTitle;
  String highVacancyCostBody(String pct, String amount);
  String get notableVacancyCostTitle;
  String notableVacancyCostBody(String amount, String pct);
  String get calculationCompleteTitle;
  String get calculationCompleteBody;

  // ── PDF Unlock Sheet ────────────────────────────────────────────────────────
  String get exportPdfReport;
  String get premiumUnlimited;
  String get notNow;
  String get adNotAvailable;

  // ── Notifications ───────────────────────────────────────────────────────────
  String get notifTitle;
  String notifBody(String month);
}

class AppStringsEn extends AppStrings {
  const AppStringsEn();

  // ── App / Shell ─────────────────────────────────────────────────────────────
  @override String get appTitle => 'Rental Expenses';
  @override String get navProperties => 'Properties';
  @override String get navCalculator => 'Calculator';
  @override String get navReports => 'Reports';
  @override String get navTools => 'Tools';
  @override String get navHistory => 'History';

  // ── Common actions ──────────────────────────────────────────────────────────
  @override String get cancel => 'Cancel';
  @override String get save => 'Save';
  @override String get delete => 'Delete';
  @override String get clear => 'Clear';
  @override String get ok => 'OK';
  @override String get edit => 'Edit';
  @override String get share => 'Share';
  @override String get reset => 'Reset';
  @override String get add => 'Add';
  @override String get close => 'Close';
  @override String get confirm => 'Confirm';
  @override String get remove => 'Remove';
  @override String get view => 'View';
  @override String get change => 'Change';
  @override String get exportPdf => 'Export PDF';
  @override String get goPremium => 'Go Premium';
  @override String get unlockPremium => 'Unlock Premium';

  // ── Common field labels ──────────────────────────────────────────────────────
  @override String get required => 'Required';
  @override String get mustBePositive => 'Must be > 0';
  @override String get property => 'Property';
  @override String get properties => 'Properties';
  @override String get propertyName => 'Property Name';
  @override String get address => 'Address';
  @override String get year => 'Year';
  @override String get month => 'Month';
  @override String get frequency => 'Frequency';
  @override String get deduction => 'Deduction';
  @override String get selectMonth => 'Select Month';
  @override String get period => 'PERIOD';

  // ── Calculator screen ────────────────────────────────────────────────────────
  @override String get propertySetup => 'Property Setup';
  @override String get monthlyExpenses => 'Monthly Expenses';
  @override String get results => 'Results';
  @override String get recalculate => 'Recalculate';
  @override String get myProperty => 'My Property';
  @override String get propertyNameLabel => 'Property Name';
  @override String get monthlyRentIncome => 'Monthly Rent Income';
  @override String get investmentMetricsOptional => 'Investment Metrics (optional)';
  @override String get propertyValue => 'Property Value (\$)';
  @override String get propertyValueHint => 'Purchase price or market value';
  @override String get cashInvested => 'Cash Invested (\$)';
  @override String get cashInvestedHint => 'Down payment + closing costs + rehab';
  @override String get propertyNameHint => 'e.g. Main St Duplex';
  @override String get rentHint => '0.00';
  @override String get mortgagePayment => 'Mortgage Payment';
  @override String get propertyTaxes => 'Property Taxes (annual ÷ 12)';
  @override String get homeownersInsurance => 'Homeowner\'s Insurance';
  @override String get hoaFees => 'HOA Fees';
  @override String get propertyManagement => 'Property Management';
  @override String get percentOfRent => '% of rent';
  @override String get monthlyAmount => 'Monthly amount';
  @override String get maintenanceRepairs => 'Maintenance / Repairs';
  @override String get vacancyLoss => 'Vacancy Loss';
  @override String get monthlyLoss => 'Monthly loss (\$)';
  @override String get utilities => 'Utilities';
  @override String get landscaping => 'Landscaping';
  @override String get otherExpenses => 'Other Expenses';
  @override String get expenseBreakdown => 'Expense Breakdown';
  @override String get monthlyCashFlow => 'Monthly Cash Flow';
  @override String get rentMinusTotalExpenses => 'Rent − Total Expenses';
  @override String get annualCF => 'Annual CF';
  @override String get annualNOI => 'Annual NOI';
  @override String get totalMonthlyExpenses => 'Total Monthly Expenses';
  @override String get expenseRatio => 'Expense Ratio';
  @override String get breakEvenRent => 'Break-Even Rent';
  @override String get netOperatingIncomeAnnual => 'Net Operating Income (Annual NOI)';
  @override String get investmentMetrics => 'Investment Metrics';
  @override String get annualRentDivPropertyValue => 'Annual rent ÷ property value';
  @override String get annualCashFlowDivCashInvested => 'Annual cash flow ÷ cash invested';
  @override String get annualNOIDivPropertyValue => 'Annual NOI ÷ property value';
  @override String get capRateGoodCoCROIExcellent => 'Cap Rate > 6% = good  •  CoC ROI > 8% = excellent';
  @override String get capRateLabel => 'Cap Rate';
  @override String get cocRoiLabel => 'Cash-on-Cash ROI';
  @override String get perMonthSuffix => '/mo';
  @override String get positiveCashFlow => 'Positive cash flow — property is profitable';
  @override String get negativeCashFlow => 'Negative cash flow — review your expenses';
  @override String get noExpensesEntered => 'No expenses entered';
  @override String get enterExpensesToSeeResults => 'Enter your expenses above to see results';
  @override String get grossYield => 'Gross Yield';
  @override String get savedToHistory => 'Saved to history';
  @override String get sharedSuccessfully => 'Shared successfully';
  @override String get shareFailed => 'Share failed';
  @override String get unlimitedHistory => 'Unlimited History';
  @override String get unlimitedHistorySubtitle => 'Save all your properties without limit';

  // ── Share text ───────────────────────────────────────────────────────────────
  @override String shareTitle(String propertyName) => '🏠 $propertyName — Rental Expense Summary';
  @override String shareMonthlyRent(String amount) => '• Monthly Rent: $amount';
  @override String shareTotalExpenses(String amount) => '• Total Expenses: $amount';
  @override String shareMonthlyCashFlow(String sign, String amount) => '• Monthly Cash Flow: ${sign}$amount';
  @override String shareAnnualCashFlow(String sign, String amount) => '• Annual Cash Flow: ${sign}$amount';
  @override String shareAnnualNOI(String amount) => '• Annual NOI: $amount';
  @override String get shareCalculatedWith => 'Calculated with Rental Expenses Tracker';
  @override String get shareExportPdfCTA => '📄 Export the full PDF report in the app →';

  // ── Reports screen ───────────────────────────────────────────────────────────
  @override String get reports => 'Reports';
  @override String get noPropertiesForReport => 'No properties to report on.';
  @override String get chartPositive => 'Positive';
  @override String get chartNegative => 'Negative';
  @override String get monthlyNetIncome => 'Monthly Net Income';
  @override String get annualNetIncome => 'Annual Net Income';
  @override String get avgMonthlyCashFlow => 'Avg Monthly Cash Flow';
  @override String get totalProperties => 'Total Properties';
  @override String get profitableProperties => 'Profitable';
  @override String get monthlyBreakdown => 'Monthly Breakdown';
  @override String get noDataForMonth => 'No data for this month.';

  // ── History screen ───────────────────────────────────────────────────────────
  @override String get history => 'History';
  @override String get historyTitle => 'History';
  @override String get entryDeleted => 'Entry deleted';
  @override String get clearHistory => 'Clear all';
  @override String get clearHistoryConfirm => 'All saved entries will be deleted.';
  @override String get noSavedHistory => 'No saved history';
  @override String get noSavedHistorySubtitle => 'Calculate expenses for a property and save the result.';
  @override String get loadInCalculator => 'Load in calculator';
  @override String get monthlyCFLabel => 'Monthly CF';
  @override String savedNOfNFreeProperties(int limit) => 'You\'ve saved $limit of $limit free properties';
  @override String get unlockForUnlimitedHistory => 'Unlock Premium for unlimited history';

  // ── History detail screen ────────────────────────────────────────────────────
  @override String get calculationDetail => 'Calculation Detail';
  @override String get income => 'Income';
  @override String get rentIncome => 'Rent Income';
  @override String get monthlyExpensesSection => 'Monthly Expenses';
  @override String get keyMetrics => 'Key Metrics';
  @override String get annualRent => 'Annual Rent';
  @override String get annualExpenses => 'Annual Expenses';
  @override String get annualCashFlow => 'Annual Cash Flow';
  @override String get breakEvenRentLabel => 'Break-even Rent';
  @override String get savedLabel => 'Saved';
  @override String get capRateGood => 'Cap Rate > 6% = good';
  @override String get cocRoiExcellent => 'CoC ROI > 8% = excellent';
  @override String get breakdown => 'Breakdown';
  @override String get category => 'Category';
  @override String get amount => 'Amount';
  @override String get totalExpenses => 'TOTAL EXPENSES';
  @override String get mortgage => 'Mortgage';
  @override String get propertyTaxesLabel => 'Property Taxes';
  @override String get insurance => 'Insurance';
  @override String get administration => 'Property Mgmt';
  @override String get maintenance => 'Maintenance';
  @override String get vacancy => 'Vacancy Loss';
  @override String get landscapingLabel => 'Landscaping';
  @override String get other => 'Other';
  @override String get totalExpensesLabel => 'Total Expenses';
  @override String get pdfExportFailed => 'PDF export failed';

  // ── Property list screen ─────────────────────────────────────────────────────
  @override String get myProperties => 'My Properties';
  @override String get sortByProfitability => 'Sort by profitability';
  @override String get sortByName => 'Sort by name';
  @override String get sortByNewest => 'Sort by newest';
  @override String get addProperty => 'Add Property';
  @override String get noPropertiesYet => 'No properties yet';
  @override String get noPropertiesSubtitle => 'Tap + to add your first property.';
  @override String get deleteProperty => 'Delete property?';
  @override String deletePropertyConfirm(String name) => 'Delete "$name" and all its data?';
  @override String get editProperty => 'Edit Property';
  @override String get propertyNameDialogHint => 'e.g. Main St Duplex';
  @override String get addressOptional => 'Address (optional)';
  @override String get monthlyRent => 'Monthly Rent';
  @override String get monthlyRentRequired => 'Monthly rent is required';
  @override String get squareFootageOptional => 'Sq ft (optional)';
  @override String get propertyAdded => 'Property added';
  @override String get propertyUpdated => 'Property updated';
  @override String get propertyDeleted => 'Property deleted';
  @override String get noCF => 'No CF data';
  @override String get lastMonthCF => 'Last month CF';
  @override String get expenseRatioLabel => 'Expense ratio';
  @override String get sortLabel => 'Sort';
  @override String get premiumFeatureFull => 'Premium Feature';
  @override String get premiumFeatureSubtitleFull => 'Upgrade to Premium for unlimited properties.';
  @override String get getPremium => 'Get Premium';
  @override String get propertiesLimitReached => 'Property limit reached';
  @override String get propertiesLimitSubtitle => 'Upgrade to Premium for unlimited properties.';

  // ── Property detail screen ────────────────────────────────────────────────────
  @override String get propertyDetails => 'Property Details';
  @override String get editPropertyDetails => 'Edit Property';
  @override String get noExpensesRecorded => 'No expenses recorded yet';
  @override String get addFirstExpenses => 'Tap + to add expenses for this property.';
  @override String get sqFt => 'Sq Ft';
  @override String get rentalIncome => 'Rental Income';
  @override String get lastRecorded => 'Last Recorded';
  @override String get monthlyAvg => 'Monthly Avg';
  @override String addExpensesForMonth(String month) => 'Add expenses for $month';
  @override String get addExpenses => 'Add Expenses';

  // ── Expense entry screen ──────────────────────────────────────────────────────
  @override String get addExpensesTitle => 'Add Expenses';
  @override String get editExpensesTitle => 'Edit Expenses';
  @override String get hipoteca => 'Mortgage';
  @override String get propertyTaxesShort => 'Property Taxes';
  @override String get insuranceShort => 'Insurance';
  @override String get hoaFeesShort => 'HOA Fees';
  @override String get maintenanceRepairsShort => 'Maintenance / Repairs';
  @override String get percentOfRentShort => '% of rent';
  @override String get monthlyLossShort => 'Monthly loss';
  @override String get utilitiesShort => 'Utilities';
  @override String get landscapingShort => 'Landscaping';
  @override String get otherExpensesShort => 'Other Expenses';
  @override String get recurrence => 'RECURRENCE';
  @override String get recurringExpense => 'Recurring expense';
  @override String get recurringExpenseSubtitle => 'Repeats automatically';
  @override String get monthly => 'Monthly';
  @override String get annual => 'Annual';
  @override String get receiptPhoto => 'RECEIPT / PHOTO';
  @override String get addReceipt => 'Add Receipt';
  @override String get addReceiptPremium => 'Add Receipt (Premium)';
  @override String get receiptAttached => 'Receipt attached';
  @override String get liveResults => 'LIVE RESULTS';
  @override String get totalExpensesLive => 'Total Expenses';
  @override String get monthlyCashFlowLive => 'Monthly Cash Flow';
  @override String get expenseRatioLive => 'Expense Ratio';
  @override String get breakEvenRentLive => 'Break-Even Rent';
  @override String get saveExpenses => 'Save Expenses';
  @override String get expensesSaved => 'Expenses saved';
  @override String get errorSaving => 'Error saving';
  @override String get takePhoto => 'Take photo';
  @override String get chooseFromGallery => 'Choose from gallery';

  // ── Expense history screen ─────────────────────────────────────────────────
  @override String get expenseHistory => 'Expense History';
  @override String get noExpenseEntriesYet => 'No expense entries yet';
  @override String get noExpenseEntriesSubtitle => 'Add monthly expenses using the + button on the previous screen.';
  @override String get deleteEntry => 'Delete entry';
  @override String deleteEntryConfirm(String month) => 'Delete expenses for $month?';
  @override String get expensesLabel => 'Expenses';
  @override String get monthlyCFShort => 'monthly CF';

  // ── Compare properties screen ──────────────────────────────────────────────
  @override String get compareProperties => 'Compare Properties';
  @override String get premiumFeature => 'Premium Feature';
  @override String get premiumFeatureSubtitle => 'Property comparison is available for Premium users. Unlock to see side-by-side analysis.';
  @override String get selectPropertiesMax3 => 'SELECT PROPERTIES (max 3)';
  @override String get comparison => 'COMPARISON';
  @override String get noPropertiesToCompare => 'No properties to compare.';
  @override String get selectAtLeast2 => 'Select at least 2 properties to compare.';
  @override String get monthlyRentRow => 'Monthly Rent';
  @override String get totalExpensesRow => 'Total Expenses';
  @override String get monthlyCFRow => 'Monthly CF';
  @override String get annualCFRow => 'Annual CF';
  @override String get expenseRatioRow => 'Expense Ratio';
  @override String noiAnnual(String period) => 'NOI ($period)';

  // ── Tax summary screen ─────────────────────────────────────────────────────
  @override String get taxSummary => 'Tax Summary';
  @override String get taxSummaryTitle => 'Tax Summary — Schedule E';
  @override String get scheduleEEntries => 'Schedule E Entries';
  @override String get noScheduleEEntries => 'No Schedule E entries yet';
  @override String get noScheduleESubtitle => 'Add depreciation or mileage deductions from the Tools tab.';
  @override String get netRentalIncome => 'Net Rental Income';
  @override String get netRentalLoss => 'Net Rental Loss';
  @override String get totalDeductions => 'Total Deductions';
  @override String get addDeduction => 'Add Deduction';
  @override String get deductionAdded => 'Deduction added';
  @override String get deductionDeleted => 'Deduction deleted';
  @override String get exportScheduleE => 'Export Schedule E';
  @override String get taxDisclaimer => 'This is an estimate for illustrative purposes only. Consult a tax professional.';
  @override String get taxYearLabel => 'TAX YEAR';
  @override String get portfolioNet => 'PORTFOLIO NET';
  @override String get totalRentalIncome => 'Total Rental Income';
  @override String get netIncomeBadge => 'Net Income';
  @override String get netLossBadge => 'Net Loss';
  @override String get editExpense => 'Edit Expense';
  @override String get addExpense => 'Add Expense';
  @override String get irsCategory => 'IRS Category';
  @override String get annualRentalIncome => 'Annual Rental Income';
  @override String get preFilledMonthlyRent => 'Pre-filled from monthly rent × 12';
  @override String get partIExpenses => 'Part I — Expenses (Schedule E)';
  @override String get noExpensesYetTapPlus => 'No expenses yet. Tap + to add.';
  @override String get addIrsExpense => 'Add IRS Expense';
  @override String get consultTaxProfessional => 'Consult a tax professional before filing your return.';

  // ── Depreciation screen ────────────────────────────────────────────────────
  @override String get depreciationCalculator => 'Depreciation Calculator';
  @override String get usResidential27 => 'US RESIDENTIAL — 27.5 YEARS';
  @override String get purchasePrice => 'Purchase price (\$)';
  @override String get landValue => 'Land value (\$) — not depreciable';
  @override String get capitalImprovements => 'Capital improvements (\$) — optional';
  @override String get inServiceMonth => 'In-service month';
  @override String get result => 'RESULT';
  @override String get depreciableBasis => 'Depreciable basis';
  @override String get annualDepreciation27 => 'Annual depreciation (÷ 27.5)';
  @override String firstYearMidMonth(int year) => '1st year (mid-month, $year)';
  @override String get addToScheduleE => 'Add to Schedule E';
  @override String depreciationAddedScheduleE(int year) => 'Depreciation added to Schedule E ($year)';
  @override String get depreciationDisclaimer => 'Straight-line depreciation estimate (MACRS GDS, 27.5 years, mid-month convention). Land is not depreciable. Consult a tax professional.';
  @override String get valuesCannotBeNegative => 'Values cannot be negative.';
  @override String get addPropertyForScheduleE => 'Add a property to save depreciation to Schedule E.';

  // ── Mileage log screen ─────────────────────────────────────────────────────
  @override String get mileageLog => 'Mileage Log';
  @override String totalMilesYear(int year) => 'Total miles $year';
  @override String irsRateYear(int year) => 'IRS rate $year';
  @override String get deductionLabel => 'Deduction';
  @override String get addToScheduleEAutoTravel => 'Add to Schedule E (Auto & Travel)';
  @override String mileageAddedScheduleE(int year) => 'Mileage deduction added to Schedule E ($year)';
  @override String get trips => 'TRIPS';
  @override String get noTripsYet => 'No trips yet. Tap + to add.';
  @override String get addTrip => 'Add Trip';
  @override String get milesOneWay => 'Miles (one-way)';
  @override String get roundTripX2 => 'Round trip (×2)';
  @override String get purposeLabel => 'Purpose (visit, repair…)';
  @override String get mileageDisclaimer => 'IRS standard mileage method. Keep a contemporaneous log. Consult a tax professional.';
  @override String get noPropertiesMileage => 'No properties';
  @override String get addPropertiesFirst => 'Add properties in the Properties tab.';

  // ── Tools screen ──────────────────────────────────────────────────────────
  @override String get tools => 'Tools';
  @override String get taxSummaryTool => 'Tax Summary';
  @override String get taxSummaryToolSubtitle => 'Tax breakdown & deductions';
  @override String get depreciationTool => 'Depreciation (27.5 yr)';
  @override String get depreciationToolSubtitle => 'Straight-line residential depreciation';
  @override String get mileageLogTool => 'Mileage Log';
  @override String get mileageLogToolSubtitle => 'Log trips & deduct IRS mileage';
  @override String get comparePropertiesTool => 'Compare Properties';
  @override String get comparePropertiesToolSubtitle => 'Compare property profitability side-by-side';
  @override String get expenseHistoryTool => 'Expense History';
  @override String get expenseHistoryToolSubtitle => 'View full transaction history';
  @override String get settingsTool => 'Settings';
  @override String get settingsToolSubtitle => 'App preferences & settings';
  @override String get investmentRulesTitle => 'Investment Rules';
  @override String get investmentRulesToolSubtitle => '1% Rule · 50% Rule · CapEx estimate';

  // ── Settings screen ────────────────────────────────────────────────────────
  @override String get settings => 'Settings';
  @override String get premiumSection => 'Premium';
  @override String get premiumTitle => 'Upgrade to Premium';
  @override String get premiumSubtitle => 'Unlock all features';
  @override String get premiumActive => 'Premium Active';
  @override String get language => 'Language';
  @override String get notifications => 'Notifications';
  @override String get monthlyReminder => 'Monthly expense reminder';
  @override String get monthlyReminderSubtitle => 'Reminder on the 28th of each month at 10:00 AM';
  @override String get support => 'Support';
  @override String get rateApp => 'Rate the App';
  @override String get privacyPolicy => 'Privacy Policy';
  @override String get termsOfUse => 'Terms of Use';
  @override String get aboutApp => 'About';
  @override String get version => 'Version';

  // ── Save scenario button ───────────────────────────────────────────────────
  @override String get saveScenario => 'Save Scenario';
  @override String get saving => 'Saving…';
  @override String get saveScenarioTitle => 'Save Scenario';
  @override String get scenarioNameHint => 'Scenario name (optional)';
  @override String scenarioSaved(String label) => 'Scenario "$label" saved';
  @override String get scenarioSavedNoLabel => 'Scenario saved';

  // ── Tenants screen ─────────────────────────────────────────────────────────
  @override String get tenants => 'Tenants';
  @override String get addTenant => 'Add Tenant';
  @override String get editTenant => 'Edit Tenant';
  @override String get noTenantsYet => 'No tenants yet';
  @override String get noTenantsSubtitle => 'Add a tenant to track lease information.';
  @override String get deleteTenant => 'Delete Tenant';
  @override String deleteTenantConfirm(String name) => 'Delete tenant "$name"?';
  @override String get tenantName => 'Tenant Name';
  @override String get tenantPhone => 'Phone';
  @override String get tenantEmail => 'Email';
  @override String get leaseStart => 'Lease Start';
  @override String get leaseEnd => 'Lease End';
  @override String get monthlyRentTenant => 'Monthly Rent';
  @override String get leaseStatusActive => 'Active';
  @override String get leaseStatusExpiringSoon => 'Expiring Soon';
  @override String get leaseStatusExpired => 'Expired';
  @override String expiresInDays(int days) => 'Expires in $days days';
  @override String leaseExpiredDaysAgo(int days) => 'Lease expired ${days} days ago';
  @override String get tenantNameRequired => 'Name *';
  @override String get emailOptional => 'Email (optional)';
  @override String get phoneOptional => 'Phone (optional)';
  @override String get notes => 'Notes';
  @override String get leaseStartLabel => 'Lease Start';
  @override String get leaseEndLabel => 'Lease End';

  // ── Insight Engine ─────────────────────────────────────────────────────────
  @override String get solidCashFlowTitle => 'Solid cash flow';
  @override String solidCashFlowBody(String amount) => 'You net \$$amount/mo — healthy rental income.';
  @override String get thinMarginTitle => 'Thin margin';
  @override String thinMarginBody(String amount) => 'Only \$$amount/mo net. One unexpected repair could push you negative.';
  @override String get negativeCashFlowInsightTitle => 'Negative cash flow';
  @override String negativeCashFlowInsightBody(String amount) => 'You lose \$$amount/mo. Consider raising rent or cutting expenses.';
  @override String get expensesUnderControlTitle => 'Expenses under control';
  @override String expensesUnderControlBody(String pct) => '$pct% expense ratio — well below the 50% threshold.';
  @override String get highExpenseRatioTitle => 'High expense ratio';
  @override String highExpenseRatioBody(String pct) => '$pct% of rent goes to expenses. Healthy standard is ≤ 50%.';
  @override String get criticalExpenseRatioTitle => 'Critical expense ratio';
  @override String criticalExpenseRatioBody(String pct) => '$pct% in expenses — well over 60%. Review your largest cost items.';
  @override String get strongCapRateTitle => 'Strong cap rate';
  @override String strongCapRateBody(String pct) => '$pct% cap rate — competitive market yield.';
  @override String get moderateCapRateTitle => 'Moderate cap rate';
  @override String moderateCapRateBody(String pct) => '$pct% cap rate. Recommended minimum is 5–6% for investment properties.';
  @override String get lowCapRateTitle => 'Low cap rate';
  @override String lowCapRateBody(String pct) => '$pct% cap rate — weak long-term profitability risk.';
  @override String get highVacancyCostTitle => 'High vacancy cost';
  @override String highVacancyCostBody(String pct, String amount) => 'Vacancy is $pct% of rent (\$$amount/mo). Consider longer lease terms.';
  @override String get notableVacancyCostTitle => 'Notable vacancy cost';
  @override String notableVacancyCostBody(String amount, String pct) => '\$$amount/mo vacancy cost ($pct%). Market standard is ~5–8%.';
  @override String get calculationCompleteTitle => 'Calculation Complete';
  @override String get calculationCompleteBody => 'Scroll down to see the full breakdown.';

  // ── PDF Unlock Sheet ───────────────────────────────────────────────────────
  @override String get exportPdfReport => 'Export PDF Report';
  @override String get premiumUnlimited => 'Premium (unlimited)';
  @override String get notNow => 'Not now';
  @override String get adNotAvailable => 'Ad not available. Try again later.';

  // ── Notifications ──────────────────────────────────────────────────────────
  @override String get notifTitle => 'Log your rental expenses!';
  @override String notifBody(String month) => 'Log your $month expenses before month end.';
}
