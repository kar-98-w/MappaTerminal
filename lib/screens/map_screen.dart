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
import '../widgets/terminal_modals.dart'; // ✅ RESTORED: Import your modal widget




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




  final String _terminalMarkerId = "red-marker";




  // 1. Add a key for the MaplibreMap
  Key _maplibreMapKey = UniqueKey();




  @override
  void initState() {
    super.initState();
    _listenToTerminals();
  }




  void _listenToTerminals() {
    FirebaseFirestore.instance.collection('terminals').snapshots().listen((snapshot) {
      terminals = snapshot.docs
          .map((doc) => Terminal.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();




      if (mapController != null) {
        _updateMarkers();
      }
      setState(() {});
    });
  }




  Future<void> _onMapCreated(MaplibreMapController controller) async {
    mapController = controller;
    await _ensureMarkerImagesLoaded();
    _updateMarkers();


    // ✅ RESTORED: Attach the symbol tap listener
    mapController!.onSymbolTapped.add(_onSymbolTapped);




    // Center map on current location
    _getCurrentLocationAndCenter();
  }




  Future<void> _ensureMarkerImagesLoaded() async {
    if (mapController == null || _terminalMarkerImageLoaded) return;




    try {
      final ByteData terminalData = await rootBundle.load("assets/red_marker.png");
      await mapController!.addImage(_terminalMarkerId, terminalData.buffer.asUint8List());
      _terminalMarkerImageLoaded = true;
    } catch (e) {
      debugPrint("⚠️ Failed to load terminal image: $e");
    }
  }




  Future<void> _updateMarkers() async {
    if (mapController == null) return;
    await _ensureMarkerImagesLoaded();




    Set<String> newTerminalIds = terminals.map((t) => t.id).toSet();
    Set<String> oldTerminalIds = terminalSymbols.keys.toSet();




    for (String id in oldTerminalIds) {
      if (!newTerminalIds.contains(id)) {
        await mapController!.removeSymbol(terminalSymbols[id]!);
        terminalSymbols.remove(id);
      }
    }




    for (var terminal in terminals) {
      if (terminal.position != null) {
        SymbolOptions options = SymbolOptions(
          geometry: terminal.position!,
          iconImage: _terminalMarkerId,
          iconSize: 1.2,
          // ✅ FIX: Use null-safe check to prevent "property 'isNotEmpty' can't be unconditionally accessed"
          textField: terminal.name?.isNotEmpty == true ? terminal.name : "Terminal",
          textSize: 14,
          textColor: "#000000",
          textOffset: const Offset(0, 1.3),
          textAnchor: "top",
        );




        if (terminalSymbols.containsKey(terminal.id)) {
          await mapController!.updateSymbol(terminalSymbols[terminal.id]!, options);
        } else {
          Symbol newSymbol = await mapController!.addSymbol(options);
          terminalSymbols[terminal.id] = newSymbol;
        }
      }
    }
  }


  // ✅ RESTORED: Function to handle symbol taps and display the modal
  void _onSymbolTapped(Symbol symbol) {
    final tappedTerminal = terminals.firstWhere(
          (t) => terminalSymbols[t.id]?.id == symbol.id,
      orElse: () => Terminal(id: "", name: "Unknown"),
    );


    if (tappedTerminal.id.isNotEmpty) {
      showDialog(
        context: context,
        builder: (_) => TerminalInfoModal(
          terminalData: {
            "name": tappedTerminal.name,
            "type": tappedTerminal.type,
            "fareMetric": tappedTerminal.fareMetric,
            "timeSchedule": tappedTerminal.timeSchedule,
            "nearestLandmark": tappedTerminal.nearestLandmark,
            "latitude": tappedTerminal.latitude,
            "longitude": tappedTerminal.longitude,
            "imagesBase64": tappedTerminal.imagesBase64 ?? [],
          },
        ),
      );
    }
  }




  Future<void> _getCurrentLocationAndCenter() async {
    if (mapController == null) return;




    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Location services are disabled. Turn it on?"),
            action: SnackBarAction(
              label: "Settings",
              onPressed: () => AppSettings.openAppSettings(type: AppSettingsType.location),
            ),
          ),
        );
      }
      return;
    }




    // Capture the permission status BEFORE checking/requesting
    LocationPermission initialPermission = await Geolocator.checkPermission();




    LocationPermission permission = initialPermission;
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission is required.")),
          );
        }
        return;
      }
    }




    // Check if permission was just granted
    bool permissionWasJustGranted = (initialPermission == LocationPermission.denied &&
        (permission == LocationPermission.whileInUse || permission == LocationPermission.always));




    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng currentLatLng = LatLng(position.latitude, position.longitude);




      // Move camera to current location
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(currentLatLng, 16.0),
      );




      // 2. If permission was just granted, change the key to force a map rebuild.
      if (permissionWasJustGranted) {
        debugPrint("Location permission just granted, forcing map rebuild.");
        // Invalidate the key to force the MaplibreMap to tear down and rebuild
        // which often resolves the issue of myLocationEnabled not appearing.
        _maplibreMapKey = UniqueKey();
      }




      // Refresh map so blue dot shows (and rebuilds if key changed)
      setState(() {});
    } catch (e) {
      debugPrint("⚠️ Error getting or centering location: $e");
      if (mounted && (permission == LocationPermission.whileInUse || permission == LocationPermission.always)) {
        // Show a generic error if permission is there but location failed to retrieve
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not retrieve current location.")),
        );
      }
    }
  }




  void _zoomIn() => mapController?.animateCamera(CameraUpdate.zoomIn());
  void _zoomOut() => mapController?.animateCamera(CameraUpdate.zoomOut());




  void _openSearch() {
    showDialog(
      context: context,
      builder: (_) => SearchDialog(terminals: terminals, mapController: mapController),
    );
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SF Pampanga Terminals'),
        actions: [
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
            // 3. Apply the key here to control when the map is rebuilt
            key: _maplibreMapKey,
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(15.0345, 120.6841),
              zoom: 13,
            ),
            styleString: "https://api.maptiler.com/maps/streets/style.json?key=5fqSudo2zTvmgImpw3Ld",
            myLocationEnabled: true, // ✅ shows the blue dot
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  heroTag: "zoomInButton",
                  mini: true,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "zoomOutButton",
                  mini: true,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 10),
                FloatingActionButton(
                  heroTag: "gpsButton",
                  onPressed: _getCurrentLocationAndCenter,
                  child: const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

