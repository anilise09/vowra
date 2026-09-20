import '../domain/user_profile.dart';

abstract interface class ProfileRepository {
  UserProfile? load();
  void save(UserProfile profile);
}

/// Prototype-only storage. It never writes identity data to disk or a service.
class MemoryProfileRepository implements ProfileRepository {
  UserProfile? _profile;

  @override
  UserProfile? load() => _profile;

  @override
  void save(UserProfile profile) => _profile = profile;
}
