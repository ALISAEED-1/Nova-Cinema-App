import '../core/constants/app_constants.dart';
import 'local_store.dart';

/// Tracks whether the onboarding carousel has already been shown.
///
/// Device-scoped rather than per-user: onboarding runs before sign-in.
class OnboardingService {
  const OnboardingService(this._store);

  final LocalStore _store;

  bool hasSeen() => _store.readBool(StorageKeys.onboardingSeen);

  Future<void> markSeen() =>
      _store.writeBool(StorageKeys.onboardingSeen, true);
}
