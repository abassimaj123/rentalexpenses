import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';

class InsightEngine {
  InsightEngine._();

  static List<Insight> generate({
    required double monthlyRent,
    required double totalMonthlyExpenses,
    required double monthlyCashFlow,
    required double expenseRatioPct,
    required double vacancyLoss,
    double? capRate,
    bool isSpanish = false,
    int maxCount = 4,
  }) {
    final insights = <Insight>[];

    // 1. Cash Flow Health
    if (monthlyCashFlow >= 300) {
      insights.add(Insight(
        severity: InsightSeverity.good,
        title: isSpanish ? 'Flujo de caja sólido' : 'Solid cash flow',
        body: isSpanish
            ? 'Ganas \$${monthlyCashFlow.toStringAsFixed(0)}/mes neto — buena salud financiera.'
            : 'You net \$${monthlyCashFlow.toStringAsFixed(0)}/mo — healthy rental income.',
      ));
    } else if (monthlyCashFlow >= 0) {
      insights.add(Insight(
        severity: InsightSeverity.warning,
        title: isSpanish ? 'Margen ajustado' : 'Thin margin',
        body: isSpanish
            ? 'Solo \$${monthlyCashFlow.toStringAsFixed(0)}/mes de flujo neto. Cualquier reparación inesperada puede ponerte en rojo.'
            : 'Only \$${monthlyCashFlow.toStringAsFixed(0)}/mo net. One unexpected repair could push you negative.',
      ));
    } else {
      insights.add(Insight(
        severity: InsightSeverity.alert,
        title: isSpanish ? 'Flujo de caja negativo' : 'Negative cash flow',
        body: isSpanish
            ? 'Pierdes \$${(-monthlyCashFlow).toStringAsFixed(0)}/mes. Considera subir el alquiler o reducir gastos.'
            : 'You lose \$${(-monthlyCashFlow).toStringAsFixed(0)}/mo. Consider raising rent or cutting expenses.',
      ));
    }

    // 2. Expense Ratio
    if (expenseRatioPct <= 40) {
      insights.add(Insight(
        severity: InsightSeverity.good,
        title: isSpanish ? 'Gastos bajo control' : 'Expenses under control',
        body: isSpanish
            ? 'Ratio de gastos del ${expenseRatioPct.toStringAsFixed(0)}% — bien por debajo del límite del 50%.'
            : '${expenseRatioPct.toStringAsFixed(0)}% expense ratio — well below the 50% threshold.',
      ));
    } else if (expenseRatioPct <= 60) {
      insights.add(Insight(
        severity: InsightSeverity.warning,
        title: isSpanish ? 'Gastos elevados' : 'High expense ratio',
        body: isSpanish
            ? '${expenseRatioPct.toStringAsFixed(0)}% de los ingresos va a gastos. El estándar saludable es ≤ 50%.'
            : '${expenseRatioPct.toStringAsFixed(0)}% of rent goes to expenses. Healthy standard is ≤ 50%.',
      ));
    } else {
      insights.add(Insight(
        severity: InsightSeverity.alert,
        title: isSpanish ? 'Gastos críticos' : 'Critical expense ratio',
        body: isSpanish
            ? '${expenseRatioPct.toStringAsFixed(0)}% de gastos — muy por encima del 60%. Revisa partidas mayores.'
            : '${expenseRatioPct.toStringAsFixed(0)}% in expenses — well over 60%. Review your largest cost items.',
      ));
    }

    // 3. Cap Rate (only when propertyValue provided)
    if (capRate != null) {
      if (capRate >= 6) {
        insights.add(Insight(
          severity: InsightSeverity.good,
          title: isSpanish ? 'Cap rate atractivo' : 'Strong cap rate',
          body: isSpanish
              ? 'Cap rate del ${capRate.toStringAsFixed(1)}% — rendimiento competitivo en el mercado.'
              : '${capRate.toStringAsFixed(1)}% cap rate — competitive market yield.',
        ));
      } else if (capRate >= 3) {
        insights.add(Insight(
          severity: InsightSeverity.warning,
          title: isSpanish ? 'Cap rate moderado' : 'Moderate cap rate',
          body: isSpanish
              ? 'Cap rate del ${capRate.toStringAsFixed(1)}%. El mínimo recomendado es 5–6% para propiedades de inversión.'
              : '${capRate.toStringAsFixed(1)}% cap rate. Recommended minimum is 5–6% for investment properties.',
        ));
      } else {
        insights.add(Insight(
          severity: InsightSeverity.alert,
          title: isSpanish ? 'Cap rate bajo' : 'Low cap rate',
          body: isSpanish
              ? 'Cap rate del ${capRate.toStringAsFixed(1)}% — riesgo de rentabilidad débil a largo plazo.'
              : '${capRate.toStringAsFixed(1)}% cap rate — weak long-term profitability risk.',
        ));
      }
    }

    // 4. Vacancy Loss
    if (monthlyRent > 0) {
      final vacancyPct = vacancyLoss / monthlyRent * 100;
      if (vacancyPct > 15) {
        insights.add(Insight(
          severity: InsightSeverity.alert,
          title: isSpanish ? 'Vacancia alta' : 'High vacancy cost',
          body: isSpanish
              ? 'La vacancia representa el ${vacancyPct.toStringAsFixed(0)}% del alquiler (\$${vacancyLoss.toStringAsFixed(0)}/mes). Considera contratos de arrendamiento más largos.'
              : 'Vacancy is ${vacancyPct.toStringAsFixed(0)}% of rent (\$${vacancyLoss.toStringAsFixed(0)}/mo). Consider longer lease terms.',
        ));
      } else if (vacancyPct > 8) {
        insights.add(Insight(
          severity: InsightSeverity.warning,
          title: isSpanish ? 'Vacancia moderada' : 'Notable vacancy cost',
          body: isSpanish
              ? '\$${vacancyLoss.toStringAsFixed(0)}/mes en vacancia (${vacancyPct.toStringAsFixed(0)}%). El estándar de mercado es ~5–8%.'
              : '\$${vacancyLoss.toStringAsFixed(0)}/mo vacancy cost (${vacancyPct.toStringAsFixed(0)}%). Market standard is ~5–8%.',
        ));
      }
    }

    // Sort: alerts first, then warnings, then good
    insights.sort((a, b) {
      const order = {
        InsightSeverity.alert: 0,
        InsightSeverity.warning: 1,
        InsightSeverity.good: 2,
      };
      return order[a.severity]!.compareTo(order[b.severity]!);
    });

    if (insights.isEmpty) {
      insights.add(Insight(
        severity: InsightSeverity.good,
        title: isSpanish ? 'Cálculo Completado' : 'Calculation Complete',
        body: isSpanish
            ? 'Desplázate hacia abajo para ver el desglose completo.'
            : 'Scroll down to see the full breakdown.',
      ));
    }

    return insights.take(maxCount).toList();
  }

  static Color colorFor(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.good:
        return const Color(0xFF34C759);
      case InsightSeverity.warning:
        return const Color(0xFFFFA500);
      case InsightSeverity.alert:
        return const Color(0xFFDC2626);
    }
  }

  static Color surfaceFor(InsightSeverity s) {
    switch (s) {
      case InsightSeverity.good:
        return const Color(0xFFECFDF5);
      case InsightSeverity.warning:
        return const Color(0xFFFFFBEB);
      case InsightSeverity.alert:
        return const Color(0xFFFEF2F2);
    }
  }
}
