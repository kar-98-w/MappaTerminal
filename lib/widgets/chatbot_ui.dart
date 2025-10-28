import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  final String baseUrl; // URL of your Vercel deployment

  ChatbotService({required this.baseUrl});

  Future<String> sendMessage(String message) async {
    final url = Uri.parse("$baseUrl/api/chatbot"); // your function endpoint

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? "No response from AI.";
      } else {
        print("❌ Chatbot API error: ${response.statusCode}");
        print("Response body: ${response.body}");
        return "Failed to get AI response: ${response.statusCode}";
      }
    } catch (e) {
      return "Error sending message: $e";
    }
  }
}
