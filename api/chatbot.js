import { json } from '@vercel/node';
import fetch from 'node-fetch';

export default async function handler(req, res) {
  try {
    // Dynamic import for node-fetch (ESM compatible)
    const fetch = (...args) => import('node-fetch').then(mod => mod.default(...args));

    // Get your Google API key from environment variables
    const apiKey = process.env.GOOGLE_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ error: "Google API key not set in environment variables." });
    }

    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed" });
    }

    const { message } = req.body;
    if (!message) {
      return res.status(400).json({ error: "Message is required" });
    }

    // Call Google Generative AI Text API (Text-Bison model)
    const response = await fetch(
      "https://generativelanguage.googleapis.com/v1beta2/models/text-bison-001:generateText",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          prompt: message,
          temperature: 0.7, // optional: adjust creativity
        }),
      }
    );

    const data = await response.json();
    const reply = data?.candidates?.[0]?.output || "No response from AI.";

    res.status(200).json({ reply });
  } catch (err) {
    console.error("Chatbot API error:", err);
    res.status(500).json({ error: "Internal Server Error" });
  }
}

