// ignore_for_file: lines_longer_than_80_chars
import 'strings_en.dart';

class AppStringsEs extends AppStrings {
  const AppStringsEs();

  // ── App / Shell ─────────────────────────────────────────────────────────────
  @override String get appTitle => 'Gastos de Alquiler';
  @override String get navProperties => 'Propiedades';
  @override String get navCalculator => 'Calculadora';
  @override String get navReports => 'Reportes';
  @override String get navTools => 'Más Calculadoras';
  @override String get navHistory => 'Historial';

  // ── Common actions ──────────────────────────────────────────────────────────
  @override String get cancel => 'Cancelar';
  @override String get save => 'Guardar';
  @override String get delete => 'Eliminar';
  @override String get clear => 'Borrar';
  @override String get ok => 'OK';
  @override String get edit => 'Editar';
  @override String get share => 'Compartir';
  @override String get reset => 'Reiniciar';
  @override String get add => 'Agregar';
  @override String get close => 'Cerrar';
  @override String get confirm => 'Confirmar';
  @override String get remove => 'Quitar';
  @override String get view => 'Ver';
  @override String get change => 'Cambiar';
  @override String get exportPdf => 'Exportar PDF';
  @override String get goPremium => 'Obtener Premium';
  @override String get unlockPremium => 'Desbloquear Premium';
  @override String get oneTimeNoSubscription => 'Compra única · Sin suscripción';

  // ── Common field labels ──────────────────────────────────────────────────────
  @override String get required => 'Requerido';
  @override String get mustBePositive => 'Debe ser > 0';
  @override String get property => 'Propiedad';
  @override String get properties => 'Propiedades';
  @override String get propertyName => 'Nombre de la propiedad';
  @override String get address => 'Dirección';
  @override String get year => 'Año';
  @override String get month => 'Mes';
  @override String get frequency => 'Frecuencia';
  @override String get deduction => 'Deducción';
  @override String get selectMonth => 'Seleccionar Mes';
  @override String get period => 'PERÍODO';

  // ── Calculator screen ────────────────────────────────────────────────────────
  @override String get propertySetup => 'Información de la Propiedad';
  @override String get monthlyExpenses => 'Gastos Mensuales';
  @override String get results => 'Resultados';
  @override String get recalculate => 'Recalcular';
  @override String get myProperty => 'Mi Propiedad';
  @override String get propertyNameLabel => 'Nombre de la propiedad';
  @override String get monthlyRentIncome => 'Ingreso mensual de alquiler';
  @override String get investmentMetricsOptional => 'Métricas de inversión (opcional)';
  @override String get propertyValue => 'Valor de la propiedad (\$)';
  @override String get propertyValueHint => 'Precio de compra o mercado';
  @override String get cashInvested => 'Capital invertido (\$)';
  @override String get cashInvestedHint => 'Entrada + costos + reformas';
  @override String get propertyNameHint => 'Ej: Casa Principal';
  @override String get rentHint => '0.00';
  @override String get mortgagePayment => 'Pago de hipoteca';
  @override String get propertyTaxes => 'Impuestos de propiedad (anual ÷ 12)';
  @override String get homeownersInsurance => 'Seguro de propietario';
  @override String get hoaFees => 'Cuotas HOA';
  @override String get propertyManagement => 'Adm. de propiedad';
  @override String get percentOfRent => '% del alquiler';
  @override String get monthlyAmount => 'Cantidad mensual';
  @override String get maintenanceRepairs => 'Mantenimiento / Reparaciones';
  @override String get vacancyLoss => 'Pérdida por vacante';
  @override String get monthlyLoss => 'Pérdida mensual (\$)';
  @override String get utilities => 'Servicios públicos';
  @override String get landscaping => 'Jardinería / Paisajismo';
  @override String get otherExpenses => 'Otros gastos';
  @override String get expenseBreakdown => 'Desglose de Gastos';
  @override String get monthlyCashFlow => 'Flujo de Caja Mensual';
  @override String get rentMinusTotalExpenses => 'Alquiler − Gastos Totales';
  @override String get annualCF => 'Flujo Anual';
  @override String get annualNOI => 'NOI Anual';
  @override String get totalMonthlyExpenses => 'Total gastos mensuales';
  @override String get expenseRatio => 'Ratio de gastos';
  @override String get breakEvenRent => 'Alquiler mínimo necesario';
  @override String get netOperatingIncomeAnnual => 'Ingreso operativo neto (NOI anual)';
  @override String get investmentMetrics => 'Métricas de Inversión';
  @override String get annualRentDivPropertyValue => 'Alquiler anual ÷ valor de propiedad';
  @override String get annualCashFlowDivCashInvested => 'Flujo anual ÷ capital invertido';
  @override String get annualNOIDivPropertyValue => 'NOI anual ÷ valor de propiedad';
  @override String get capRateGoodCoCROIExcellent => 'Cap Rate > 6% = bueno  •  CoC ROI > 8% = excelente';
  @override String get capRateLabel => 'Cap Rate';
  @override String get cocRoiLabel => 'Retorno sobre Efectivo (CoC ROI)';
  @override String get perMonthSuffix => '/mes';
  @override String get positiveCashFlow => 'Flujo de caja positivo — propiedad rentable';
  @override String get negativeCashFlow => 'Flujo de caja negativo — revisar gastos';
  @override String get noExpensesEntered => 'Sin gastos ingresados';
  @override String get enterExpensesToSeeResults => 'Ingresa tus gastos arriba para ver los resultados';
  @override String get grossYield => 'Rendimiento bruto';
  @override String get savedToHistory => 'Guardado en historial';
  @override String get sharedSuccessfully => 'Compartido con éxito';
  @override String get shareFailed => 'Error al compartir';
  @override String get unlimitedHistory => 'Historial ilimitado';
  @override String get unlimitedHistorySubtitle => 'Guarda todas tus propiedades sin límite';

