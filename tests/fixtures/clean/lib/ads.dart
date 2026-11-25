Future<void> startAds() async {
  final params = ConsentRequestParameters();
  ConsentInformation.instance.requestConsentInfoUpdate(params, () async {
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    await MobileAds.instance.initialize();
  }, (_) {});
}
