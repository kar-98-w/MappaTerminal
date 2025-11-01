import 'package:flutter/material.dart';
import 'map_screen.dart';
import '../widgets/chatbot_ui.dart';
import '../services/chatbot_service.dart';
import '../models/terminal.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class NavBar extends StatefulWidget {
  final bool isAdmin;
  const NavBar({super.key, this.isAdmin = false});

  @override
  State<NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<NavBar> {
  int _currentIndex = 0;
  String _selectedMode = 'Car'; // 🚗 Default mode
  late ChatbotService chatbotService;
  List<Map<String, String>> _chatHistory = [];
  List<Terminal> terminals = [];
  MaplibreMapController? mapController;

  @override
  void initState() {
    super.initState();
    chatbotService = ChatbotService(
      apiKey: "AIzaSyDK8eLauZkKT8XF26oG4WX1sr7y96aQfNQ",
    );
    _loadTerminals();
  }

  void _loadTerminals() {
    FirebaseFirestore.instance.collection('terminals').snapshots().listen((snapshot) {
      setState(() {
        terminals = snapshot.docs
            .map((doc) => Terminal.fromMap(doc.id, doc.data() as Map<String, dynamic>))
            .toList();
      });
    });
  }

  void _onModeSelected(String mode) {
    setState(() => _selectedMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      MapScreen(
        key: ValueKey('map_${_selectedMode.toLowerCase()}'),
        isAdmin: widget.isAdmin,
        selectedMode: _selectedMode.toLowerCase(), // ✅ Correct parameter name
      ),

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
              // 🔹 Transport Mode Filter
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
              // 🔹 Bottom Nav Bar
              BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
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