  // ── Share text ───────────────────────────────────────────────────────────────
  @override String shareTitle(String propertyName) => '🏠 $propertyName — Gastos de Alquiler';
  @override String shareMonthlyRent(String amount) => '• Alquiler mensual: $amount';
  @override String shareTotalExpenses(String amount) => '• Total gastos: $amount';
  @override String shareMonthlyCashFlow(String sign, String amount) => '• Flujo de caja mensual: ${sign}$amount';
  @override String shareAnnualCashFlow(String sign, String amount) => '• Flujo de caja anual: ${sign}$amount';
  @override String shareAnnualNOI(String amount) => '• NOI anual: $amount';
  @override String get shareCalculatedWith => 'Calculado con Rental Expenses Tracker';
  @override String get shareExportPdfCTA => '📄 Exporta el reporte completo en PDF →';

  // ── Reports screen ───────────────────────────────────────────────────────────
  @override String get reports => 'Reportes';
  @override String get noPropertiesForReport => 'Sin propiedades para reportar.';
  @override String get chartPositive => 'Positivo';
  @override String get chartNegative => 'Negativo';
  @override String get monthlyNetIncome => 'Ingreso Neto Mensual';
  @override String get annualNetIncome => 'Ingreso Neto Anual';
  @override String get avgMonthlyCashFlow => 'Flujo Mensual Promedio';
  @override String get totalProperties => 'Propiedades';
  @override String get profitableProperties => 'Rentables';
  @override String get monthlyBreakdown => 'Desglose Mensual';
  @override String get noDataForMonth => 'Sin datos para este mes.';

  // ── History screen ───────────────────────────────────────────────────────────
  @override String get history => 'Historial';
  @override String get historyTitle => 'Historial';
  @override String get entryDeleted => 'Entrada eliminada';
  @override String get clearHistory => 'Borrar todo';
  @override String get clearHistoryConfirm => 'Se eliminarán todas las entradas guardadas.';
  @override String get noSavedHistory => 'Sin historial guardado';
  @override String get noSavedHistorySubtitle => 'Calcula los gastos de una propiedad y guarda el resultado.';
  @override String get loadInCalculator => 'Cargar en calculadora';
  @override String get monthlyCFLabel => 'Flujo mensual';
  @override String savedNOfNFreeProperties(int limit) => 'Guardaste $limit de $limit propiedades gratis';
  @override String get unlockForUnlimitedHistory => 'Desbloquea Premium para historial ilimitado';
  @override String get otherSavedScenarios => 'Otros escenarios guardados';
  @override String get depreciationEntryTitle => 'Análisis de depreciación';
  @override String get mileageEntryTitle => 'Registro de millaje';
  @override String get incomeEntryTitle => 'Informe de cartera';
  @override String get taxSummaryEntryTitle => 'Resumen Schedule E';
  @override String get compareEntryTitle => 'Comparación de propiedades';
  @override String get scenarioDetails => 'Detalles del escenario';

