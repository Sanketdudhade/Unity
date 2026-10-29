/// Central application configuration and environment variables.
///
/// Can be loaded natively via:
/// `flutter run --dart-define-from-file=.env`
/// or accessed via [AppConstants].
class AppConstants {
  AppConstants._();

  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Unity Engineers Production Tracker',
  );

  static const String companyName = 'Unity Engineers';
  static const String companyAddress =
      'B-15/2/61, MIDC, Waluj, Aurangabad, M.H. India. 431136';

  // Firebase / Backend
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static const String firebaseApiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: '',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Emulators
  static const bool useFirebaseEmulator = bool.fromEnvironment(
    'USE_FIREBASE_EMULATOR',
    defaultValue: false,
  );

  static const String emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  static const int emulatorAuthPort = int.fromEnvironment(
    'EMULATOR_AUTH_PORT',
    defaultValue: 9099,
  );

  static const int emulatorFirestorePort = int.fromEnvironment(
    'EMULATOR_FIRESTORE_PORT',
    defaultValue: 8080,
  );

  static const int emulatorFunctionsPort = int.fromEnvironment(
    'EMULATOR_FUNCTIONS_PORT',
    defaultValue: 5001,
  );

  static const int emulatorStoragePort = int.fromEnvironment(
    'EMULATOR_STORAGE_PORT',
    defaultValue: 9199,
  );

  // Helper getters
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
}
