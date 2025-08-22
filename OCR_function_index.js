const functions = require('@google-cloud/functions-framework');
const Busboy = require('busboy');
const vision = require('@google-cloud/vision');
const { VertexAI } = require('@google-cloud/vertexai');
const cors = require('cors')({ origin: true });
const admin = require('firebase-admin');

// =================================================================
// ============== NEW: FIREBASE ADMIN INITIALIZATION ===============
// =================================================================
try {
  admin.initializeApp();
} catch (e) {
  console.error('Firebase Admin SDK initialization error:', e);
}
// =================================================================

// Config
const GCLOUD_PROJECT = 'calendar-app-467118';
const GCLOUD_LOCATION = 'us-central1';
const MODEL_NAME = 'gemini-2.5-pro';
const FUNCTION_NAME = 'test';

// Init
const visionClient = new vision.ImageAnnotatorClient();
const vertex_ai = new VertexAI({ project: GCLOUD_PROJECT, location: GCLOUD_LOCATION });
const generativeModel = vertex_ai.getGenerativeModel({
    model: MODEL_NAME,
});

// Cloud Function HTTP Handler
functions.http(FUNCTION_NAME, async (req, res) => {
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
            await admin.auth().verifyIdToken(idToken);
        } catch (error) {
            console.error('Error verifying Firebase ID token:', error);
            res.status(403).send('Forbidden: Invalid token.');
            return;
        }
        // =================================================================

        if (req.method !== 'POST') {
            return res.status(405).send('Method Not Allowed');
        }

        const busboy = Busboy({ headers: req.headers });
        let imageBuffer;

        busboy.on('file', (fieldname, file, filename, encoding, mimetype) => {
            const chunks = [];
            file.on('data', (chunk) => chunks.push(chunk));
            file.on('end', () => {
                imageBuffer = Buffer.concat(chunks);
            });
        });

        busboy.on('finish', async () => {
            if (!imageBuffer) {
                return res.status(400).send('No image file uploaded.');
            }

            try {
                const [result] = await visionClient.textDetection(imageBuffer);
                const fullText = result.fullTextAnnotation?.text || '';

                if (!fullText) {
                    return res.status(200).json([]);
                }

                const today = new Date().toISOString().split('T')[0];
                const prompt = `
                    You are a highly intelligent and precise data extraction engine. Your sole function is to analyze unstructured text, identify calendar events, and convert them into a structured JSON format.

                    ### Rules & Constraints:
                    1.  **Output Format:** Your response MUST be a valid JSON array. Do NOT include any explanatory text or markdown.
                    2.  **Event Schema:** Each object MUST contain: "title" (String), "start" (ISO 8601 String), "end" (ISO 8601 String), "location" (String, or "" if none).
                    3.  **Date Logic:** Use today's date, ${today}, as the reference. For days of the week (e.g., "Monday"), calculate the date for the next upcoming instance.
                    4.  **Time Logic:** Handle 12-hour (AM/PM) and 24-hour formats. Assume a 1-hour duration if no end time is specified.
                    5.  **Ambiguity:** If a title or start time is missing for an event, do not include it in the output.
                    6.  **Empty Input:** If no events are found, return an empty array [].

                    Here is the text for analysis:
                    ---
                    ${fullText}
                    ---
                `;

                const geminiResponse = await generativeModel.generateContent(prompt);
                const candidate = geminiResponse?.response?.candidates?.[0];
                let jsonString = candidate?.content?.parts?.[0]?.text || '[]';

                jsonString = jsonString.replace(/```json/g, '').replace(/```/g, '').trim();

                let events = [];
                try {
                    const parsedData = JSON.parse(jsonString);
                    if (Array.isArray(parsedData)) {
                        events = parsedData.filter(event =>
                            event &&
                            typeof event.title === 'string' &&
                            typeof event.start === 'string' &&
                            typeof event.end === 'string'
                        );
                    }
                } catch (jsonError) {
                    console.error('Failed to parse JSON from AI response:', jsonError);
                    events = [];
                }

                res.status(200).json(events);

            } catch (error) {
                console.error('AI processing error:', error);
                res.status(500).send('Error processing image with AI.');
            }
        });

        if (req.rawBody) {
            busboy.end(req.rawBody);
        } else {
            req.pipe(busboy);
        }
    });
});