  // ── History detail screen ────────────────────────────────────────────────────
  @override String get calculationDetail => 'Detalle de cálculo';
  @override String get income => 'Ingresos';
  @override String get rentIncome => 'Ingreso por renta';
  @override String get monthlyExpensesSection => 'Gastos mensuales';
  @override String get keyMetrics => 'Métricas clave';
  @override String get annualRent => 'Alquiler anual';
  @override String get annualExpenses => 'Gastos anuales';
  @override String get annualCashFlow => 'Flujo anual';
  @override String get breakEvenRentLabel => 'Renta mínima';
  @override String get savedLabel => 'Guardado';
  @override String get capRateGood => 'Cap Rate > 6% = bueno';
  @override String get cocRoiExcellent => 'CoC ROI > 8% = excelente';
  @override String get breakdown => 'Desglose';
  @override String get category => 'Categoría';
  @override String get amount => 'Monto';
  @override String get totalExpenses => 'TOTAL GASTOS';
  @override String get mortgage => 'Hipoteca';
  @override String get propertyTaxesLabel => 'Impuestos';
  @override String get insurance => 'Seguro';
  @override String get administration => 'Administración';
  @override String get maintenance => 'Mantenimiento';
  @override String get vacancy => 'Vacancia';
  @override String get landscapingLabel => 'Jardinería';
  @override String get other => 'Otros';
  @override String get totalExpensesLabel => 'Total gastos';
  @override String get pdfExportFailed => 'Error al exportar PDF';

  // ── Property list screen ─────────────────────────────────────────────────────
  @override String get myProperties => 'Mis Propiedades';
  @override String get sortByProfitability => 'Ordenar por rentabilidad';
  @override String get sortByName => 'Ordenar por nombre';
  @override String get sortByNewest => 'Ordenar por recientes';
  @override String get addProperty => 'Agregar propiedad';
  @override String get noPropertiesYet => 'Sin propiedades';
  @override String get noPropertiesSubtitle => 'Toca + para agregar tu primera propiedad.';
  @override String get deleteProperty => '¿Eliminar propiedad?';
  @override String deletePropertyConfirm(String name) => '¿Eliminar "$name" y todos sus datos?';
  @override String get editProperty => 'Editar propiedad';
  @override String get propertyNameDialogHint => 'Ej: Casa Principal';
  @override String get addressOptional => 'Dirección (opcional)';
  @override String get monthlyRent => 'Alquiler mensual';
  @override String get monthlyRentRequired => 'El alquiler mensual es requerido';
  @override String get squareFootageOptional => 'M² (opcional)';
  @override String get propertyAdded => 'Propiedad agregada';
  @override String get propertyUpdated => 'Propiedad actualizada';
  @override String get propertyDeleted => 'Propiedad eliminada';
  @override String get noCF => 'Sin datos';
  @override String get lastMonthCF => 'Flujo último mes';
  @override String get expenseRatioLabel => 'Ratio de gastos';
  @override String get sortLabel => 'Ordenar';
  @override String get premiumFeatureFull => 'Función Premium';
  @override String get premiumFeatureSubtitleFull => 'Actualiza a Premium para propiedades ilimitadas.';
  @override String get getPremium => 'Obtener Premium';
  @override String get propertiesLimitReached => 'Límite de propiedades alcanzado';
  @override String get propertiesLimitSubtitle => 'Actualiza a Premium para propiedades ilimitadas.';

  // ── Property detail screen ────────────────────────────────────────────────────
  @override String get propertyDetails => 'Detalles de Propiedad';
  @override String get editPropertyDetails => 'Editar Propiedad';
  @override String get noExpensesRecorded => 'Sin gastos registrados';
  @override String get addFirstExpenses => 'Toca + para agregar gastos de esta propiedad.';
  @override String get sqFt => 'M²';
  @override String get rentalIncome => 'Ingreso de Alquiler';
  @override String get lastRecorded => 'Último Registro';
  @override String get monthlyAvg => 'Promedio Mensual';
  @override String addExpensesForMonth(String month) => 'Agregar gastos de $month';
  @override String get addExpenses => 'Agregar Gastos';

