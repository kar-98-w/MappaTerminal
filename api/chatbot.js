// chatbot.js
import fetch from "node-fetch";

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const { message } = req.body;

  if (!message) {
    return res.status(400).json({ error: "Message is required" });
  }

  try {
    const apiKey = process.env.GOOGLE_AI_API_KEY; // set this in Vercel
    const model = "gemini-2.5-pro"; // or your preferred model

    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta2/models/${model}:generateText`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
        },
        body: JSON.stringify({
          model: model,
          input: [
            {
              role: "user",
              content: [
                { type: "text", text: message }
              ]
            }
          ],
          temperature: 0.7,
          maxOutputTokens: 200
        }),
      }
    );

    const data = await response.json();

    const aiText =
      data.responses?.[0]?.output?.[0]?.content?.[0]?.text || "No response from AI";

    res.status(200).json({ reply: aiText });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Error calling AI API", details: error.message });
  }
}
