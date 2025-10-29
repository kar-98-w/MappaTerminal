import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  final String apiKey; // Your Google API key
  final String model;

  ChatbotService({
    required this.apiKey,
    this.model = "gemini-2.0-flash", // default Gemini model
  });

  /// Sends a message to the Gemini API and returns the AI reply.
  Future<String> sendMessage(String message) async {
    final url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent");

    final payload = {
      "contents": [
        {
          "parts": [
            {"text": message}
          ]
        }
      ]
    };

    try {
      final response = await http
          .post(
        url,
        headers: {
          "Content-Type": "application/json",
          "X-goog-api-key": apiKey,
        },
        body: jsonEncode(payload),
      )
          .timeout(const Duration(seconds: 15));

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
      } else if (response.statusCode == 400) {
        return "Bad request (400). Check your message payload.";
      } else if (response.statusCode == 401) {
        return "Unauthorized (401). Check your API key.";
      } else if (response.statusCode == 404) {
        return "Model not found (404). Check the model name.";
      } else {
        return "Error ${response.statusCode}: ${response.body}";
      }
    } catch (e) {
      return "Exception calling Gemini API: $e";
    }
  }
}