  // ── Expense entry screen ──────────────────────────────────────────────────────
  @override String get addExpensesTitle => 'Agregar Gastos';
  @override String get editExpensesTitle => 'Editar Gastos';
  @override String get hipoteca => 'Hipoteca';
  @override String get propertyTaxesShort => 'Impuestos de propiedad';
  @override String get insuranceShort => 'Seguro';
  @override String get hoaFeesShort => 'Cuotas HOA';
  @override String get maintenanceRepairsShort => 'Mantenimiento / Reparaciones';
  @override String get percentOfRentShort => '% del alquiler';
  @override String get monthlyLossShort => 'Pérdida mensual';
  @override String get utilitiesShort => 'Servicios públicos';
  @override String get landscapingShort => 'Jardinería';
  @override String get otherExpensesShort => 'Otros gastos';
  @override String get recurrence => 'RECURRENCIA';
  @override String get recurringExpense => 'Gasto recurrente';
  @override String get recurringExpenseSubtitle => 'Se repite automáticamente';
  @override String get monthly => 'Mensual';
  @override String get annual => 'Anual';
  @override String get receiptPhoto => 'RECIBO / FOTO';
  @override String get addReceipt => 'Agregar Recibo';
  @override String get addReceiptPremium => 'Agregar Recibo (Premium)';
  @override String get receiptAttached => 'Recibo adjunto';
  @override String get liveResults => 'RESULTADOS EN VIVO';
  @override String get totalExpensesLive => 'Total gastos';
  @override String get monthlyCashFlowLive => 'Flujo de caja mensual';
  @override String get expenseRatioLive => 'Ratio de gastos';
  @override String get breakEvenRentLive => 'Alquiler mínimo';
  @override String get saveExpenses => 'Guardar Gastos';
  @override String get expensesSaved => 'Gastos guardados';
  @override String get errorSaving => 'Error al guardar';
  @override String get takePhoto => 'Tomar foto';
  @override String get chooseFromGallery => 'Elegir de galería';

  // ── Expense history screen ─────────────────────────────────────────────────
  @override String get expenseHistory => 'Historial de Gastos';
  @override String get noExpenseEntriesYet => 'Sin entradas de gastos';
  @override String get noExpenseEntriesSubtitle => 'Agrega gastos mensuales con el botón + en la pantalla anterior.';
  @override String get deleteEntry => 'Eliminar entrada';
  @override String deleteEntryConfirm(String month) => '¿Eliminar gastos de $month?';
  @override String get expensesLabel => 'Gastos';
  @override String get monthlyCFShort => 'flujo mensual';

  // ── Compare properties screen ──────────────────────────────────────────────
  @override String get compareProperties => 'Comparar Propiedades';
  @override String get premiumFeature => 'Función Premium';
  @override String get premiumFeatureSubtitle => 'La comparación de propiedades está disponible para usuarios Premium. Desbloquea para ver análisis lado a lado.';
  @override String get selectPropertiesMax3 => 'SELECCIONAR PROPIEDADES (máx. 3)';
  @override String get comparison => 'COMPARACIÓN';
  @override String get noPropertiesToCompare => 'Sin propiedades para comparar.';
  @override String get selectAtLeast2 => 'Selecciona al menos 2 propiedades para comparar.';
  @override String get monthlyRentRow => 'Alquiler mensual';
  @override String get totalExpensesRow => 'Total gastos';
  @override String get monthlyCFRow => 'Flujo mensual';
  @override String get annualCFRow => 'Flujo anual';
  @override String get expenseRatioRow => 'Ratio gastos';
  @override String noiAnnual(String period) => 'NOI ($period)';

