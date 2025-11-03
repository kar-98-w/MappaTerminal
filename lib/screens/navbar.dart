import 'package:flutter/material.dart';
import 'map_screen.dart';
import '../widgets/chatbot_ui.dart';
import '../services/chatbot_service.dart';
import '../models/terminal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';


class NavBar extends StatefulWidget {
  final bool isAdmin;
  const NavBar({super.key, this.isAdmin = false});


  @override
  State<NavBar> createState() => _NavBarState();
}


class _NavBarState extends State<NavBar> {
  int _currentIndex = 0;
  String _selectedMode = 'Car'; // Default transport mode
  late ChatbotService chatbotService;
  List<Map<String, String>> _chatHistory = [];
  List<Terminal> terminals = [];
  MaplibreMapController? mapController;


  @override
  void initState() {
    super.initState();


    // Initialize ChatbotService
    chatbotService = ChatbotService(
      apiKey: "AIzaSyDK8eLauZkKT8XF26oG4WX1sr7y96aQfNQ", // Replace with your API key
    );


    // Load terminals from Firebase
    _loadTerminals();


    // Fetch user location immediately (optional)
    _fetchUserLocation();
  }


  /// Load terminals from Firebase in real-time
  void _loadTerminals() {
    FirebaseFirestore.instance.collection('terminals').snapshots().listen((snapshot) {
      setState(() {
        terminals = snapshot.docs
            .map((doc) => Terminal.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
      });
    });
  }


  /// Fetch and store user location
  Future<void> _fetchUserLocation() async {
    try {
      Position? position = await _getUserLocation();
      chatbotService.setUserLocation(position);
    } catch (_) {
      // Ignore if location fails
    }
  }


  /// Get user's current GPS location
  Future<Position?> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;


      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }


      if (permission == LocationPermission.deniedForever) return null;


      return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }


  /// Change transport mode
  void _onModeSelected(String mode) {
    setState(() => _selectedMode = mode);
  }


  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      // Map screen
      MapScreen(
        key: ValueKey('map_${_selectedMode.toLowerCase()}'),
        isAdmin: widget.isAdmin,
        selectedMode: _selectedMode.toLowerCase(),
      ),


      // Chatbot UI
      ChatbotUI(
        chatbotService: chatbotService,
        initialMessages: _chatHistory,
        onMessagesUpdated: (msgs) => setState(() => _chatHistory = msgs),
      ),
    ];


    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Transport mode filter
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildModeButton('Car', Icons.directions_car),
                    _buildModeButton('Bike', Icons.directions_bike),
                    _buildModeButton('Foot', Icons.directions_walk),
                  ],
                ),
              ),


              // Bottom navigation bar
              BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) async {
                  setState(() => _currentIndex = index);


                  // If switching to Chatbot, fetch user location
                  if (index == 1) {
                    await _fetchUserLocation();
                  }
                },
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Colors.blueAccent,
                unselectedItemColor: Colors.grey,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.map),
                    label: 'Map',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_bubble_outline),
                    label: 'Chatbot',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// Transport mode button
  Widget _buildModeButton(String mode, IconData icon) {
    final bool isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _onModeSelected(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(width: 6),
            Text(
              mode,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

