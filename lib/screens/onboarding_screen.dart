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
            titleEs: 'Controla cada\ndólar de alquiler',
            subtitleEs: 'ROI, flujo de caja y deducciones fiscales — todo en un solo lugar.',
            pillsEs: ['ROI', 'Flujo de caja', 'Deducciones'],
          ),
          OnboardingPage(
            icon: Icons.assignment_rounded,
            title: 'Know Your\nTrue Returns',
            subtitle:
                'Cap rate, gross yield, net yield — see the full picture of your investment.',
            pills: ['Cap Rate', 'Gross Yield', 'Net Yield'],
            titleEs: 'Conoce tus\nrendimientos reales',
            subtitleEs:
                'Tasa de cap, rendimiento bruto, neto — ve el panorama completo de tu inversión.',
            pillsEs: ['Tasa de cap', 'Rend. bruto', 'Rend. neto'],
          ),
        ],
      );
}