  // ── Tax summary screen ─────────────────────────────────────────────────────
  @override String get taxSummary => 'Resumen Fiscal';
  @override String get taxSummaryTitle => 'Resumen Fiscal Schedule E';
  @override String get scheduleEEntries => 'Entradas Schedule E';
  @override String get noScheduleEEntries => 'Sin entradas en Schedule E';
  @override String get noScheduleESubtitle => 'Agrega depreciación o deducciones de millaje desde la pestaña Herramientas.';
  @override String get netRentalIncome => 'Ingreso Neto de Alquiler';
  @override String get netRentalLoss => 'Pérdida Neta de Alquiler';
  @override String get totalDeductions => 'Total Deducciones';
  @override String get addDeduction => 'Agregar Deducción';
  @override String get deductionAdded => 'Deducción agregada';
  @override String get deductionDeleted => 'Deducción eliminada';
  @override String get exportScheduleE => 'Exportar Schedule E';
  @override String get taxDisclaimer => 'Estimación solo para fines ilustrativos. Consulta a un profesional fiscal.';
  @override String get taxYearLabel => 'AÑO FISCAL';
  @override String get portfolioNet => 'RESUMEN PORTAFOLIO';
  @override String get totalRentalIncome => 'Total ingresos';
  @override String get netIncomeBadge => 'Ingreso neto';
  @override String get netLossBadge => 'Pérdida neta';
  @override String get editExpense => 'Editar gasto';
  @override String get addExpense => 'Agregar gasto';
  @override String get irsCategory => 'Categoría IRS';
  @override String get annualRentalIncome => 'Ingreso anual por alquiler';
  @override String get preFilledMonthlyRent => 'Prellenado con alquiler mensual × 12';
  @override String get partIExpenses => 'Parte I — Gastos (Schedule E)';
  @override String get noExpensesYetTapPlus => 'Sin gastos registrados. Toca + para agregar.';
  @override String get addIrsExpense => 'Agregar gasto IRS';
  @override String get consultTaxProfessional => 'Consulta a un profesional fiscal antes de presentar tu declaración.';

  // ── Depreciation screen ────────────────────────────────────────────────────
  @override String get depreciationCalculator => 'Calculadora de Depreciación';
  @override String get usResidential27 => 'RESIDENCIAL US — 27.5 AÑOS';
  @override String get purchasePrice => 'Precio de compra (\$)';
  @override String get landValue => 'Valor del terreno (\$) — no depreciable';
  @override String get capitalImprovements => 'Mejoras de capital (\$) — opcional';
  @override String get inServiceMonth => 'Mes en servicio';
  @override String get result => 'RESULTADO';
  @override String get depreciableBasis => 'Base depreciable';
  @override String get annualDepreciation27 => 'Depreciación anual (÷ 27.5)';
  @override String firstYearMidMonth(int year) => '1er año (mid-month, $year)';
  @override String get addToScheduleE => 'Agregar al Schedule E';
  @override String depreciationAddedScheduleE(int year) => 'Depreciación agregada al Schedule E ($year)';
  @override String get depreciationDisclaimer => 'Estimación de depreciación lineal (MACRS GDS, 27.5 años, convención de medio mes). El terreno no es depreciable. Consulta a un profesional fiscal.';
  @override String get valuesCannotBeNegative => 'Los valores no pueden ser negativos.';
  @override String get addPropertyForScheduleE => 'Agrega una propiedad para guardar la depreciación en el Schedule E.';

  // ── Mileage log screen ─────────────────────────────────────────────────────
  @override String get mileageLog => 'Registro de Millaje';
  @override String totalMilesYear(int year) => 'Total millas $year';
  @override String irsRateYear(int year) => 'Tasa IRS $year';
  @override String get deductionLabel => 'Deducción';
  @override String get addToScheduleEAutoTravel => 'Agregar al Schedule E (Auto y Viajes)';
  @override String mileageAddedScheduleE(int year) => 'Deducción de millaje agregada al Schedule E ($year)';
  @override String get trips => 'TRAYECTOS';
  @override String get noTripsYet => 'Sin trayectos. Toca + para agregar.';
  @override String get addTrip => 'Agregar trayecto';
  @override String get milesOneWay => 'Millas (un sentido)';
  @override String get roundTripX2 => 'Ida y vuelta (×2)';
  @override String get purposeLabel => 'Motivo (visita, reparación…)';
  @override String get mileageDisclaimer => 'Método de millaje estándar del IRS. Mantén un registro contemporáneo. Consulta a un profesional fiscal.';
  @override String get noPropertiesMileage => 'Sin propiedades';
  @override String get addPropertiesFirst => 'Agrega propiedades en la pestaña Propiedades.';

