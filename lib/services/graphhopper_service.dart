import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

class GraphHopperService {
  final String apiKey;

  GraphHopperService(this.apiKey);

  /// 🔹 Map vehicle type to GraphHopper profile
  String _getProfileForVehicle(String vehicle) {
    switch (vehicle.toLowerCase()) {
      case 'car':
        return 'car';
      case 'bike':
        return 'bike';
      case 'foot':
        return 'foot';
      default:
        return 'car';
    }
  }

  /// 🔹 Get route for given start/end points and vehicle type
  Future<List<LatLng>> getRoute(LatLng start, LatLng end, String vehicleType) async {
    final profile = _getProfileForVehicle(vehicleType);

    final url = Uri.parse('https://graphhopper.com/api/1/route?key=23301fe9-e63f-41cc-a378-3000dbe92236');

    final body = jsonEncode({
      "points": [
        [start.longitude, start.latitude],
        [end.longitude, end.latitude]
      ],
      "profile": profile, // ✅ use the selected vehicle
      "points_encoded": false,
    });

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['paths'] == null || data['paths'].isEmpty) {
        return [];
      }

      final List coords = data['paths'][0]['points']['coordinates'] as List<dynamic>;

      return coords
          .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
          .toList();
    } else {
      print('❌ Failed to get route: ${response.statusCode}');
      print(response.body);
      throw Exception('Failed to get route: ${response.body}');
    }
  }
}
