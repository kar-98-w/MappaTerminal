import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    print(terminalData);
    // --- MODIFIED ---
    // Now checks for new AND old image field names for backward compatibility
    final List<String> images = (terminalData['imagesBase64'] is List)
        ? List<String>.from(terminalData['imagesBase64'])
        : (terminalData['picture'] is List) // Check for 'picture'
        ? List<String>.from(terminalData['picture'])
        : (terminalData['pictures'] is List) // Check for 'pictures'
        ? List<String>.from(terminalData['pictures'])
        : []; // Default to empty

    // --- NEW ---
    // Loads the new 'routes' array (this code is correct)
    final List<dynamic> routes = terminalData['routes'] as List<dynamic>? ?? [];

    final double? latitude = _safeToDouble(terminalData['latitude']);
    final double? longitude = _safeToDouble(terminalData['longitude']);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Scrollable content
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🖐 Grab handle
                      Center(
                        child: Container(
                          width: 45,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      // 🖼️ Image carousel
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            controller: PageController(viewportFraction: 0.9),
                            itemCount: images.length,
                            itemBuilder: (context, index) {
                              Uint8List? bytes;
                              try {
                                // Added padding to handle potential bad base64
                                String paddedImage =
                                images[index].length % 4 == 0
                                    ? images[index]
                                    : images[index] +
                                    '=' * (4 - images[index].length % 4);
                                bytes = base64Decode(paddedImage);
                              } catch (e) {
                                // --- MODIFIED --- Added logging for debugging
                                debugPrint('Error decoding base64 image: $e');
                                bytes = null;
                              }
                              return bytes == null
                                  ? _buildFallbackImage()
                                  : GestureDetector(
                                onTap: () =>
                                    _showZoomableImage(context, bytes!),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  child: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(15),
                                    child: Image.memory(
                                      bytes,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      else
                        _buildNoImagesPlaceholder(),

                      const SizedBox(height: 18),

                      // 🏷️ Terminal name
                      Text(
                        terminalData['name'] ?? 'Unnamed Terminal',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Type: ${terminalData['type'] ?? 'N/A'}",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: Colors.grey[700],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // --- NEW: Routes Section ---
                      Text(
                        "Routes from this Terminal",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (routes.isEmpty)
                        _buildNoRoutesPlaceholder()
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: routes.length,
                          itemBuilder: (context, index) {
                            final route = routes[index] as Map<String, dynamic>;
                            return _buildRouteCard(route);
                          },
                        ),
                      // --- END NEW ---

                      const SizedBox(height: 18),

                      // 📍 Nearest Landmark
                      _infoBlock(
                        context,
                        icon: Icons.location_on,
                        title: "Nearest Landmark",
                        value: terminalData['nearestLandmark'] ?? 'N/A',
                      ),

                      const SizedBox(height: 25),

                      // 🧭 Get Directions
                      if (latitude != null && longitude != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.directions),
                            label: const Text(
                              "Get Directions",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding:
                              const EdgeInsets.symmetric(vertical: 14.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),

              // ❌ Close button
              Positioned(
                right: 6,
                top: 6,
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.black54, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- (All helper widgets below are unchanged and correct) ---

  /// A clean card to display a single route
  Widget _buildRouteCard(Map<String, dynamic> route) {
    final String to = route['to']?.toString() ?? 'N/A';
    final String type = route['type']?.toString() ?? 'N/A';
    final String schedule = route['timeSchedule']?.toString() ?? 'N/A';
    final String fare = route['fare']?.toString() ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "To: $to",
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 8),
          _buildRouteInfoRow(Icons.directions_bus, "Vehicle", type),
          _buildRouteInfoRow(Icons.schedule, "Schedule", schedule),
          _buildRouteInfoRow(Icons.wallet, "Fare", fare.isEmpty ? 'N/A' : fare),
        ],
      ),
    );
  }

  /// A small helper for the route card to format info neatly
  Widget _buildRouteInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[700], size: 16),
          const SizedBox(width: 8),
          Text(
            "$title: ",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Placeholder for when 'routes' array is empty
  Widget _buildNoRoutesPlaceholder() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: Text(
        'No specific routes available for this terminal.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic),
      ),
    ),
  );

  // 🖼️ Zoomable image view (Unchanged)
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
              child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
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

  // ✅ Safe parsing (Unchanged)
  double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // 🖼️ Fallback image (Unchanged)
  Widget _buildFallbackImage() => Container(
    margin: const EdgeInsets.only(right: 8),
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(15),
    ),
    child: const Center(
      child: Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
    ),
  );

  // 📷 No image placeholder (Unchanged)
  Widget _buildNoImagesPlaceholder() => Container(
    height: 150,
    decoration: BoxDecoration(
      color: Colors.grey[200],
      borderRadius: BorderRadius.circular(15),
    ),
    child: const Center(
      child: Text(
        'No images available',
        style: TextStyle(color: Colors.black54),
      ),
    ),
  );

  // 🧩 Info Block (Unchanged)
  Widget _infoBlock(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String value,
        bool multiLine = false,
        Color? color,
      }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
        multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color ?? Colors.blueAccent, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}