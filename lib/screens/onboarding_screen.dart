import 'package:flutter/material.dart';
import 'package:calcwise_core/calcwise_core.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) => CalcwiseOnboarding(
        appKey: 'rentalexpenses',
        onDone: () => Navigator.of(context).pushReplacementNamed('/home'),
        pages: const [
          OnboardingPage(
            icon: Icons.holiday_village_rounded,
            title: 'Track Every\nRental Dollar',
            subtitle: 'ROI, cash flow, and tax deductions — all in one place.',
            pills: ['ROI', 'Cash Flow', 'Tax Deductions'],
          ),
          OnboardingPage(
            icon: Icons.assignment_rounded,
            title: 'Know Your\nTrue Returns',
            subtitle:
                'Cap rate, gross yield, net yield — see the full picture of your investment.',
            pills: ['Cap Rate', 'Gross Yield', 'Net Yield'],
          ),
          OnboardingPage(
            icon: Icons.history_rounded,
            title: 'Track Every\nProperty Over Time',
            subtitle:
                'Save your calculations and build a history of your rental portfolio.',
            pills: ['History', 'PDF Export', 'Multi-Property'],
            titleEs: 'Sigue cada\npropiedad con el tiempo',
            subtitleEs:
                'Guarda tus cálculos y construye un historial de tu cartera de alquileres.',
            pillsEs: ['Historial', 'Exportar PDF', 'Multi-Propiedad'],
          ),
        ],
      );
}
