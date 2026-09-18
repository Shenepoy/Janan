/// A BLE reading that must not be re-imported after the user deleted it.
class BleBlacklistEntry {
  /// Create a blacklist row.
  const BleBlacklistEntry({
    required this.kind,
    required this.key,
    required this.created,
  });

  /// `bp` or `weight`.
  final String kind;

  /// Dedup key for the blocked reading.
  final String key;

  /// When the user blocked this reading.
  final DateTime created;
}

/// Stored keys of BLE readings the user asked not to re-import.
abstract class BleBlacklistRepository {
  /// Remember a blocked reading.
  Future<void> add(String kind, String key);

  /// Forget a blocked reading (used by undo).
  Future<void> remove(String kind, String key);

  /// Keys stored for [kind].
  Future<Set<String>> getKeys(String kind);
}
