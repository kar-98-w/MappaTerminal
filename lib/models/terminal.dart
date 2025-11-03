import 'package:flutter/material.dart'; // Added for debugPrint
import 'package:maplibre_gl/maplibre_gl.dart';

class Terminal {
  final String id;
  final String? name;
  final String? type;
  final String? category;
  final String? fareMetric; // Kept for any old data
  final String? timeSchedule; // Kept for any old data
  final String? nearestLandmark;
  final double? latitude;
  final double? longitude;
  final List<String>? imagesBase64;

  // This will hold your array of route maps
  final List<dynamic>? routes;

  LatLng? get position =>
      (latitude != null && longitude != null) ? LatLng(latitude!, longitude!) : null;

  Terminal({
    required this.id,
    this.name,
    this.type,
    this.category,
    this.fareMetric,
    this.timeSchedule,
    this.nearestLandmark,
    this.latitude,
    this.longitude,
    this.imagesBase64,
    this.routes,
  });

  // --- 🔽 THIS IS THE UPDATED FUNCTION 🔽 ---
  factory Terminal.fromMap(String id, Map<String, dynamic> data) {
    debugPrint("--- Parsing Terminal ID: $id ---");

    try {
      // Print the types to see if they are correct
      debugPrint("   Name: ${data['name']}");
      debugPrint("   Latitude type: ${data['latitude'].runtimeType}, Value: ${data['latitude']}");
      debugPrint("   Longitude type: ${data['longitude'].runtimeType}, Value: ${data['longitude']}");

      // Made these checks safer in case the fields are missing
      debugPrint("   Routes type: ${data['routes']?.runtimeType}, Value: ${data['routes']}");
      debugPrint("   Images type: ${data['imagesBase64']?.runtimeType}");

      return Terminal(
        id: id,
        name: data['name'],
        type: data['type'],
        category: data['category'],
        fareMetric: data['fareMetric'],
        timeSchedule: data['timeSchedule'],
        nearestLandmark: data['nearestLandmark'],

        // This is the logic that's likely failing
        latitude: (data['latitude'] is num) ? data['latitude'].toDouble() : null,
        longitude: (data['longitude'] is num) ? data['longitude'].toDouble() : null,

        // Made this one safer
        imagesBase64: (data['imagesBase64'] as List<dynamic>?)
            ?.map((item) => item.toString())
            .toList() ?? [], // Use ?? [] in case it's null

        // This line can fail if 'routes' is null or not a List
        routes: data['routes'] as List<dynamic>? ?? [], // Use ?? []
      );
    } catch (e) {
      // This will catch any error (like a bad cast)
      debugPrint("❌❌❌ CRITICAL ERROR parsing terminal '$id': $e");
      debugPrint("   Problem data map: $data");

      // Return a bad terminal so the app doesn't crash
      // This terminal will have null coordinates and no pin
      return Terminal(id: id, name: "PARSE ERROR");
    }
  }
  // --- 🔼 END OF UPDATED FUNCTION 🔼 ---

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'category': category,
      'fareMetric': fareMetric,
      'timeSchedule': timeSchedule,
      'nearestLandmark': nearestLandmark,
      'latitude': latitude,
      'longitude': longitude,
      'imagesBase64': imagesBase64,
      'routes': routes,
    };
  }
}