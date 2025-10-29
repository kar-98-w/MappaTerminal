// api/chatbot.js
import fetch from "node-fetch";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { message } = req.body;

    if (!message) {
      return res.status(400).json({ error: "Message is required" });
    }

    // Replace with your Google Gemini API endpoint & key
    const GOOGLE_AI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";
    const GOOGLE_AI_API_KEY = "AIzaSyDK8eLauZkKT8XF26oG4WX1sr7y96aQfNQ"; // replace with your key

    const response = await fetch(`${GOOGLE_AI_API_URL}?key=${GOOGLE_AI_API_KEY}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        "contents": [
          {
            "role": "user",
            "parts": [{ "text": message }]
          }
        ],
        "generationConfig": { "temperature": 0.7, "maxOutputTokens": 500 }
      }),
    });

    if (!response.ok) {
      const text = await response.text();
      return res.status(response.status).json({ error: text });
    }

    const data = await response.json();
    const reply = data?.candidates?.[0]?.content?.[0]?.text ?? "No response from AI";

    res.status(200).json({ reply });
  } catch (error) {
    console.error("Chatbot error:", error);
    res.status(500).json({ error: "Internal Server Error" });
  }
}
