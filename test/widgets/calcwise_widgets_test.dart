import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcwise_core/calcwise_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal host — no Firebase, no AdMob, no IAP.
Widget _host(Widget child) => MaterialApp(
      theme: ThemeData.light().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16A34A)),
        extensions: [CalcwiseTheme.light(primary: const Color(0xFF16A34A))],
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ResultTile', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(_host(
        const ResultTile(label: 'Net Operating Income', value: r'$18,600'),
      ));
      await tester.pump();
      expect(find.text('Net Operating Income'), findsOneWidget);
      expect(find.text(r'$18,600'), findsOneWidget);
    });

    testWidgets('highlighted tile renders without error', (tester) async {
      await tester.pumpWidget(_host(
        const ResultTile(
          label: 'Cash Flow',
          value: r'$820/mo',
          isHighlight: true,
        ),
      ));
      await tester.pump();
      expect(find.text('Cash Flow'), findsOneWidget);
      expect(find.text(r'$820/mo'), findsOneWidget);
    });

    testWidgets('renders rental expense breakdown tiles', (tester) async {
      await tester.pumpWidget(_host(
        const Column(
          children: [
            ResultTile(label: 'Gross Rent', value: r'$2,400/mo'),
            ResultTile(label: 'Vacancy (5%)', value: r'$120/mo'),
            ResultTile(label: 'Total Expenses', value: r'$1,460/mo'),
            ResultTile(label: 'Net Cash Flow', value: r'$820/mo'),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('Gross Rent'), findsOneWidget);
      expect(find.text('Vacancy (5%)'), findsOneWidget);
      expect(find.text('Total Expenses'), findsOneWidget);
      expect(find.text('Net Cash Flow'), findsOneWidget);
    });
  });

  group('CalcwiseHeroCard', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseHeroCard(
          label: 'Monthly Cash Flow',
          value: r'$820',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('MONTHLY CASH FLOW'), findsOneWidget);
      expect(find.text(r'$820'), findsOneWidget);
    });

    testWidgets('renders secondary text', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseHeroCard(
          label: 'Cap Rate',
          value: '6.2%',
          secondary: 'Net operating income / value',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Net operating income / value'), findsOneWidget);
    });

    testWidgets('renders stats row', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseHeroCard(
          label: 'Monthly Cash Flow',
          value: r'$820',
          stats: [
            (label: 'Cap Rate', value: '6.2%'),
            (label: 'Cash-on-Cash', value: '8.1%'),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('CAP RATE'), findsOneWidget);
      expect(find.text('CASH-ON-CASH'), findsOneWidget);
    });

    testWidgets('renders badge', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseHeroCard(
          label: 'Monthly Cash Flow',
          value: r'$820',
          badges: [CalcwiseHeroBadge(label: 'Positive')],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Positive'), findsOneWidget);
    });
  });

  group('SectionCard', () {
    testWidgets('renders operating expenses section', (tester) async {
      await tester.pumpWidget(_host(
        const SectionCard(
          title: 'Operating Expenses',
          children: [
            ResultTile(label: 'Property Tax', value: r'$350/mo'),
            ResultTile(label: 'Insurance', value: r'$120/mo'),
            ResultTile(label: 'Maintenance (10%)', value: r'$240/mo'),
            ResultTile(label: 'Management (8%)', value: r'$192/mo'),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('Operating Expenses'), findsOneWidget);
      expect(find.text('Property Tax'), findsOneWidget);
      expect(find.text('Insurance'), findsOneWidget);
      expect(find.text('Maintenance (10%)'), findsOneWidget);
      expect(find.text('Management (8%)'), findsOneWidget);
    });

    testWidgets('renders income section', (tester) async {
      await tester.pumpWidget(_host(
        const SectionCard(
          title: 'Income',
          children: [
            ResultTile(label: 'Monthly Rent', value: r'$2,400'),
            ResultTile(label: 'Other Income', value: r'$0'),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Monthly Rent'), findsOneWidget);
    });
  });

  group('CalcwiseEmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseEmptyState(
          icon: Icons.home_rounded,
          title: 'No properties added',
          body: 'Add a property to analyze its expenses.',
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.text('No properties added'), findsOneWidget);
      expect(find.text('Add a property to analyze its expenses.'),
          findsOneWidget);
    });

    testWidgets('action button fires callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_host(
        CalcwiseEmptyState(
          icon: Icons.add_home_rounded,
          title: 'No data',
          actionLabel: 'Add property',
          onAction: () => tapped = true,
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Add property'));
      expect(tapped, isTrue);
    });

    testWidgets('renders without action when not provided', (tester) async {
      await tester.pumpWidget(_host(
        const CalcwiseEmptyState(
          icon: Icons.home_rounded,
          title: 'No data',
        ),
      ));
      await tester.pump();
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });
}
