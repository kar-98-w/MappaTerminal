// api/chatbot.js
import fetch from "node-fetch";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { message } = await req.body ? req.body : {};

    if (!message) {
      return res.status(400).json({ error: "Message is required" });
    }

    // Replace with your Google AI Studio endpoint
    const GOOGLE_AI_API_URL = process.env.GOOGLE_AI_API_URL;
    const GOOGLE_AI_API_KEY = process.env.GOOGLE_AI_API_KEY;

    if (!GOOGLE_AI_API_URL || !GOOGLE_AI_API_KEY) {
      return res.status(500).json({ error: "AI API not configured" });
    }

    // Send the message to Google AI
    const response = await fetch(GOOGLE_AI_API_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${GOOGLE_AI_API_KEY}`,
      },
      body: JSON.stringify({ prompt: message, max_tokens: 200 }),
    });

    if (!response.ok) {
      const text = await response.text();
      return res.status(response.status).json({ error: text });
    }

    const data = await response.json();

    // Adjust depending on the response structure from Google AI
    const reply = data?.choices?.[0]?.text ?? "No response from AI";

    return res.status(200).json({ reply });
  } catch (error) {
    console.error("Chatbot error:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
