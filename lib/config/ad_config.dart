// AdMob — publisher ca-app-pub-5379540026739666
// Production unit IDs are injected at build time via:
//   flutter build appbundle --release --dart-define-from-file=admob.json
// When a prod ID is absent (blank), falls back to Google official TEST ads,
// so a release build never ships placeholder IDs.
import 'package:flutter/foundation.dart';

class AdConfig {
  AdConfig._();
  static const bool adsEnabled = true;
  static const int calcThreshold = 3;
  static const int cooldownMinutes = 5;

  // Google official TEST ad unit IDs (debug + release fallback)
  // Adaptive banner test unit — fixed 320x50 unit letterboxes when requested at an adaptive size.
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/9214589741';
  static const _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardedIOS = 'ca-app-pub-3940256099942544/1712485313';

  // Production IDs injected via --dart-define-from-file=admob.json
  static const _prodBannerAndroid =
      String.fromEnvironment('ADMOB_BANNER_ANDROID');
  static const _prodInterstitialAndroid =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ANDROID');
  static const _prodRewardedAndroid =
      String.fromEnvironment('ADMOB_REWARDED_ANDROID');
  static const _prodBannerIOS = String.fromEnvironment('ADMOB_BANNER_IOS');
  static const _prodInterstitialIOS =
      String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');
  static const _prodRewardedIOS = String.fromEnvironment('ADMOB_REWARDED_IOS');

  static String get bannerAndroid =>
      kReleaseMode && _prodBannerAndroid.isNotEmpty
          ? _prodBannerAndroid
          : _testBannerAndroid;
  static String get interstitialAndroid =>
      kReleaseMode && _prodInterstitialAndroid.isNotEmpty
          ? _prodInterstitialAndroid
          : _testInterstitialAndroid;
  static String get rewardedAndroid =>
      kReleaseMode && _prodRewardedAndroid.isNotEmpty
          ? _prodRewardedAndroid
          : _testRewardedAndroid;

  // ── iOS Ad Unit IDs (opt-in — only wired when activate_ios.sh runs) ──────
  static String get banneriOS => kReleaseMode && _prodBannerIOS.isNotEmpty
      ? _prodBannerIOS
      : _testBannerIOS;
  static String get interstitialiOS =>
      kReleaseMode && _prodInterstitialIOS.isNotEmpty
          ? _prodInterstitialIOS
          : _testInterstitialIOS;
  static String get rewardediOS => kReleaseMode && _prodRewardedIOS.isNotEmpty
      ? _prodRewardedIOS
      : _testRewardedIOS;
}