  // ── Tools screen ──────────────────────────────────────────────────────────
  @override String get tools => 'Más Calculadoras';
  @override String get toolsIntro => '5 calculadoras adicionales para análisis de propiedades, impuestos y comparaciones — más allá de tu Calculadora principal.';
  @override String get taxSummaryTool => 'Resumen Fiscal';
  @override String get taxSummaryToolSubtitle => 'Desglose de impuestos y deducciones';
  @override String get depreciationTool => 'Depreciación (27.5 años)';
  @override String get depreciationToolSubtitle => 'Calcula depreciación lineal residencial';
  @override String get mileageLogTool => 'Registro de Millaje';
  @override String get mileageLogToolSubtitle => 'Registra trayectos y deduce millaje IRS';
  @override String get comparePropertiesTool => 'Comparar Propiedades';
  @override String get comparePropertiesToolSubtitle => 'Comparar rentabilidad de propiedades';
  @override String get expenseHistoryTool => 'Historial de Gastos';
  @override String get expenseHistoryToolSubtitle => 'Ver historial completo — acceso directo a la pestaña Historial';
  @override String get settingsTool => 'Configuración';
  @override String get settingsToolSubtitle => 'Preferencias — acceso directo al ícono ⚙ de arriba';
  @override String get investmentRulesTitle => 'Reglas de Inversión';
  @override String get investmentRulesToolSubtitle => 'Regla del 1% · Regla del 50% · Estimación CapEx';
  @override String get investmentRulesSeedLabel => 'Desde tu calculadora:';

  // ── Silent pre-fill / data-scope clarity ───────────────────────────────────
  @override String get calculatorScratchpadNotice => 'Simulador rápido —';
  @override String get calculatorScratchpadSummary => 'no se guarda en ninguna propiedad. Para tu registro oficial mensual, usa Agregar Gasto en una propiedad.';
  @override String get expenseEntryOfficialNotice => 'Registro oficial —';
  @override String get expenseEntryOfficialSummary => 'se guarda en esta propiedad y se usa en Reportes, Resumen Fiscal y Schedule E.';

  // ── Settings screen ────────────────────────────────────────────────────────
  @override String get settings => 'Configuración';
  @override String get premiumSection => 'Premium';
  @override String get premiumTitle => 'Actualizar a Premium';
  @override String get premiumSubtitle => 'Desbloquea todas las funciones';
  @override String get premiumActive => 'Premium Activo';
  @override String get language => 'Idioma';
  @override String get notifications => 'Notificaciones';
  @override String get monthlyReminder => 'Recordatorio mensual';
  @override String get monthlyReminderSubtitle => 'Aviso el 28 de cada mes a las 10:00 AM';
  @override String get support => 'Soporte';
  @override String get rateApp => 'Calificar la App';
  @override String get privacyPolicy => 'Política de privacidad';
  @override String get termsOfUse => 'Términos de Uso';
  @override String get aboutApp => 'Acerca de';
  @override String get version => 'Versión';

  // ── Save scenario button ───────────────────────────────────────────────────
  @override String get saveScenario => 'Guardar escenario';
  @override String get saving => 'Guardando…';
  @override String get saveScenarioTitle => 'Guardar escenario';
  @override String get scenarioNameHint => 'Nombre del escenario (opcional)';
  @override String scenarioSaved(String label) => 'Escenario "$label" guardado';
  @override String get scenarioSavedNoLabel => 'Escenario guardado';

