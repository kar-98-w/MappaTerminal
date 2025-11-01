import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatbotService {
  final String apiKey;
  final String model;

  ChatbotService({
    required this.apiKey,
    this.model = "gemini-2.0-flash",
  });

  /// Fetches the latest terminals data from Firestore.
  Future<String> _getTerminalsData() async {
    final snapshot = await FirebaseFirestore.instance.collection('terminals').get();

    if (snapshot.docs.isEmpty) return "No terminal data available.";

    // Create a readable summary string
    final terminalsInfo = snapshot.docs.map((doc) {
      final data = doc.data();
      return """
Name: ${data['name'] ?? 'Unknown'}
Type: ${data['type'] ?? 'N/A'}
Fare Metric: ${data['fareMetric'] ?? 'N/A'}
Nearest Landmark: ${data['nearestLandmark'] ?? 'N/A'}
Schedule: ${data['timeSchedule'] ?? 'N/A'}
Location: (${data['latitude']}, ${data['longitude']})
""";
    }).join("\n----------------\n");

    return terminalsInfo;
  }

  /// Sends a message to the Gemini API with Firestore data as context.
  Future<String> sendMessage(String message) async {
    final terminalsData = await _getTerminalsData();

    final systemPrompt = """
You are a helpful assistant that answers questions about transport terminals in San Fernando, Pampanga.
You have the following data from Firebase:

$terminalsData

User question: "$message"

Respond clearly, using only the information from the data if possible.
If unsure, politely say you don’t have that information.
""";

    final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent",
    );

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": systemPrompt}
          ]
        }
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
            return parts[0]["text"] ?? "⚠️ No text returned";
          }
        }
        return "⚠️ No reply from Gemini.";
      } else {
        return "Error ${response.statusCode}: ${response.body}";
      }
    } catch (e) {
      return "Exception calling Gemini API: $e";
    }
  }
}
