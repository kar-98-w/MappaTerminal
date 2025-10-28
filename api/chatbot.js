// Make sure package.json has: "type": "module"
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

    // Use your Google AI Studio endpoint
    const apiKey = process.env.GOOGLE_AI_KEY; // Set in Vercel environment variables
    const endpoint = "https://generativelanguage.googleapis.com/v1beta2/models/text-bison-001:generateText";

    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${apiKey}`,
      },
      body: JSON.stringify({
        prompt: {
          text: message
        },
        // optional parameters like maxOutputTokens
        maxOutputTokens: 200
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      return res.status(response.status).json({ error: errorText });
    }

    const data = await response.json();

    // Extract text response
    const reply = data?.candidates?.[0]?.content || "No response from AI.";

    return res.status(200).json({ reply });
  } catch (err) {
    console.error("Chatbot API error:", err);
    return res.status(500).json({ error: "Internal server error" });
  }
}
