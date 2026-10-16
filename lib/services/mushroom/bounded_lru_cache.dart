import 'dart:collection';

/// Cache LRU borné qui supprime automatiquement les entrées les plus anciennes
/// lorsque la capacité maximale est atteinte.
class BoundedLruCache<K, V> {
  BoundedLruCache(this.maxCapacity) : _cache = LinkedHashMap();

  final int maxCapacity;
  final LinkedHashMap<K, V> _cache;

  /// Retourne la valeur associée à [key], ou null si absente.
  V? operator [](K key) => _cache[key];

  /// Ajoute ou met à jour [key] avec [value].
  /// Si la capacité est dépassée, supprime l'entrée la plus ancienne.
  void operator []=(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxCapacity) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// Supprime [key] du cache.
  void remove(K key) => _cache.remove(key);

  /// Vide le cache.
  void clear() => _cache.clear();

  /// Nombre d'entrées dans le cache.
  int get length => _cache.length;

  /// Vérifie si [key] est présente.
  bool containsKey(K key) => _cache.containsKey(key);

  /// Retourne toutes les clés.
  Iterable<K> get keys => _cache.keys;

  /// Retourne toutes les valeurs.
  Iterable<V> get values => _cache.values;
}
