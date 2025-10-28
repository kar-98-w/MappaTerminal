import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:app_settings/app_settings.dart';

import '../models/terminal.dart';
import 'add_edit_terminal_screen.dart';
import 'login_screen.dart';
import '../widgets/search_dialog.dart';
import '../widgets/terminal_modals.dart';
import '../services/graphhopper_service.dart';
import '../widgets/chatbot_ui.dart';
import '../services/chatbot_service.dart';

class MapScreen extends StatefulWidget {
  final bool isAdmin;

  const MapScreen({super.key, this.isAdmin = false});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MaplibreMapController? mapController;
  List<Terminal> terminals = [];
  Map<String, Symbol> terminalSymbols = {};
  bool _terminalMarkerImageLoaded = false;
  Line? _currentRouteLine;

  final String _terminalMarkerId = "red-marker";
  final graphHopper =
  GraphHopperService("23301fe9-e63f-41cc-a378-3000dbe92236");
  Key _maplibreMapKey = UniqueKey();

  // Vehicle filter
  String _selectedVehicle = "car";
  final List<String> _vehicleOptions = ["car", "bike", "foot"];

  // 🔑 Put your Generative AI API Key here once
  final String generativeAIKey = "AIzaSyDK8eLauZkKT8XF26oG4WX1sr7y96aQfNQ";

  @override
  void initState() {
    super.initState();
    _listenToTerminals();
  }

  void _listenToTerminals() {
    FirebaseFirestore.instance.collection('terminals').snapshots().listen(
          (snapshot) {
        terminals = snapshot.docs
            .map((doc) =>
            Terminal.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        if (mapController != null) _updateMarkers();
        setState(() {});
      },
    );
  }

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    mapController = controller;
    await _ensureMarkerImagesLoaded();
    _updateMarkers();

    mapController!.onSymbolTapped.add(_onSymbolTapped);
    _getCurrentLocationAndCenter();
  }

  Future<void> _ensureMarkerImagesLoaded() async {
    if (mapController == null || _terminalMarkerImageLoaded) return;

    try {
      final ByteData terminalData =
      await rootBundle.load("assets/red_marker.png");
      await mapController!
          .addImage(_terminalMarkerId, terminalData.buffer.asUint8List());
      _terminalMarkerImageLoaded = true;
    } catch (e) {
      debugPrint("⚠️ Failed to load terminal image: $e");
    }
  }

  Future<void> _updateMarkers() async {
    if (mapController == null) return;
    await _ensureMarkerImagesLoaded();

    Set<String> newIds = terminals.map((t) => t.id).toSet();
    Set<String> oldIds = terminalSymbols.keys.toSet();

    // Remove deleted terminals
    for (String id in oldIds) {
      if (!newIds.contains(id)) {
        await mapController!.removeSymbol(terminalSymbols[id]!);
        terminalSymbols.remove(id);
      }
    }

    // Add or update terminals
    for (var terminal in terminals) {
      if (terminal.position != null) {
        final options = SymbolOptions(
          geometry: terminal.position!,
          iconImage: _terminalMarkerId,
          iconSize: 1.2,
          textField: terminal.name?.isNotEmpty == true
              ? terminal.name
              : "Terminal",
          textSize: 14,
          textColor: "#000000",
          textOffset: const Offset(0, 1.3),
          textAnchor: "top",
        );

        if (terminalSymbols.containsKey(terminal.id)) {
          await mapController!
              .updateSymbol(terminalSymbols[terminal.id]!, options);
        } else {
          final newSymbol = await mapController!.addSymbol(options);
          terminalSymbols[terminal.id] = newSymbol;
        }
      }
    }
  }

