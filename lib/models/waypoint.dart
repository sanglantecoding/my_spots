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

    return Waypoint(
      name: json['name'] as String,
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
      createdAt: DateTime.parse(json['createdAt'] as String),
      colorHex: json['colorHex'] as String? ?? 'FFFFEB3B',
      category: parsedCategory,
      creationAccuracy: json['creationAccuracy'] as double?,
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
    if (waypointsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(waypointsJson);
        waypoints
          ..clear()
          ..addAll(decoded.map((json) => Waypoint.fromJson(json)));
      } catch (e) {
        waypoints.clear();
      }
    } else {
      waypoints.clear();
    }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = waypoints.map((wp) => wp.toJson()).toList();
    await prefs.setString(_key, jsonEncode(list));
  }
}
