import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class TerminalModal extends StatelessWidget {
  final Map<String, dynamic> terminalData;
  final Future<void> Function(double lat, double lng)? onGetDirections;

  const TerminalModal({
    super.key,
    required this.terminalData,
    this.onGetDirections,
  });

  @override
  Widget build(BuildContext context) {
    // ✅ Safely parse "picture" or "pictures" as List<String>
    final List<String> images = (terminalData['picture'] is List)
        ? List<String>.from(terminalData['picture'])
        : (terminalData['pictures'] is List)
        ? List<String>.from(terminalData['pictures'])
        : [];

    final double? latitude = _safeToDouble(terminalData['latitude']);
    final double? longitude = _safeToDouble(terminalData['longitude']);

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
              // 🖼️ Image carousel with tap-to-zoom
              if (images.isNotEmpty)
                SizedBox(
                  height: 180,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final base64Str = images[index];
                      Uint8List? bytes;

                      try {
                        if (base64Str.isNotEmpty) {
                          bytes = base64Decode(base64Str);
                        }
                      } catch (_) {
                        bytes = null;
                      }

                      if (bytes == null) {
                        return _buildFallbackImage();
                      }

                      // 🖱️ Tap to zoom
                      return GestureDetector(
                        onTap: () {
                          _showZoomableImage(context, bytes!);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            bytes,
                            width: 220,
                            height: 180,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildFallbackImage();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                _buildNoImagesPlaceholder(),

              const SizedBox(height: 20),
              const Divider(),

              // 🏷️ Terminal name
              Text(
                terminalData['name'] ?? 'Unnamed Terminal',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "Type: ${terminalData['type'] ?? 'N/A'}",
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 15),

              // 💰 Fare
              _infoRow(
                Icons.attach_money,
                "Fare:",
                "₱${terminalData['fareMetric'] ?? 'N/A'}",
                emphasize: true,
              ),

              const SizedBox(height: 10),

              // 🕒 Schedule
              _infoRow(
                Icons.schedule,
                "Schedule:",
                terminalData['timeSchedule'] ?? 'N/A',
                emphasize: true,
              ),

              const SizedBox(height: 10),

              // 📍 Landmark
              _infoRow(
                Icons.location_on,
                "Nearest Landmark:",
                terminalData['nearestLandmark'] ?? 'N/A',
              ),

              const SizedBox(height: 20),

              // 🧭 Directions button
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
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ),

              const SizedBox(height: 10),

              // ❌ Close button
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

  /// ✅ Helper for zoomable image view
  void _showZoomableImage(BuildContext context, Uint8List bytes) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 15,
              right: 15,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 220,
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: const Center(
        child: Icon(Icons.broken_image, color: Colors.grey, size: 40),
      ),
    );
  }

  Widget _buildNoImagesPlaceholder() {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(
        child: Text(
          'No images available',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String label,
      String? value, {
        bool emphasize = false,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black),
              children: [
                TextSpan(text: "$label "),
                TextSpan(
                  text: value ?? 'N/A',
                  style: TextStyle(
                    fontWeight:
                    emphasize ? FontWeight.bold : FontWeight.normal,
                    fontSize: emphasize ? 17 : 16,
                    color: emphasize
                        ? Colors.blue.shade900
                        : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