  // ── Tenants screen ─────────────────────────────────────────────────────────
  @override String get tenants => 'Locatarios';
  @override String get addTenant => 'Agregar locatario';
  @override String get editTenant => 'Editar locatario';
  @override String get noTenantsYet => 'Sin locatarios';
  @override String get noTenantsSubtitle => 'Agrega un locatario para registrar información de arrendamiento.';
  @override String get deleteTenant => 'Eliminar locatario';
  @override String deleteTenantConfirm(String name) => '¿Eliminar locatario "$name"?';
  @override String get tenantName => 'Nombre del locatario';
  @override String get tenantPhone => 'Teléfono';
  @override String get tenantEmail => 'Correo';
  @override String get leaseStart => 'Inicio de contrato';
  @override String get leaseEnd => 'Fin de contrato';
  @override String get monthlyRentTenant => 'Alquiler mensual';
  @override String get leaseStatusActive => 'Activo';
  @override String get leaseStatusExpiringSoon => 'Por vencer';
  @override String get leaseStatusExpired => 'Vencido';
  @override String expiresInDays(int days) => 'Vence en $days días';
  @override String leaseExpiredDaysAgo(int days) => 'Bail vencido hace $days días';
  @override String get tenantNameRequired => 'Nombre *';
  @override String get emailOptional => 'Email (opcional)';
  @override String get phoneOptional => 'Teléfono (opcional)';
  @override String get notes => 'Notas';
  @override String get leaseStartLabel => 'Inicio del bail';
  @override String get leaseEndLabel => 'Fin del bail';

  // ── Insight Engine ─────────────────────────────────────────────────────────
  @override String get solidCashFlowTitle => 'Flujo de caja sólido';
  @override String solidCashFlowBody(String amount) => 'Ganas \$$amount/mes neto — buena salud financiera.';
  @override String get thinMarginTitle => 'Margen ajustado';
  @override String thinMarginBody(String amount) => 'Solo \$$amount/mes de flujo neto. Cualquier reparación inesperada puede ponerte en rojo.';
  @override String get negativeCashFlowInsightTitle => 'Flujo de caja negativo';
  @override String negativeCashFlowInsightBody(String amount) => 'Pierdes \$$amount/mes. Considera subir el alquiler o reducir gastos.';
  @override String get expensesUnderControlTitle => 'Gastos bajo control';
  @override String expensesUnderControlBody(String pct) => 'Ratio de gastos del $pct% — bien por debajo del límite del 50%.';
  @override String get highExpenseRatioTitle => 'Gastos elevados';
  @override String highExpenseRatioBody(String pct) => '$pct% de los ingresos va a gastos. El estándar saludable es ≤ 50%.';
  @override String get criticalExpenseRatioTitle => 'Gastos críticos';
  @override String criticalExpenseRatioBody(String pct) => '$pct% de gastos — muy por encima del 60%. Revisa partidas mayores.';
  @override String get strongCapRateTitle => 'Cap rate atractivo';
  @override String strongCapRateBody(String pct) => 'Cap rate del $pct% — rendimiento competitivo en el mercado.';
  @override String get moderateCapRateTitle => 'Cap rate moderado';
  @override String moderateCapRateBody(String pct) => 'Cap rate del $pct%. El mínimo recomendado es 5–6% para propiedades de inversión.';
  @override String get lowCapRateTitle => 'Cap rate bajo';
  @override String lowCapRateBody(String pct) => 'Cap rate del $pct% — riesgo de rentabilidad débil a largo plazo.';
  @override String get highVacancyCostTitle => 'Vacancia alta';
  @override String highVacancyCostBody(String pct, String amount) => 'La vacancia representa el $pct% del alquiler (\$$amount/mes). Considera contratos de arrendamiento más largos.';
  @override String get notableVacancyCostTitle => 'Vacancia moderada';
  @override String notableVacancyCostBody(String amount, String pct) => '\$$amount/mes en vacancia ($pct%). El estándar de mercado es ~5–8%.';
  @override String get calculationCompleteTitle => 'Cálculo Completado';
  @override String get calculationCompleteBody => 'Desplázate hacia abajo para ver el desglose completo.';

  // ── PDF Unlock Sheet ───────────────────────────────────────────────────────
  @override String get exportPdfReport => 'Exportar Informe PDF';
  @override String get premiumUnlimited => 'Premium (ilimitado)';
  @override String get notNow => 'Ahora no';
  @override String get adNotAvailable => 'Anuncio no disponible. Inténtalo más tarde.';

  // ── Notifications ──────────────────────────────────────────────────────────
  @override String get notifTitle => '¡Registra tus gastos de renta!';
  @override String notifBody(String month) => 'Registra tus gastos de $month antes de fin de mes.';
}
