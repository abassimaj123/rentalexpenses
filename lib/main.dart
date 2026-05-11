import 'dart:async';
import 'package:calcwise_core/calcwise_core.dart' hide CrashlyticsService, iapErrorNotifier;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/ads/ad_service.dart';
import 'core/firebase/analytics_service.dart';
import 'core/firebase/firebase_options.dart';
import 'core/freemium/freemium_service.dart';
import 'core/freemium/iap_service.dart';
import 'core/services/crashlytics_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/calculator_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/property_list_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/history_screen.dart';
import 'widgets/paywall_hard.dart';
import 'widgets/paywall_soft.dart';

final ValueNotifier<bool> isSpanishNotifier = ValueNotifier<bool>(false);

/// Centralized paywall session service
final paywallSession = PaywallSessionService(appKey: 'rentalexpenses');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AnalyticsService.instance.logAppOpen();
  await CrashlyticsService.init();

  final locales = PlatformDispatcher.instance.locales;
  final systemLang = locales.isNotEmpty ? locales.first.languageCode : 'en';
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('language');
  isSpanishNotifier.value = (savedLang ?? systemLang) == 'es';

  await themeModeService.initialize();
  await freemiumService.initialize();
  await IAPService.instance.initialize();
  await paywallSession.initialize();

  try {
    await _requestConsent();
    await MobileAds.instance.initialize();
    await AdService.instance.initialize();
  } catch (e) {
    debugPrint('AdMob init error: $e');
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0D0B1E),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const _IapErrorWrapper());
}

class _IapErrorWrapper extends StatefulWidget {
  const _IapErrorWrapper();

  @override
  State<_IapErrorWrapper> createState() => _IapErrorWrapperState();
}

class _IapErrorWrapperState extends State<_IapErrorWrapper> {
  @override
  void initState() {
    super.initState();
    iapErrorNotifier.addListener(_onIapError);
  }

  @override
  void dispose() {
    iapErrorNotifier.removeListener(_onIapError);
    super.dispose();
  }

  void _onIapError() {
    final msg = iapErrorNotifier.value;
    if (msg == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
      iapErrorNotifier.value = null;
    });
  }

  @override
  Widget build(BuildContext context) => const RentalExpensesApp();
}

class RentalExpensesApp extends StatelessWidget {
  const RentalExpensesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeService.notifier,
          builder: (context, themeMode, child) => MaterialApp(
            title: 'Rental Expenses Tracker',
            theme: AppTheme.theme,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            debugShowCheckedModeBanner: false,
            initialRoute: '/',
            routes: {
              '/': (_) => const SplashScreen(),
              '/home': (_) => const MainShell(),
            },
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    PropertyListScreen(),
    CalculatorScreen(),
    ReportsScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async => await paywallSession.recordSession());
  }

  Future<void> _onTabChanged(int i) async {
    setState(() => _index = i);
    // Paywall: record tab-switch as an action — triggers gate every N actions
    final trigger = await paywallSession.recordAction();
    if (trigger == PaywallTrigger.none || !mounted) return;
    if (trigger == PaywallTrigger.hard) {
      PaywallHard.show(context);
    } else {
      PaywallSoft.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    ));
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return Scaffold(
          body: IndexedStack(index: _index, children: _screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onTabChanged,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_work_outlined),
                selectedIcon: const Icon(Icons.home_work_rounded),
                label: isSpanish ? 'Propiedades' : 'Properties',
              ),
              NavigationDestination(
                icon: const Icon(Icons.calculate_outlined),
                selectedIcon: const Icon(Icons.calculate),
                label: isSpanish ? 'Calculadora' : 'Calculator',
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_outlined),
                selectedIcon: const Icon(Icons.bar_chart_rounded),
                label: isSpanish ? 'Reportes' : 'Reports',
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history_rounded),
                label: isSpanish ? 'Historial' : 'History',
              ),
            ],
          ),
        );
      },
    );
  }
}


/// Request GDPR/PIPEDA consent via Google UMP SDK.
/// Resolves on success, timeout, or error so the app always launches.
/// On non-EEA/UK devices the UMP SDK completes immediately without showing a form.
Future<void> _requestConsent() async {
  final completer = Completer<void>();
  ConsentInformation.instance.requestConsentInfoUpdate(
    ConsentRequestParameters(),
    () async {
      // Consent info updated — show form only if required
      if (await ConsentInformation.instance.isConsentFormAvailable()) {
        ConsentForm.loadAndShowConsentFormIfRequired(
          (_) { if (!completer.isCompleted) completer.complete(); },
        );
      } else {
        if (!completer.isCompleted) completer.complete();
      }
    },
    (_) { if (!completer.isCompleted) completer.complete(); },
  );
  return completer.future;
}
