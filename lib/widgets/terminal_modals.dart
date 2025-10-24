import 'dart:convert';
import 'package:flutter/material.dart';

class TerminalInfoModal extends StatelessWidget {
  final Map<String, dynamic> terminalData;
  final Future<void> Function(double lat, double lng)? onGetDirections;

  const TerminalInfoModal({
    super.key,
    required this.terminalData,
    this.onGetDirections,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> images = (terminalData['imagesBase64'] != null)
        ? List<String>.from(terminalData['imagesBase64'])
        : [];

    final double? latitude = terminalData['latitude']?.toDouble();
    final double? longitude = terminalData['longitude']?.toDouble();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(15),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Terminal name
              Text(
                terminalData['name'] ?? 'Unnamed Terminal',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Type
              Row(
                children: [
                  const Icon(Icons.directions_bus, color: Colors.blueAccent),
                  const SizedBox(width: 6),
                  Text(
                    terminalData['type'] ?? 'Unknown Type',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Images section
              if (images.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            base64Decode(images[index]),
                            width: 200,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text('No images available'),
                  ),
                ),

              const SizedBox(height: 16),
              const Divider(),

              // Info rows
              _infoRow(Icons.attach_money, "Fare:", terminalData['fareMetric']),
              const SizedBox(height: 8),
              _infoRow(Icons.schedule, "Schedule:", terminalData['timeSchedule']),
              const SizedBox(height: 8),
              _infoRow(Icons.location_on, "Nearest Landmark:", terminalData['nearestLandmark']),
              const SizedBox(height: 8),
              _infoRow(
                Icons.map,
                "Coordinates:",
                "${terminalData['latitude'] ?? 'N/A'}, ${terminalData['longitude'] ?? 'N/A'}",
              ),

              const SizedBox(height: 20),

              // 🧭 Get Directions Button (only if coordinates exist)
              if (latitude != null && longitude != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.directions, color: Colors.white),
                    label: const Text("Get Directions"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      if (onGetDirections != null) {
                        await onGetDirections!(latitude, longitude);
                        Navigator.pop(context); // close modal after drawing route
                      }
                    },
                  ),
                ),

              const SizedBox(height: 10),

              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text("Close"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "$label ${value ?? 'N/A'}",
            style: const TextStyle(fontSize: 15),
          ),
        ),
      ],
    );
  }
}
