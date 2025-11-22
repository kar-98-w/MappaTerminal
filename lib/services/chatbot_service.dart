import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class ChatbotService {
  final String apiKey;
  final String model;

  Position? _userLocation; // Store last known user location

  final List<Map<String, String>> _chatHistory = [];

  ChatbotService({
    required this.apiKey,
    this.model = "gemini-2.0-flash",
  });

  /// Set or update the user's location
  void setUserLocation(Position? position) {
    _userLocation = position;
  }

  /// Optional: get last stored location
  Position? get userLocation => _userLocation;

  /// Get user's current GPS location (requests permission if needed)
  Future<Position> getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are denied.');
      }
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  /// Fetch all terminals from Firebase
  Future<Map<String, dynamic>> _getAllTerminals() async {
    final snapshot =
    await FirebaseFirestore.instance.collection('terminals').get();
    Map<String, dynamic> terminals = {};
    for (var doc in snapshot.docs) {
      terminals[doc.id] = doc.data();
    }
    return terminals;
  }

  // --- (Helper functions _findTerminalIdByName, _computePath, _parseFare, _formatTerminalsData, findNearestTerminal are all unchanged) ---
  String? _findTerminalIdByName(
      Map<String, dynamic> terminals, String name) {
    for (var entry in terminals.entries) {
      final data = entry.value as Map<String, dynamic>;
      final terminalName = data['name'] as String?;
      if (terminalName != null &&
          terminalName.toLowerCase() == name.toLowerCase()) {
        return entry.key; // Returns the document ID (e.g., "terminal_A")
      }
    }
    return null; // Not found
  }
  Future<List<String>> _computePath(Map<String, dynamic> terminals,
      String startName, String destinationName) async {
    // Find the document IDs for the start and destination names
    final String? startId = _findTerminalIdByName(terminals, startName);
    final String? destinationId =
    _findTerminalIdByName(terminals, destinationName);

    // Can't proceed if we don't have a valid start or end
    if (startId == null || destinationId == null) {
      return [];
    }
    List<String> pathIds = []; // Will store the path as Document IDs
    Set<String> visited = {};
    bool dfs(String currentId) {
      if (visited.contains(currentId)) return false;
      visited.add(currentId);
      pathIds.add(currentId);
      // Check if we've reached the destination ID
      if (currentId == destinationId) return true;
      final terminal = terminals[currentId];
      if (terminal != null) {
        final connectsTo = terminal['connectsTo'] as List<dynamic>? ?? [];
        for (var next in connectsTo) {
          String nextId = next is DocumentReference ? next.id : next.toString();
          if (dfs(nextId)) return true;
        }
      }
      pathIds.removeLast();
      return false;
    }
    dfs(startId); // Start the search from the start ID
    // Convert the list of IDs back to human-readable names for the AI
    return pathIds
        .map((id) => (terminals[id]?['name'] ?? id) as String)
        .toList();
  }
  String _parseFare(dynamic fareData) {
    if (fareData == null) {
      return 'N/A';
    }
    // Case 1: Fare is a map (e.g., { min: 12, max: 15 })
    if (fareData is Map) {
      final min = fareData['min'];
      final max = fareData['max'];
      if (min != null && max != null) {
        return '₱$min - ₱$max';
      } else if (min != null) {
        return '₱$min';
      } else if (max != null) {
        return '₱$max (max)';
      }
    }
    // Case 2: Fare is a number (e.g., 15)
    if (fareData is num) {
      return '₱${fareData.toString()}';
    }
    // Case 3: Fare is a string (e.g., "15" or "12-15")
    final fareString = fareData.toString();
    if (fareString.startsWith('₱')) {
      return fareString;
    }
    if (double.tryParse(fareString) != null) {
      return '₱$fareString';
    }
    return fareString; // Return as-is (e.g., "Contact driver")
  }
  Future<String> _formatTerminalsData(Map<String, dynamic> terminals) async {
    return terminals.entries.map((entry) {
      final data = entry.value as Map<String, dynamic>;
      final connectsTo = (data['connectsTo'] as List<dynamic>? ?? [])
          .map((ref) => ref is DocumentReference ? ref.id : ref.toString())
          .join(', ');

      String routesInfo = '';
      if (data['routes'] != null && data['routes'] is List) {
        final routes = List<Map<String, dynamic>>.from(data['routes']);
        routesInfo = routes.map((route) {
          final toName = route['to'] is DocumentReference
              ? (route['to'] as DocumentReference).id
              : route['to']?.toString() ?? 'Unknown';

          final String fareInfo = _parseFare(route['fare']);

          return "- To: $toName\n  Type: ${route['type'] ?? 'N/A'}\n  Schedule: ${route['timeSchedule'] ?? 'N/A'}\n  Fare: $fareInfo";
        }).join('\n');
      } else {
        routesInfo = "No route info";
      }

      return """
Name: ${data['name'] ?? 'Unknown'}
Nearest Landmark: ${data['nearestLandmark'] ?? 'N/A'}
Connects To: ${connectsTo.isEmpty ? 'N/A' : connectsTo}
Routes:
$routesInfo
""";
    }).join("\n----------------\n");
  }
  Future<Map<String, dynamic>?> findNearestTerminal(Position position) async {
    final terminals = await _getAllTerminals();
    double minDistance = double.infinity;
    Map<String, dynamic>? nearestTerminal;

    for (var entry in terminals.entries) {
      final data = entry.value as Map<String, dynamic>;
      final lat = (data['latitude'] ?? 0).toDouble();
      final lng = (data['longitude'] ?? 0).toDouble();
      final distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, lat, lng);
      if (distance < minDistance) {
        minDistance = distance;
        nearestTerminal = {'id': entry.key, 'data': data};
      }
    }
    return nearestTerminal;
  }

  // --- 1. MODIFIED: This function now returns true (success) or false (failure) ---
  Future<bool> _submitUserFeedback(String feedbackMessage) async {
    try {
      await FirebaseFirestore.instance.collection('user_feedback').add({
        'timestamp': FieldValue.serverTimestamp(),
        'feedback_message': feedbackMessage,
        'chat_history': _chatHistory,
        'user_location': _userLocation != null
            ? '${_userLocation!.latitude}, ${_userLocation!.longitude}'
            : 'Not available',
        'status': 'new',
      });
      return true; // <-- It worked!
    } catch (e) {
      // It failed! Print the error and return false.
      print("❌ FAILED TO SAVE FEEDBACK: $e");
      return false; // <-- It failed!
    }
  }


  // --- 2. MODIFIED: This function now CHECKS if the save was successful ---
  Future<String> sendMessage(String message, {String? startTerminal}) async {

    _chatHistory.add({"role": "user", "text": message});

    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('feedback') ||
        lowerMessage.contains('report') ||
        lowerMessage.contains('wrong') ||
        lowerMessage.contains('incorrect') ||
        lowerMessage.contains('outdated') ||
        lowerMessage.contains('missing')) {

      // --- CHECK THE RESULT ---
      bool didSave = await _submitUserFeedback(message);

      String response;
      if (didSave) {
        // --- Only show "Thank you" if it worked ---
        response = "Thank you! I have forwarded your feedback to the admin for review.";
      } else {
        // --- Show an error if it failed ---
        response = "I'm sorry, I tried to send your feedback but an error occurred. Please try again later.";
      }

      _chatHistory.add({"role": "ai", "text": response});
      return response;
    }

    // --- (Rest of your Gemini/question-answering code is unchanged) ---

    final terminals = await _getAllTerminals();
    final terminalsData = await _formatTerminalsData(terminals);

    String gpsInfo = '';
    if (_userLocation != null) {
      final nearest = await findNearestTerminal(_userLocation!);
      if (nearest != null) {
        final data = nearest['data'] as Map<String, dynamic>;
        startTerminal ??= data['name'] ?? nearest['id'];
        gpsInfo =
        "User is at latitude ${_userLocation!.latitude}, longitude ${_userLocation!.longitude}. Nearest terminal: ${data['name'] ?? nearest['id']}.";
      }
    }

    List<String> path = [];
    if (startTerminal != null) {
      final regex = RegExp(r'to (.+)', caseSensitive: false);
      final match = regex.firstMatch(message);

      final destination = match != null
          ? match.group(1)?.trim().replaceAll(RegExp(r'[.?]'), '') ?? ''
          : '';

      if (destination.isNotEmpty) {
        path = await _computePath(terminals, startTerminal, destination);
      }
    }

    String pathInfo =
    path.isNotEmpty ? 'Precomputed Path: ' + path.join(' → ') : '';

    final systemPrompt = """
You are an AI assistant for San Fernando, Pampanga terminals.
You have the following data from Firebase:

$terminalsData

Instructions:
- **Your main goal is to be easily readable.**
- **Format your response clearly.** Use newlines to separate thoughts and steps.
- **Do NOT use asterisks (*) or any Markdown.** Use spaces for indentation.
- Do NOT include latitude/longitude in your response.
- Provide step-by-step directions between terminals.
- When listing a route's details, use this exact format:
Route to: [Destination Name]
  Vehicle: [Jeepney/Bus/Minibus]
  Fare: ₱[Fare info]
  Schedule: [Schedule info]
- If a terminal has multiple routes, list them one by one using that format.
- Precomputed path: $pathInfo
- GPS info (for reference only): $gpsInfo
""";

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent",
    );

    final payload = {
      "systemInstruction": {
        "parts": [{"text": systemPrompt}]
      },
      "contents": [
        ..._chatHistory.map((msg) => {
          "role": msg["role"] == "user" ? "user" : "model",
          "parts": [{"text": msg["text"]!}]
        })
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-goog-api-key": apiKey,
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final candidates = data["candidates"];
        if (candidates != null && candidates.isNotEmpty) {
          final parts = candidates[0]["content"]["parts"];
          if (parts != null && parts.isNotEmpty) {

            final aiResponse = parts[0]["text"] ?? "⚠️ No text returned";

            _chatHistory.add({"role": "ai", "text": aiResponse});
            return aiResponse;
          }
        }
        return "⚠️ No reply from Gemini.";
      } else {
        _chatHistory.removeLast();
        return "Sorry, please try again (Error: ${response.statusCode})";
      }
    } catch (e) {
      _chatHistory.removeLast();
      return "Sorry, please try again. ($e)";
    }
  }
}