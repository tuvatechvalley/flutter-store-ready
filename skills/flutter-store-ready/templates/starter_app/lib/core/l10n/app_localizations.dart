import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../errors/app_failure.dart';
import '../security/input_validators.dart';

/// Type-safe strings. Every language implements every getter, so a missing
/// translation is a compile error instead of a blank label in production.
///
/// To add a language: create a subclass, add it to [_byLanguage] and to
/// [supportedLocales]. (Switch to `flutter gen-l10n` + ARB files if you work
/// with translators; keep the same "fail at compile time" rule.)
abstract class AppLocalizations {
  const AppLocalizations();

  static const supportedLocales = [Locale('tr'), Locale('en')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const Map<String, AppLocalizations> _byLanguage = {
    'tr': AppLocalizationsTr(),
    'en': AppLocalizationsEn(),
  };

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations.delegate is not registered.');
    return value ?? const AppLocalizationsEn();
  }

  static AppLocalizations forLocale(Locale locale) =>
      _byLanguage[locale.languageCode] ?? const AppLocalizationsEn();

  String get appTitle;
  String get retry;
  String get cancel;
  String get confirm;
  String get close;

  // Navigation
  String get navItems;
  String get navSettings;

  // Auth
  String get loginTitle;
  String get loginSubtitle;
  String get emailLabel;
  String get passwordLabel;
  String get showPassword;
  String get hidePassword;
  String get signIn;
  String get signOut;
  String get signOutConfirm;
  String get invalidCredentials;
  String get deleteAccount;
  String get deleteAccountConfirm;
  String get deleteAccountDone;
  String tooManyAttempts(int seconds);
  String get demoHint;
  String get sessionExpired;

  // Items
  String get itemsTitle;
  String get itemsEmptyTitle;
  String get itemsEmptyMessage;
  String get itemDetailTitle;
  String get loadMoreFailed;
  String lastUpdated(String date);

  // Settings
  String get settingsTitle;
  String get theme;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get language;
  String get languageSystem;
  String get textSize;
  String get textSizeHint;
  String get textSizePreview;
  List<String> get textSizeOptions;
  String get about;
  String get privacyPolicy;
  String get linkOpenFailed;

  // States
  String get offlineBanner;
  String get notFoundTitle;
  String get notFoundMessage;
  String get goHome;
  String get somethingWentWrong;
  String get configErrorTitle;

  // Failures (never show raw exception text to users)
  String get failureNetwork;
  String get failureTimeout;
  String get failureSecurity;
  String get failureUnauthorized;
  String get failureForbidden;
  String get failureNotFound;
  String get failureValidation;
  String failureRateLimited(int? seconds);
  String get failureServer;
  String get failureData;
  String get failureUnexpected;

  // Validation
  String get validationRequired;
  String get validationEmail;
  String validationTooShort(int min);
  String validationTooLong(int max);
  String get validationWeakPassword;
  String get validationInvalidCharacters;

  String failureMessage(AppFailure failure) => switch (failure) {
    NetworkFailure() => failureNetwork,
    TimeoutFailure() => failureTimeout,
    SecurityFailure() => failureSecurity,
    UnauthorizedFailure() => failureUnauthorized,
    ForbiddenFailure() => failureForbidden,
    NotFoundFailure() => failureNotFound,
    ValidationFailure(:final serverMessage) =>
      serverMessage ?? failureValidation,
    RateLimitedFailure(:final retryAfter) => failureRateLimited(
      retryAfter?.inSeconds,
    ),
    ServerFailure() => failureServer,
    DataFormatFailure() => failureData,
    CancelledFailure() => failureUnexpected,
    UnexpectedFailure() => failureUnexpected,
  };

  String validationMessage(
    ValidationError error, {
    int min = InputValidators.minPasswordLength,
    int max = InputValidators.maxPasswordLength,
  }) => switch (error) {
    ValidationError.required => validationRequired,
    ValidationError.invalidEmail => validationEmail,
    ValidationError.tooShort => validationTooShort(min),
    ValidationError.tooLong => validationTooLong(max),
    ValidationError.weakPassword => validationWeakPassword,
    ValidationError.invalidCharacters => validationInvalidCharacters,
  };
}

