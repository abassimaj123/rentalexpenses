import 'dart:async';
import 'package:calcwise_core/calcwise_core.dart'
    hide CrashlyticsService, iapErrorNotifier, PaywallHard;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/ad_config.dart';
import 'core/firebase/analytics_service.dart';
import 'core/firebase/firebase_options.dart';
import 'core/freemium/freemium_service.dart';
import 'core/freemium/iap_service.dart';
import 'core/services/crashlytics_service.dart';
import 'core/theme/app_theme.dart';
import 'data/history_database_adapter.dart';
import 'screens/calculator_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/property_list_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tools_screen.dart';
import 'screens/history_screen.dart';
import 'services/rental_notification_service.dart';
import 'l10n/strings_en.dart';
import 'l10n/strings_es.dart';
import 'widgets/paywall_hard.dart';
import 'widgets/paywall_soft.dart';

final ValueNotifier<bool> isSpanishNotifier = ValueNotifier<bool>(false);

/// SmartHistory ring buffer + pinned scenarios service (SQLite — separate DB
/// from SharedPreferences used by the main calculator history).
final smartHistoryService = SmartHistoryService(
  db: HistoryDatabaseAdapter(),
  freemium: freemiumService,
);

/// Bumped to trigger a silent reload after a SmartHistory save.
final historyRefreshNotifier = ValueNotifier<int>(0);

/// Centralized paywall session service
final paywallSession = PaywallSessionService(
  appKey: 'rentalexpenses',
  hasFullAccess: () => freemiumService.hasFullAccess,
);

/// Global AdService (calcwise_core)
final adService = CalcwiseAdService(
  config: CalcwiseAdConfig(
    bannerAndroid: AdConfig.bannerAndroid,
    interstitialAndroid: AdConfig.interstitialAndroid,
    rewardedAndroid: AdConfig.rewardedAndroid,
    calcThreshold: AdConfig.calcThreshold,
    cooldownMinutes: AdConfig.cooldownMinutes,
  ),
  freemium: freemiumService,
  analytics: AnalyticsService.instance,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await initializeDateFormatting('en', null);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  unawaited(CalcwiseRemoteConfig.initialize());
  await CalcwiseTax.init(remoteFetcher: calcwiseTaxRemoteFetch);
  unawaited(AnalyticsService.instance.initialize());
  await AnalyticsService.instance.logAppOpen();
  await CrashlyticsService.init();

  final locales = PlatformDispatcher.instance.locales;
  final systemLang = locales.isNotEmpty ? locales.first.languageCode : 'en';
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('language');
  isSpanishNotifier.value = (savedLang ?? systemLang) == 'es';

  await themeModeService.initialize();
  await freemiumService.initialize();
  try {
    await RentalNotificationService.initialize();
    await RentalNotificationService.scheduleMonthlyReminder(isSpanishNotifier.value);
  } catch (e) {
    debugPrint('Notification init error: $e');
  }
  await IAPService.instance.initialize();
  await paywallSession.initialize();

  try {
    await requestCalcwiseConsent();
    await MobileAds.instance.initialize();
    if (kDebugMode) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: ['FD16D4616C3A21C3ACE5E48F8DC9C1DC']),
      );
    }
    if (AdConfig.adsEnabled) await adService.initialize();
  } catch (e) {
    debugPrint('AdMob init error: $e');
  }

  AnalyticsService.instance.setUserPremium(freemiumService.hasFullAccess);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // Initial style — will be overridden per-frame in MainShell based on theme brightness.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  CalcwiseAdFooter.configure(
    adService: adService,
    freemium: freemiumService,
    isSpanishNotifier: isSpanishNotifier,
    onGetPremium: () => IAPService.instance.buy(),
    analytics: AnalyticsService.instance,
  );
  CalcwiseRewardAdSheet.configure(
    adService: adService,
    freemium: freemiumService,
    isSpanishNotifier: isSpanishNotifier,
  );
  runApp(const _IapErrorWrapper());
}

class _IapErrorWrapper extends StatefulWidget {
  const _IapErrorWrapper();

  @override
  State<_IapErrorWrapper> createState() => _IapErrorWrapperState();
}

