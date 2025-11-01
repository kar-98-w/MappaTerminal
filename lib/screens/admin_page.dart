import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';

import 'navbar.dart';

import 'login_screen.dart';
import 'map_screen.dart';
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
            BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))
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

                  // get image thumbnail if exists
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
                      thumbnail = const Icon(Icons.image_not_supported, size: 40);
                    }
                  }

                  return ListTile(
                    leading: thumbnail ?? const Icon(Icons.location_on, size: 40),
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

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Page'),
        actions: [
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
