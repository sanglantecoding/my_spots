import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum WaypointCategory { fishing, mushrooms, other }

/// Modèle représentant un point (waypoint) enregistré.
class Waypoint {
  final String name;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final String colorHex;
  final WaypointCategory category;
  final double? creationAccuracy; // Précision GPS lors de la création
  final String?
  gpsStatus; // Statut de précision ("Vert", "Jaune", "Orange", "Rouge", "Inconnu")

  Waypoint({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.colorHex = 'FFFFEB3B',
    this.category = WaypointCategory.other,
    this.creationAccuracy,
    this.gpsStatus,
  });

  Color get color => Color(int.parse(colorHex, radix: 16));

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'colorHex': colorHex,
      'category': category.name,
      'creationAccuracy': creationAccuracy,
      'gpsStatus': gpsStatus,
    };
  }

  factory Waypoint.fromJson(Map<String, dynamic> json) {
    final String? categoryStr = json['category'] as String?;
    final WaypointCategory parsedCategory = categoryStr != null
        ? WaypointCategory.values.firstWhere(
            (c) => c.name == categoryStr,
            orElse: () => WaypointCategory.fishing,
          )
        : WaypointCategory.fishing;

    DateTime createdAt;
    try {
      createdAt = DateTime.parse(json['createdAt']?.toString() ?? '');
    } catch (_) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    return Waypoint(
      name: json['name']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      colorHex: json['colorHex'] as String? ?? 'FFFFEB3B',
      category: parsedCategory,
      creationAccuracy: (json['creationAccuracy'] as num?)?.toDouble(),
      gpsStatus: json['gpsStatus'] as String? ?? 'Inconnu',
    );
  }
}

/// Stockage persistant des waypoints (SharedPreferences).
class WaypointStore {
  WaypointStore._();

  static final List<Waypoint> waypoints = [];

  static const String _key = 'waypoints';

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final waypointsJson = prefs.getString(_key);
    waypoints.clear();
    if (waypointsJson == null) {
      return;
    }

    try {
      final decoded = jsonDecode(waypointsJson);
      if (decoded is! List) {
        return;
      }
      for (final item in decoded) {
        try {
          if (item is Map) {
            waypoints.add(
              Waypoint.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        } catch (_) {
          // Ignore a single corrupted waypoint instead of dropping the store.
        }
      }
    } catch (_) {
      waypoints.clear();
    }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = waypoints.map((wp) => wp.toJson()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }
}
