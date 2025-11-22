import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/terminal.dart';
import '../widgets/search_dialog.dart';
import '../widgets/terminal_modals.dart';
import 'navbar.dart';
import 'login_screen.dart';
import 'add_edit_terminal_screen.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  MaplibreMapController? mapController;
  bool _markerImageLoaded = false;

  // ---------------- Logout ----------------
  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Do you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No", style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes", style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const NavBar(isAdmin: false)),
            (route) => false,
      );
    }
  }

  // ---------------- Marker Setup ----------------
  Future<void> _ensureMarkerImageLoaded() async {
    if (mapController == null || _markerImageLoaded) return;
    try {
      final ByteData bytes = await rootBundle.load('assets/red_marker.png');
      final Uint8List list = bytes.buffer.asUint8List();
      await mapController!.addImage('red-marker', list);
      _markerImageLoaded = true;
    } catch (e) {
      debugPrint('⚠️ Failed to load marker: $e');
    }
  }

  Future<void> _updateMarkers(List<QueryDocumentSnapshot> docs) async {
    if (mapController == null) return;
    await _ensureMarkerImageLoaded();
    await mapController!.clearSymbols();

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lon = (data['longitude'] as num?)?.toDouble();
      final name = data['name']?.toString() ?? 'Terminal';

      if (lat != null && lon != null) {
        await mapController!.addSymbol(
          SymbolOptions(
            geometry: LatLng(lat, lon),
            iconImage: _markerImageLoaded ? 'red-marker' : 'marker-15',
            iconSize: 1.2,
            textField: name,
            textSize: 14,
            textColor: '#000000',
            textOffset: const Offset(0, 1.3),
            textAnchor: 'top',
          ),
          {'docId': doc.id, 'data': data},
        );
      }
    }
  }

  // ---------------- Terminal List ----------------
  Widget _buildTerminalList(List<QueryDocumentSnapshot> terminals) {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.12,
      maxChildSize: 0.8,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, -2),
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: terminals.length,
                itemBuilder: (context, i) {
                  final doc = terminals[i];
                  final data = doc.data() as Map<String, dynamic>;

                  final images = data['imagesBase64'] ?? [];
                  Widget? thumbnail;
                  if (images is List && images.isNotEmpty) {
                    try {
                      thumbnail = Image.memory(
                        Uint8List.fromList(
                          const Base64Decoder().convert(images.first),
                        ),
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      );
                    } catch (_) {
                      thumbnail =
                      const Icon(Icons.image_not_supported, size: 40);
                    }
                  }

                  return ListTile(
                    leading:
                    thumbnail ?? const Icon(Icons.location_on, size: 40),
                    title: Text(data['name'] ?? 'Unnamed Terminal'),
                    subtitle: Text('Type: ${data['type'] ?? 'N/A'}'),
                    trailing: const Icon(Icons.edit),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditTerminalScreen(
                            existingData: data,
                            terminalId: doc.id,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Feedback Functions ----------------
  Future<void> _markAsResolved(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('user_feedback')
          .doc(docId)
          .update({'status': 'resolved'});
    } catch (e) {
      debugPrint("Error marking as resolved: $e");
    }
  }

  void _showFeedbackPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_feedback')
                  .where('status', isEqualTo: 'new')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: const Text(
                      'No new feedback.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                final feedbackDocs = snapshot.data!.docs;

                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'New User Feedback',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: feedbackDocs.length,
                        itemBuilder: (context, index) {
                          final doc = feedbackDocs[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};

                          final message =
                              data['feedback_message'] ?? 'No message content';
                          final location = data['user_location'] ?? 'N/A';
                          final timestamp =
                          (data['timestamp'] as Timestamp?)?.toDate();
                          final formattedTime = timestamp != null
                              ? DateFormat('MMM d, h:mm a').format(timestamp)
                              : 'No timestamp';

                          return ListTile(
                            leading: const Icon(Icons.message_outlined,
                                color: Colors.blueAccent),
                            title: Text(
                              message,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(formattedTime),
                            trailing: const Icon(Icons.chevron_right,
                                color: Colors.grey),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('Feedback Details'),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Message:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(message),
                                        const SizedBox(height: 12),
                                        const Text(
                                          "Time:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(formattedTime),
                                        const SizedBox(height: 12),
                                        const Text(
                                          "User Location (Approx.):",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(location),
                                        const SizedBox(height: 12),
                                        const Text(
                                          "Status:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text(data['status'] ?? 'N/A'),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text('Close'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        _markAsResolved(doc.id);
                                        Navigator.pop(dialogContext);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Mark as Resolved'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFeedbackNotificationButton() {
    final feedbackStream = FirebaseFirestore.instance
        .collection('user_feedback')
        .where('status', isEqualTo: 'new')
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: feedbackStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.hasError) {
          return IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'View feedback',
            onPressed: _showFeedbackPanel,
          );
        }

        final feedbackCount = snapshot.data!.docs.length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                feedbackCount > 0
                    ? Icons.notifications_active
                    : Icons.notifications_none,
                color: feedbackCount > 0 ? Colors.amberAccent : null,
              ),
              tooltip: feedbackCount > 0
                  ? '$feedbackCount new feedback messages'
                  : 'No new feedback',
              onPressed: _showFeedbackPanel,
            ),
            if (feedbackCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    '$feedbackCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page'),
        actions: [
          _buildFeedbackNotificationButton(),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () async {
              final snapshot = await FirebaseFirestore.instance
                  .collection('terminals')
                  .get();
              final terminalList = snapshot.docs.map((doc) {
                final data = doc.data();
                return Terminal(
                  id: doc.id,
                  name: data['name'],
                  type: data['type'],
                  category: data['category'],
                  latitude: (data['latitude'] as num?)?.toDouble(),
                  longitude: (data['longitude'] as num?)?.toDouble(),
                  fareMetric: data['fareMetric'],
                  timeSchedule: data['timeSchedule'],
                  nearestLandmark: data['nearestLandmark'],
                  imagesBase64: (data['imagesBase64'] as List?)?.cast<String>(),
                );
              }).toList();

              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (_) => SearchDialog(
                    terminals: terminalList,
                    mapController: mapController,
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditTerminalScreen()),
          );
        },
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('terminals').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No terminals found'));
          }

          final docs = snapshot.data!.docs;

          // Update map markers
          if (mapController != null) _updateMarkers(docs);

          return Stack(
            children: [
              MaplibreMap(
                styleString:
                'https://api.maptiler.com/maps/streets/style.json?key=5fqSudo2zTvmgImpw3Ld',
                initialCameraPosition: const CameraPosition(
                  target: LatLng(15.033, 120.684),
                  zoom: 13,
                ),
                onMapCreated: (controller) {
                  mapController = controller;
                  _markerImageLoaded = false;
                  _updateMarkers(docs);

                  mapController!.onSymbolTapped.add((symbol) {
                    final meta = symbol.data;
                    if (meta != null && meta['docId'] != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddEditTerminalScreen(
                            existingData:
                            Map<String, dynamic>.from(meta['data'] ?? {}),
                            terminalId: meta['docId'],
                          ),
                        ),
                      );
                    }
                  });
                },
              ),
              _buildTerminalList(docs),
            ],
          );
        },
      ),
    );
  }
}
