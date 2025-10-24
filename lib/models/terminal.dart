import 'package:maplibre_gl/maplibre_gl.dart';

class Terminal {
  final String id;
  final String? name;
  final String? type;
  final String? category;
  final String? fareMetric;
  final String? timeSchedule;
  final String? nearestLandmark;
  final double? latitude;
  final double? longitude;
  final List<String>? imagesBase64;

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
  });

  factory Terminal.fromMap(String id, Map<String, dynamic> data) {
    return Terminal(
      id: id,
      name: data['name'],
      type: data['type'],
      category: data['category'],
      fareMetric: data['fareMetric'],
      timeSchedule: data['timeSchedule'],
      nearestLandmark: data['nearestLandmark'],
      latitude: (data['latitude'] is num) ? data['latitude'].toDouble() : null,
      longitude: (data['longitude'] is num) ? data['longitude'].toDouble() : null,
      imagesBase64: data['imagesBase64'] != null
          ? List<String>.from(data['imagesBase64'])
          : [],
    );
  }

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
    };
  }
}
