const functions = require('@google-cloud/functions-framework');
const { VertexAI } = require('@google-cloud/vertexai');
const cors = require('cors')({ origin: true });
const admin = require('firebase-admin');

// =================================================================
// ============== NEW: FIREBASE ADMIN INITIALIZATION ===============
// =================================================================
// Initialize the Firebase Admin SDK.
// The SDK will automatically use Google Application Default Credentials.
try {
  admin.initializeApp();
} catch (e) {
  console.error('Firebase Admin SDK initialization error:', e);
}
// =================================================================


const GCLOUD_PROJECT = 'calendar-app-467118';
const GCLOUD_LOCATION = 'us-central1';
const MODEL_NAME = 'gemini-2.0-flash-lite';

let generativeModel;

functions.http('processCalendarPrompt', async (req, res) => {
  cors(req, res, async () => {
    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    // =================================================================
    // ============== NEW: FIREBASE AUTHENTICATION CHECK ===============
    // =================================================================
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).send('Unauthorized: No token provided.');
      return;
    }
    const idToken = authHeader.split('Bearer ')[1];

    try {
      // Verify the ID token using the Firebase Admin SDK.
      // This ensures the request is from a valid, authenticated user.
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      // You can optionally use the decodedToken.uid for user-specific logic here.
    } catch (error) {
      console.error('Error verifying Firebase ID token:', error);
      res.status(403).send('Forbidden: Invalid token.');
      return;
    }
    // =================================================================

    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    if (!generativeModel) {
      try {
        const vertex_ai = new VertexAI({ project: GCLOUD_PROJECT, location: GCLOUD_LOCATION });
        generativeModel = vertex_ai.preview.getGenerativeModel({ model: MODEL_NAME });
      } catch (initError) {
        console.error('Failed to initialize Vertex AI client:', initError);
        res.status(500).json({ reply: "Server configuration error.", actions: [] });
        return;
      }
    }

    const { prompt: userPrompt, current_events: currentEvents } = req.body;
    if (!userPrompt) {
      res.status(400).json({ reply: 'No prompt provided.', actions: [] });
      return;
    }

    const today = new Date().toISOString();
    const fullPrompt = `
      You are an expert calendar management AI. Your primary function is to interpret a user's request and convert it into a structured list of actions (CREATE, UPDATE, DELETE) or provide a summary of existing events in a JSON format.

      **CRITICAL INSTRUCTIONS:**
      1.  **Analyze User's Schedule:** You are provided with the user's current list of upcoming events. You MUST use this list to find the correct 'id' for any event the user wants to UPDATE or DELETE.
      2.  **Infer from Context:** The user will refer to events vaguely (e.g., "my meeting on Monday"). You must intelligently match this description to the correct event in the provided schedule to get its 'id'.
      3.  **Strict JSON Output:** Your entire response MUST be a single, valid JSON object: {"reply": "...", "actions": [...]}. Do not include any text, markdown, or explanations outside this object.
      4.  **Handling Listing Requests:** If the user's request is a query to list their schedule (e.g., "what do I have this week?", "list my events", "what's on my calendar?"), your primary goal is to provide a summary in the "reply". In this case, the "actions" array MUST be empty.

      **Current Context:**
      - The current date is: ${today}. Use this for all relative date calculations.
      - The user's upcoming schedule is provided below for context.
      - User's Current Events: ${JSON.stringify(currentEvents, null, 2)}

      **Action Schemas (Your required output format):**
      - **CREATE:** For making a new event.
        {
          "action": "CREATE",
          "event": { "title": "...", "location": "...", "start": "YYYY-MM-DDTHH:mm:ss", "end": "YYYY-MM-DDTHH:mm:ss" }
        }
        (Assume a 1-hour duration if not specified.)

      - **UPDATE:** For changing an existing event.
        {
          "action": "UPDATE",
          "event_id": "the_id_of_the_event_from_the_provided_schedule",
          "updates": { "title": "(optional)", "location": "(optional)", "start": "(optional)", "end": "(optional)" }
        }
        (Only include the fields in "updates" that the user explicitly asked to change.)

      - **DELETE:** For removing an existing event.
        {
          "action": "DELETE",
          "event_id": "the_id_of_the_event_to_delete"
        }

      ---
      **User's Request:**
      "${userPrompt}"

      **Your JSON Response:**
    `;

    try {
      const geminiResponse = await generativeModel.generateContent(fullPrompt);
      const candidate = geminiResponse?.response?.candidates?.[0];

      if (!candidate?.content?.parts?.[0]?.text) {
        throw new Error("Invalid response from AI model.");
      }

      let jsonString = candidate.content.parts[0].text.replace(/```json/g, '').replace(/```/g, '').trim();
      const jsonData = JSON.parse(jsonString);

      if (typeof jsonData.reply !== 'string' || !Array.isArray(jsonData.actions)) {
        throw new Error("AI response is not in the required {reply, actions} format.");
      }

      res.status(200).json(jsonData);
    } catch (error) {
      console.error('Error during AI processing:', error);
      res.status(500).json({
        reply: "I'm sorry, I had trouble understanding that. Could you please try rephrasing?",
        actions: []
      });
    }
  });
});
