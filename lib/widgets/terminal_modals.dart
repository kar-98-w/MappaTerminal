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
    final List<String> images = (terminalData['picture'] is List)
        ? List<String>.from(terminalData['picture'])
        : (terminalData['pictures'] is List)
        ? List<String>.from(terminalData['pictures'])
        : [];

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
                                bytes = base64Decode(images[index]);
                              } catch (_) {}
                              return bytes == null
                                  ? _buildFallbackImage()
                                  : GestureDetector(
                                onTap: () =>
                                    _showZoomableImage(context, bytes!),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Image.memory(
                                    bytes,
                                    fit: BoxFit.cover,
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

                      // 💰 Fare (multi-line with ₱ + highlighted numbers)
                      _infoBlock(
                        context,
                        icon: null, // use ₱ instead
                        title: "Fare Details",
                        value: terminalData['fareMetric'] ?? 'N/A',
                        multiLine: true,
                        color: Colors.green.shade700,
                        highlightNumbers: true, // enable highlighting
                      ),

                      const SizedBox(height: 10),

                      // 🕒 Schedule
                      _infoBlock(
                        context,
                        icon: Icons.schedule,
                        title: "Schedule",
                        value: terminalData['timeSchedule'] ?? 'N/A',
                      ),

                      const SizedBox(height: 10),

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

  // 🖼️ Zoomable image view
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

  // ✅ Safe parsing
  double? _safeToDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // 🖼️ Fallback image
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

  // 📷 No image placeholder
  Widget _buildNoImagesPlaceholder() => Container(
    height: 150,
    decoration: BoxDecoration(
      color: Colors.grey[300],
      borderRadius: BorderRadius.circular(15),
    ),
    child: const Center(
      child: Text(
        'No images available',
        style: TextStyle(color: Colors.black54),
      ),
    ),
  );

  // 🧩 Info Block (supports ₱, icons, and number highlighting)
  Widget _infoBlock(
      BuildContext context, {
        IconData? icon,
        required String title,
        required String value,
        bool multiLine = false,
        Color? color,
        bool highlightNumbers = false, // new param
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
          (icon == null)
              ? Text(
            '₱',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.blueAccent,
            ),
          )
              : Icon(icon, color: color ?? Colors.blueAccent, size: 24),
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
                // RichText with number highlighting
                RichText(
                  text: TextSpan(
                    children: _buildHighlightedText(
                        value, highlightNumbers, color ?? Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Highlight numbers in fare text
  List<TextSpan> _buildHighlightedText(
      String text, bool highlightNumbers, Color highlightColor) {
    if (!highlightNumbers) {
      return [
        TextSpan(
          text: text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ];
    }

    final RegExp regex = RegExp(r'(\d+\.?\d*)'); // matches numbers
    final List<TextSpan> spans = [];
    int start = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: highlightColor,
        ),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ));
    }

    return spans;
  }
}
