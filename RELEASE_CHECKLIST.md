# Release Checklist — Rental Expenses Tracker & Calculator

## Pre-Release
- [ ] Replace all AdMob ad unit IDs in `lib/config/ad_config.dart` (search `XXXXXXXXXX`)
- [ ] Replace AdMob app ID in `AndroidManifest.xml` (currently test ID)
- [ ] Remove or guard `debugUnlockPremium()` in FreemiumService
- [ ] Verify IAP product ID matches Play Console setup
- [ ] Run full test suite: `flutter test`
- [ ] Build release AAB: `flutter build appbundle --release`
- [ ] Test on physical device (Android 8+)
- [ ] Test premium purchase flow (use test account)
- [ ] Test rewarded ad flow
- [ ] Test EN/ES language switch
- [ ] Verify splash screen on Android 12+ (API 31)
- [ ] Verify no cleartext HTTP traffic (network_security_config)

## Play Console
- [ ] Upload AAB to internal track
- [ ] Add store listing (en-US): `store/en-US/listing.txt`
- [ ] Add store listing (es-US): `store/es-US/listing.txt`
- [ ] Upload screenshots (phone + tablet)
- [ ] Set privacy policy URL (host `store/privacy/index.html`)
- [ ] Complete data safety form (no PII collected, analytics disclosed)
- [ ] Set content rating (Everyone)
- [ ] Verify CCPA compliance

## Post-Release
- [ ] Monitor Firebase Crashlytics for launch crashes
- [ ] Monitor AdMob dashboard for fill rate
- [ ] Monitor Play Console ratings and reviews