  void _onSymbolTapped(Symbol symbol) async {
    final tappedTerminal = terminals.firstWhere(
          (t) => terminalSymbols[t.id]?.id == symbol.id,
      orElse: () => Terminal(id: "", name: "Unknown"),
    );

    if (tappedTerminal.id.isEmpty) return;

    await showDialog(
      context: context,
      builder: (_) => TerminalModal(
        terminalData: {
          "name": tappedTerminal.name,
          "type": tappedTerminal.type,
          "fareMetric": tappedTerminal.fareMetric,
          "timeSchedule": tappedTerminal.timeSchedule,
          "nearestLandmark": tappedTerminal.nearestLandmark,
          "latitude": tappedTerminal.latitude,
          "longitude": tappedTerminal.longitude,
          "pictures": tappedTerminal.imagesBase64 ?? [],
        },
        onGetDirections: (lat, lng) async {
          await _showRouteToTerminal(tappedTerminal, _selectedVehicle);
        },
      ),
    );
  }

  Future<void> _showRouteToTerminal(
      Terminal terminal, String vehicleType) async {
    try {
      final userPos =
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final start = LatLng(userPos.latitude, userPos.longitude);
      final end = LatLng(terminal.latitude!, terminal.longitude!);

      final routePoints = await graphHopper.getRoute(start, end, vehicleType);

      if (routePoints.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No route found.")));
        return;
      }

      if (_currentRouteLine != null) {
        await mapController?.removeLine(_currentRouteLine!);
      }

      _currentRouteLine = await mapController?.addLine(LineOptions(
        geometry: routePoints,
        lineColor: "#007AFF",
        lineWidth: 5.0,
      ));

      final latitudes = routePoints.map((p) => p.latitude);
      final longitudes = routePoints.map((p) => p.longitude);
      final bounds = LatLngBounds(
        southwest: LatLng(
            latitudes.reduce((a, b) => a < b ? a : b),
            longitudes.reduce((a, b) => a < b ? a : b)),
        northeast: LatLng(
            latitudes.reduce((a, b) => a > b ? a : b),
            longitudes.reduce((a, b) => a > b ? a : b)),
      );

      await mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, left: 50, right: 50, top: 100, bottom: 50));
    } catch (e) {
      debugPrint("❌ Error getting directions: $e");
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Could not get directions.")));
      }
    }
  }

  Future<void> _getCurrentLocationAndCenter() async {
    if (mapController == null) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Location services are disabled. Turn it on?"),
          action: SnackBarAction(
            label: "Settings",
            onPressed: () =>
                AppSettings.openAppSettings(type: AppSettingsType.location),
          ),
        ),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Location permission is required.")),
        );
        return;
      }
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16.0));
    } catch (e) {
      debugPrint("⚠️ Error getting location: $e");
    }
  }

  void _zoomIn() => mapController?.animateCamera(CameraUpdate.zoomIn());
  void _zoomOut() => mapController?.animateCamera(CameraUpdate.zoomOut());

  void _openSearch() {
    showDialog(
      context: context,
      builder: (_) =>
          SearchDialog(terminals: terminals, mapController: mapController),
    );
  }

  void _openChatbot() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 350,
          height: 500,
          child: ChatbotUI(
            chatbotService: ChatbotService(apiKey: generativeAIKey),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SF Pampanga Terminals'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVehicle,
              items: _vehicleOptions
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedVehicle = v!),
            ),
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
          if (widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.add_location_alt),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddEditTerminalScreen()),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          MaplibreMap(
            key: _maplibreMapKey,
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(15.0345, 120.6841),
              zoom: 13,
            ),
            styleString:
            "https://api.maptiler.com/maps/streets/style.json?key=5fqSudo2zTvmgImpw3Ld",
            myLocationEnabled: true,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                    heroTag: "zoomIn",
                    mini: true,
                    onPressed: _zoomIn,
                    child: const Icon(Icons.add)),
                const SizedBox(height: 10),
                FloatingActionButton(
                    heroTag: "zoomOut",
                    mini: true,
                    onPressed: _zoomOut,
                    child: const Icon(Icons.remove)),
                const SizedBox(height: 10),
                FloatingActionButton(
                    heroTag: "gps",
                    onPressed: _getCurrentLocationAndCenter,
                    child: const Icon(Icons.my_location)),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "chatbot",
                  onPressed: _openChatbot,
                  child: const Icon(Icons.chat),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
