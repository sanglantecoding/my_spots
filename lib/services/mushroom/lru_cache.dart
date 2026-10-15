import 'dart:collection';

/// Entrée horodatée pour le cache LRU.
class CacheEntry<V> {
  CacheEntry(this.value, this.timestamp);
  final V value;
  final DateTime timestamp;
}

/// Cache LRU borné avec TTL.
///
/// - `LinkedHashMap` préserve l'ordre d'insertion : la première clé est la
///   plus ancienne (candidate à l'éviction).
/// - `get` déplace l'entrée en fin de map (recent usage).
/// - `put` insère en fin de map et évince les plus anciennes si `maxSize`
///   est dépassé.
/// - Les entrées expirées sont supprimées à la lecture (pas de scan global).
class BoundedLruCache<K, V> {
  BoundedLruCache({required this.maxSize, required this.ttl})
    : assert(maxSize > 0);

  final int maxSize;
  final Duration ttl;
  final LinkedHashMap<K, CacheEntry<V>> _entries =
      LinkedHashMap<K, CacheEntry<V>>();

  V? get(K key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _entries.remove(key);
      return null;
    }
    _entries.remove(key);
    _entries[key] = entry;
    return entry.value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = CacheEntry(value, DateTime.now());
    while (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(K key) => _entries.remove(key);
  void clear() => _entries.clear();
  int get length => _entries.length;

  /// Injecte une entrée avec un timestamp arbitraire (tests d'expiration).
  void debugPutWithTimestamp(K key, V value, DateTime timestamp) {
    _entries.remove(key);
    _entries[key] = CacheEntry(value, timestamp);
    while (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
  }
}
