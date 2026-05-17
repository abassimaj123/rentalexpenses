import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:rental_expenses/screens/calculator_screen.dart';

void main() {
  group('Format — affichage', () {
    test('Formatage currency USD', () {
      final fmt = NumberFormat.currency(locale: 'en_US', symbol: r'$');
      expect(fmt.format(1800), r'$1,800.00');
    });

    test('Formatage pourcentage', () {
      final fmt = NumberFormat('#,##0.0');
      expect(fmt.format(12.5), '12.5');
    });
  });

  group('Widget — éléments UI de base', () {
    testWidgets('Card cash flow positif affiche montant', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('Monthly Cash Flow'),
                  Text(r'+ $350.00',
                      style: TextStyle(color: Colors.green, fontSize: 24)),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Monthly Cash Flow'), findsOneWidget);
      expect(find.text(r'+ $350.00'), findsOneWidget);
    });

    testWidgets('Champ loyer mensuel accepte valeur', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Monthly Rent'),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '2200');
      expect(find.text('2200'), findsOneWidget);
    });
  });

  group('Regression guard — ExpenseCalc', () {
    ExpenseCalc makeCalc({
      double rent = 2000,
      double mortgage = 1200,
      double tax = 250,
      double insurance = 100,
      double maintenance = 100,
      double other = 0,
    }) =>
        ExpenseCalc(
          propertyName: 'Test Property',
          rentIncome: rent,
          mortgage: mortgage,
          propertyTaxes: tax,
          insurance: insurance,
          hoaFees: 0,
          propertyMgmt: 0,
          maintenance: maintenance,
          vacancyLoss: 0,
          utilities: 0,
          landscaping: 0,
          otherExpenses: other,
          savedAt: DateTime(2025),
          propertyValue: 300000,
          cashInvested: 60000,
        );

    test('RG-1: total dépenses = somme de toutes les catégories', () {
      final c = makeCalc();
      expect(c.totalExpenses, closeTo(1200 + 250 + 100 + 100, 0.01));
    });

    test('RG-2: cash flow mensuel = loyer - dépenses', () {
      final c = makeCalc();
      expect(c.monthlyCashFlow, closeTo(2000 - c.totalExpenses, 0.01));
    });

    test('RG-3: cash flow annuel = mensuel × 12', () {
      final c = makeCalc();
      expect(c.annualCashFlow, closeTo(c.monthlyCashFlow * 12, 0.01));
    });

    test('RG-4: loyer breakeven = total dépenses', () {
      final c = makeCalc();
      expect(c.breakEvenRent, closeTo(c.totalExpenses, 0.01));
    });

    test('RG-5: expense ratio = dépenses / loyer × 100', () {
      final c = makeCalc();
      expect(c.expenseRatio, closeTo(c.totalExpenses / 2000 * 100, 0.01));
    });

    test('RG-6: cash flow positif quand loyer > dépenses', () {
      final c = makeCalc(rent: 3000, mortgage: 1200, tax: 200, insurance: 100, maintenance: 100);
      expect(c.monthlyCashFlow, greaterThan(0));
    });

    test('RG-7: cash flow négatif quand dépenses > loyer', () {
      final c = makeCalc(rent: 1000, mortgage: 1500);
      expect(c.monthlyCashFlow, lessThan(0));
    });
  });
}
