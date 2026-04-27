import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../config/ad_config.dart';
import '../freemium/freemium_service.dart';
import '../firebase/analytics_service.dart';

class AdService {
  static final instance = AdService._();
  AdService._();

  InterstitialAd? _inter;
  RewardedAd? _rewarded;

  int _calcCount = 0;
  DateTime? _lastInterTime;

  static String get bannerId {
    try {
      return AdConfig.bannerAndroid;
    } catch (_) {
      return AdConfig.bannerAndroid;
    }
  }

  Future<void> initialize() async {
    if (!AdConfig.adsEnabled) return;
    _loadInter();
    _loadRewarded();
  }

  void _loadInter() {
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialAndroid,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (a) => _inter = a,
        onAdFailedToLoad: (_) => _inter = null,
      ),
    );
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdConfig.rewardedAndroid,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (a) => _rewarded = a,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  void onCalculation() {
    if (!AdConfig.adsEnabled) return;
    if (!freemiumService.showAds) return;
    _calcCount++;
    if (_calcCount < AdConfig.calcThreshold) return;
    if (_lastInterTime != null) {
      final elapsed = DateTime.now().difference(_lastInterTime!).inMinutes;
      if (elapsed < AdConfig.cooldownMinutes) return;
    }
    showInterstitial();
  }

  void showInterstitial() {
    if (_inter == null) return;
    _calcCount = 0;
    _lastInterTime = DateTime.now();
    _inter!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _inter = null;
        _loadInter();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _inter = null;
        _loadInter();
      },
    );
    _inter!.show();
  }

  bool get isRewardedReady =>
      _rewarded != null &&
      !freemiumService.isPremium &&
      !freemiumService.isRewarded;

  Future<bool> showRewarded() async {
    if (freemiumService.isPremium || freemiumService.isRewarded) return false;
    if (_rewarded == null) return false;
    bool earned = false;
    final completer = Completer<bool>();
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _rewarded = null;
        _loadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    _rewarded!.show(
      onUserEarnedReward: (_, __) {
        earned = true;
        AnalyticsService.instance.logRewardedAdWatched();
      },
    );
    return completer.future;
  }
}
