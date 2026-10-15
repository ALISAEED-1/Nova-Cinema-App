/// Where the nova-pay backend lives.
///
/// The default suits a phone on USB with `adb reverse tcp:4000 tcp:4000`, which
/// makes the phone's localhost reach the computer. Override at build time:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000` (emulator) or
/// a LAN address for a phone on the same Wi-Fi.
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );
}
