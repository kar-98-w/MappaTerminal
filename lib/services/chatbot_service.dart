import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotService {
  final String baseUrl; // your vercel endpoint

  ChatbotService({required this.baseUrl});

  Future<String> sendMessage(String message) async {
    final url = Uri.parse(baseUrl);

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["reply"] ?? "No response from AI.";
      } else {
        print("❌ API error: ${response.statusCode}");
        print(response.body);
        return "Failed to get response (${response.statusCode})";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}