class _IapErrorWrapperState extends State<_IapErrorWrapper> {
  final _smKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    iapErrorNotifier.addListener(_onIapError);
    iapRestoreResultNotifier.addListener(_onRestoreResult);
  }

  @override
  void dispose() {
    iapErrorNotifier.removeListener(_onIapError);
    iapRestoreResultNotifier.removeListener(_onRestoreResult);
    super.dispose();
  }

  void _onIapError() {
    final msg = iapErrorNotifier.value;
    if (msg == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _smKey.currentState?.showSnackBar(SnackBar(content: Text(msg)));
      iapErrorNotifier.value = null;
    });
  }

  void _onRestoreResult() {
    final result = iapRestoreResultNotifier.value;
    if (result == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isEs = isSpanishNotifier.value;
      final msg = result == 'restored'
          ? (isEs ? '¡Premium restaurado!' : 'Premium restored!')
          : (isEs ? 'No hay compras para restaurar.' : 'No purchases to restore.');
      _smKey.currentState?.showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
      iapRestoreResultNotifier.value = null;
    });
  }

  @override
  Widget build(BuildContext context) => RentalExpensesApp(smKey: _smKey);
}

class RentalExpensesApp extends StatelessWidget {
  const RentalExpensesApp({super.key, required this.smKey});
  final GlobalKey<ScaffoldMessengerState> smKey;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeModeService.notifier,
          builder: (context, themeMode, child) => MaterialApp(
            scaffoldMessengerKey: smKey,
            title: 'Rental Expenses Tracker',
            theme: AppTheme.theme,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            debugShowCheckedModeBanner: false,
            navigatorObservers: [FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)],
            builder: (context, child) {
              if (!MediaQuery.of(context).disableAnimations) return child!;
              return Theme(
                data: Theme.of(context).copyWith(
                  pageTransitionsTheme: const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: _NoAnimPageTransitionsBuilder(),
                      TargetPlatform.iOS: _NoAnimPageTransitionsBuilder(),
                    },
                  ),
                ),
                child: child!,
              );
            },
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
  bool _wasPremium = false;

  static const _screens = [
    PropertyListScreen(),
    CalculatorScreen(),
    ReportsScreen(),
    ToolsScreen(),
    HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _wasPremium = freemiumService.hasFullAccess;
    freemiumService.isPremiumNotifier.addListener(_onPremiumChange);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) async => await paywallSession.recordSession());
  }

  @override
  void dispose() {
    freemiumService.isPremiumNotifier.removeListener(_onPremiumChange);
    super.dispose();
  }

  void _onPremiumChange() {
    final now = freemiumService.hasFullAccess;
    if (now && !_wasPremium && mounted) {
      showPremiumWelcomeSnackBar(context);
      try { AnalyticsService.instance.logPaywallConverted('iap'); } catch (_) {}
    }
    _wasPremium = now;
    unawaited(AnalyticsService.instance.setUserPremium(now));
  }

  Future<void> _onTabChanged(int i) async {
    setState(() => _index = i);
    // Paywall: record tab-switch as an action — triggers gate every N actions
    final trigger = await paywallSession.recordAction();
    if (trigger == PaywallTrigger.none || !mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
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
      systemNavigationBarColor:
          isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));
    return ValueListenableBuilder<bool>(
      valueListenable: isSpanishNotifier,
      builder: (_, isSpanish, __) {
        final s = isSpanish ? const AppStringsEs() : const AppStringsEn();
        return Scaffold(
          appBar: AppBar(
            flexibleSpace: Container(
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.home_work_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  s.appTitle,
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              CalcwiseAppBarActions(
                freemium: freemiumService,
                session: paywallSession,
                onSettings: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const SettingsScreen(),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: AppDuration.base,
                  ),
                ),
                onRewardAd: () => CalcwiseRewardAdSheet.show(context),
                onPremium: () => PaywallHard.show(context),
              ),
            ],
          ),
          body: Stack(
            fit: StackFit.expand,
            children: List.generate(
              _screens.length,
              (i) => IgnorePointer(
                ignoring: _index != i,
                child: CalcwiseTabReveal(
                    active: _index == i, child: _screens[i]),
              ),
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _onTabChanged,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_work_rounded),
                selectedIcon: const Icon(Icons.home_work_rounded),
                label: s.navProperties,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calculate_rounded),
                selectedIcon: const Icon(Icons.calculate),
                label: s.navCalculator,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bar_chart_rounded),
                selectedIcon: const Icon(Icons.bar_chart_rounded),
                label: s.navReports,
              ),
              NavigationDestination(
                icon: const Icon(Icons.build_rounded),
                selectedIcon: const Icon(Icons.build),
                label: s.navTools,
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_rounded),
                selectedIcon: const Icon(Icons.history_rounded),
                label: s.navHistory,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoAnimPageTransitionsBuilder extends PageTransitionsBuilder {
  const _NoAnimPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}
