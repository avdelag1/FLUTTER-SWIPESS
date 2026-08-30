import 'package:flutter/material.dart';

/// Instagram-style map presence labels.
abstract final class MapPresenceStatus {
  static const options = <MapPresenceOption>[
    MapPresenceOption(key: 'work', label: 'Working', icon: Icons.laptop_mac_rounded),
    MapPresenceOption(key: 'chill', label: 'Chilling', icon: Icons.weekend_rounded),
    MapPresenceOption(key: 'eat', label: 'Eating', icon: Icons.restaurant_rounded),
    MapPresenceOption(key: 'travel', label: 'Traveling', icon: Icons.flight_takeoff_rounded),
    MapPresenceOption(key: 'party', label: 'Out', icon: Icons.nightlife_rounded),
    MapPresenceOption(key: 'fitness', label: 'Active', icon: Icons.fitness_center_rounded),
  ];

  static MapPresenceOption? resolve(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    for (final option in options) {
      if (option.key == key) return option;
    }
    return null;
  }
}

class MapPresenceOption {
  const MapPresenceOption({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}
