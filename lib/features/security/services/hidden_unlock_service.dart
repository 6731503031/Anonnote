/// Simple in-memory timestamp for when the hidden-notes PIN was last
/// verified. This is intentionally lightweight and not persisted to disk.
///
/// Other widgets and screens can consult [isStillUnlocked] to decide whether
/// to show previews or allow navigation.
class HiddenUnlockService {
  HiddenUnlockService._internal();

  static final HiddenUnlockService instance = HiddenUnlockService._internal();

  DateTime? _lastVerifiedAt;

  /// Mark the PIN as verified now.
  void markUnlockedNow() {
    _lastVerifiedAt = DateTime.now();
  }

  /// Returns true if the last verification was within [minutes] (default 5).
  bool isStillUnlocked({int minutes = 5}) {
    if (_lastVerifiedAt == null) return false;
    return DateTime.now().difference(_lastVerifiedAt!).inMinutes < minutes;
  }

  /// Clear the state (useful for sign-out or explicit lock).
  void clear() {
    _lastVerifiedAt = null;
  }
}
