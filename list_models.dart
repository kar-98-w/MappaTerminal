import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const apiKey = "AIzaSyDK8eLauZkKT8XF26oG4WX1sr7y96aQfNQ"; // Your API key
  const model = "gemini-2.0-flash";

  final url = Uri.parse(
      "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent");

  final body = jsonEncode({
    "contents": [
      {
        "parts": [
          {"text": "Explain how AI works in a few words"}
        ]
      }
    ]
  });

  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
    },
    body: body,
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    print("Response: $data");
  } else {
    print("Error ${response.statusCode}: ${response.body}");
  }
}