final class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations._byLanguage.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations.forLocale(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

class AppLocalizationsTr extends AppLocalizations {
  const AppLocalizationsTr();

  @override
  String get appTitle => 'Starter';
  @override
  String get retry => 'Tekrar dene';
  @override
  String get cancel => 'Vazgeç';
  @override
  String get confirm => 'Onayla';
  @override
  String get close => 'Kapat';
  @override
  String get navItems => 'Kayıtlar';
  @override
  String get navSettings => 'Ayarlar';
  @override
  String get loginTitle => 'Hoş geldiniz';
  @override
  String get loginSubtitle => 'Devam etmek için giriş yapın.';
  @override
  String get emailLabel => 'E-posta';
  @override
  String get passwordLabel => 'Şifre';
  @override
  String get showPassword => 'Şifreyi göster';
  @override
  String get hidePassword => 'Şifreyi gizle';
  @override
  String get signIn => 'Giriş yap';
  @override
  String get signOut => 'Çıkış yap';
  @override
  String get signOutConfirm => 'Oturumu kapatmak istediğinize emin misiniz?';
  @override
  String get invalidCredentials => 'E-posta veya şifre hatalı.';
  @override
  String get deleteAccount => 'Hesabı sil';
  @override
  String get deleteAccountConfirm =>
      'Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz.';
  @override
  String get deleteAccountDone => 'Hesabınız silindi.';
  @override
  String tooManyAttempts(int seconds) =>
      'Çok fazla deneme. $seconds saniye sonra tekrar deneyin.';
  @override
  String get demoHint => 'Demo: demo@example.com / Demo1234';
  @override
  String get sessionExpired => 'Oturumunuzun süresi doldu. Tekrar giriş yapın.';
  @override
  String get itemsTitle => 'Kayıtlar';
  @override
  String get itemsEmptyTitle => 'Henüz kayıt yok';
  @override
  String get itemsEmptyMessage => 'Yeni kayıtlar burada görünecek.';
  @override
  String get itemDetailTitle => 'Detay';
  @override
  String get loadMoreFailed => 'Daha fazla kayıt yüklenemedi.';
  @override
  String lastUpdated(String date) => 'Son güncelleme: $date';
  @override
  String get settingsTitle => 'Ayarlar';
  @override
  String get theme => 'Tema';
  @override
  String get themeSystem => 'Sistem';
  @override
  String get themeLight => 'Açık';
  @override
  String get themeDark => 'Koyu';
  @override
  String get language => 'Dil';
  @override
  String get languageSystem => 'Sistem dili';
  @override
  String get textSize => 'Yazı boyutu';
  @override
  String get textSizeHint =>
      'Telefonunuzun yazı boyutu ayarına ek olarak uygulanır.';
  @override
  String get textSizePreview => 'Örnek metin: Kayıtlarınız burada görünür.';
  @override
  List<String> get textSizeOptions => const [
    'Normal',
    'Büyük',
    'Daha büyük',
    'En büyük',
  ];
  @override
  String get about => 'Hakkında';
  @override
  String get privacyPolicy => 'Gizlilik politikası';
  @override
  String get linkOpenFailed => 'Bağlantı açılamadı.';
  @override
  String get offlineBanner => 'İnternet bağlantısı yok';
  @override
  String get notFoundTitle => 'Sayfa bulunamadı';
  @override
  String get notFoundMessage =>
      'Aradığınız sayfa taşınmış veya silinmiş olabilir.';
  @override
  String get goHome => 'Ana sayfaya dön';
  @override
  String get somethingWentWrong => 'Bir şeyler ters gitti';
  @override
  String get configErrorTitle => 'Uygulama yapılandırması geçersiz';
  @override
  String get failureNetwork =>
      'Bağlantı kurulamadı. İnternetinizi kontrol edin.';
  @override
  String get failureTimeout => 'İstek zaman aşımına uğradı. Tekrar deneyin.';
  @override
  String get failureSecurity =>
      'Güvenli bağlantı doğrulanamadı. Halka açık Wi-Fi kullanıyorsanız ağı değiştirin.';
  @override
  String get failureUnauthorized => 'Oturumunuz sona erdi. Tekrar giriş yapın.';
  @override
  String get failureForbidden => 'Bu işlem için yetkiniz yok.';
  @override
  String get failureNotFound => 'Aradığınız içerik bulunamadı.';
  @override
  String get failureValidation => 'Gönderilen bilgiler geçersiz.';
  @override
  String failureRateLimited(int? seconds) => seconds == null
      ? 'Çok fazla istek gönderildi. Biraz bekleyin.'
      : 'Çok fazla istek gönderildi. $seconds saniye bekleyin.';
  @override
  String get failureServer =>
      'Sunucuda bir sorun oluştu. Birazdan tekrar deneyin.';
  @override
  String get failureData => 'Sunucudan beklenmeyen bir yanıt geldi.';
  @override
  String get failureUnexpected => 'Beklenmeyen bir hata oluştu.';
  @override
  String get validationRequired => 'Bu alan zorunludur.';
  @override
  String get validationEmail => 'Geçerli bir e-posta adresi girin.';
  @override
  String validationTooShort(int min) => 'En az $min karakter olmalı.';
  @override
  String validationTooLong(int max) => 'En fazla $max karakter olabilir.';
  @override
  String get validationWeakPassword =>
      'Şifre en az bir harf ve bir rakam içermeli.';
  @override
  String get validationInvalidCharacters => 'Geçersiz karakterler içeriyor.';
}

class AppLocalizationsEn extends AppLocalizations {
  const AppLocalizationsEn();

  @override
  String get appTitle => 'Starter';
  @override
  String get retry => 'Try again';
  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'Confirm';
  @override
  String get close => 'Close';
  @override
  String get navItems => 'Items';
  @override
  String get navSettings => 'Settings';
  @override
  String get loginTitle => 'Welcome';
  @override
  String get loginSubtitle => 'Sign in to continue.';
  @override
  String get emailLabel => 'Email';
  @override
  String get passwordLabel => 'Password';
  @override
  String get showPassword => 'Show password';
  @override
  String get hidePassword => 'Hide password';
  @override
  String get signIn => 'Sign in';
  @override
  String get signOut => 'Sign out';
  @override
  String get signOutConfirm => 'Are you sure you want to sign out?';
  @override
  String get invalidCredentials => 'Incorrect email or password.';
  @override
  String get deleteAccount => 'Delete account';
  @override
  String get deleteAccountConfirm =>
      'Your account and all of its data will be permanently deleted. This cannot be undone.';
  @override
  String get deleteAccountDone => 'Your account was deleted.';
  @override
  String tooManyAttempts(int seconds) =>
      'Too many attempts. Try again in $seconds seconds.';
  @override
  String get demoHint => 'Demo: demo@example.com / Demo1234';
  @override
  String get sessionExpired => 'Your session expired. Please sign in again.';
  @override
  String get itemsTitle => 'Items';
  @override
  String get itemsEmptyTitle => 'No items yet';
  @override
  String get itemsEmptyMessage => 'New items will show up here.';
  @override
  String get itemDetailTitle => 'Details';
  @override
  String get loadMoreFailed => 'Could not load more items.';
  @override
  String lastUpdated(String date) => 'Last updated: $date';
  @override
  String get settingsTitle => 'Settings';
  @override
  String get theme => 'Theme';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get language => 'Language';
  @override
  String get languageSystem => 'System language';
  @override
  String get textSize => 'Text size';
  @override
  String get textSizeHint =>
      'Applied on top of your phone\'s font size setting.';
  @override
  String get textSizePreview => 'Sample text: your items appear here.';
  @override
  List<String> get textSizeOptions => const [
    'Normal',
    'Large',
    'Larger',
    'Largest',
  ];
  @override
  String get about => 'About';
  @override
  String get privacyPolicy => 'Privacy policy';
  @override
  String get linkOpenFailed => 'Could not open the link.';
  @override
  String get offlineBanner => 'No internet connection';
  @override
  String get notFoundTitle => 'Page not found';
  @override
  String get notFoundMessage => 'The page may have been moved or deleted.';
  @override
  String get goHome => 'Go to home';
  @override
  String get somethingWentWrong => 'Something went wrong';
  @override
  String get configErrorTitle => 'Invalid app configuration';
  @override
  String get failureNetwork =>
      'Could not connect. Check your internet connection.';
  @override
  String get failureTimeout => 'The request timed out. Please try again.';
  @override
  String get failureSecurity =>
      'Secure connection could not be verified. If you are on public Wi-Fi, switch networks.';
  @override
  String get failureUnauthorized => 'Your session ended. Please sign in again.';
  @override
  String get failureForbidden => 'You do not have permission to do this.';
  @override
  String get failureNotFound => 'We could not find what you were looking for.';
  @override
  String get failureValidation => 'Some of the information is invalid.';
  @override
  String failureRateLimited(int? seconds) => seconds == null
      ? 'Too many requests. Please wait a moment.'
      : 'Too many requests. Please wait $seconds seconds.';
  @override
  String get failureServer => 'Server problem. Please try again shortly.';
  @override
  String get failureData => 'The server sent an unexpected response.';
  @override
  String get failureUnexpected => 'An unexpected error occurred.';
  @override
  String get validationRequired => 'This field is required.';
  @override
  String get validationEmail => 'Enter a valid email address.';
  @override
  String validationTooShort(int min) => 'Must be at least $min characters.';
  @override
  String validationTooLong(int max) => 'Must be at most $max characters.';
  @override
  String get validationWeakPassword =>
      'Password must contain at least one letter and one number.';
  @override
  String get validationInvalidCharacters => 'Contains invalid characters.';
}
