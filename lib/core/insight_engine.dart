import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';
import '../l10n/strings_en.dart';
import '../l10n/strings_es.dart';

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
    final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
    final insights = <Insight>[];

    // 1. Cash Flow Health
    if (monthlyCashFlow >= 300) {
      insights.add(Insight(
        severity: InsightSeverity.good,
        title: s.solidCashFlowTitle,
        body: s.solidCashFlowBody(monthlyCashFlow.toStringAsFixed(0)),
      ));
    } else if (monthlyCashFlow >= 0) {
      insights.add(Insight(
        severity: InsightSeverity.warning,
        title: s.thinMarginTitle,
        body: s.thinMarginBody(monthlyCashFlow.toStringAsFixed(0)),
      ));
    } else {
      insights.add(Insight(
        severity: InsightSeverity.alert,
        title: s.negativeCashFlowInsightTitle,
        body: s.negativeCashFlowInsightBody((-monthlyCashFlow).toStringAsFixed(0)),
      ));
    }

    // 2. Expense Ratio
    if (expenseRatioPct <= 40) {
      insights.add(Insight(
        severity: InsightSeverity.good,
        title: s.expensesUnderControlTitle,
        body: s.expensesUnderControlBody(expenseRatioPct.toStringAsFixed(0)),
      ));
    } else if (expenseRatioPct <= 60) {
      insights.add(Insight(
        severity: InsightSeverity.warning,
        title: s.highExpenseRatioTitle,
        body: s.highExpenseRatioBody(expenseRatioPct.toStringAsFixed(0)),
      ));
    } else {
      insights.add(Insight(
        severity: InsightSeverity.alert,
        title: s.criticalExpenseRatioTitle,
        body: s.criticalExpenseRatioBody(expenseRatioPct.toStringAsFixed(0)),
      ));
    }

    // 3. Cap Rate (only when propertyValue provided)
    if (capRate != null) {
      if (capRate >= 6) {
        insights.add(Insight(
          severity: InsightSeverity.good,
          title: s.strongCapRateTitle,
          body: s.strongCapRateBody(capRate.toStringAsFixed(1)),
        ));
      } else if (capRate >= 3) {
        insights.add(Insight(
          severity: InsightSeverity.warning,
          title: s.moderateCapRateTitle,
          body: s.moderateCapRateBody(capRate.toStringAsFixed(1)),
        ));
      } else {
        insights.add(Insight(
          severity: InsightSeverity.alert,
          title: s.lowCapRateTitle,
          body: s.lowCapRateBody(capRate.toStringAsFixed(1)),
        ));
      }
    }

    // 4. Vacancy Loss
    if (monthlyRent > 0) {
      final vacancyPct = vacancyLoss / monthlyRent * 100;
      if (vacancyPct > 15) {
        insights.add(Insight(
          severity: InsightSeverity.alert,
          title: s.highVacancyCostTitle,
          body: s.highVacancyCostBody(
            vacancyPct.toStringAsFixed(0),
            vacancyLoss.toStringAsFixed(0),
          ),
        ));
      } else if (vacancyPct > 8) {
        insights.add(Insight(
          severity: InsightSeverity.warning,
          title: s.notableVacancyCostTitle,
          body: s.notableVacancyCostBody(
            vacancyLoss.toStringAsFixed(0),
            vacancyPct.toStringAsFixed(0),
          ),
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
        title: s.calculationCompleteTitle,
        body: s.calculationCompleteBody,
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
