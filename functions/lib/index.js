"use strict";
/**
 * Firebase Cloud Functions for grain
 * These functions act as secure middleware to Gemini API
 * The API key is stored here, NOT in the iOS client
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.processVoice = exports.analyzeImage = exports.callGemini = void 0;
const https_1 = require("firebase-functions/v2/https");
const generative_ai_1 = require("@google/generative-ai");
const params_1 = require("firebase-functions/params");
// Define secret for Gemini API key (set via Firebase CLI)
const geminiApiKey = (0, params_1.defineSecret)("GEMINI_API_KEY");
/**
 * Call Gemini for text generation
 */
exports.callGemini = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    // Verify authentication
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be authenticated");
    }
    const { prompt, systemPrompt, model = "gemini-2.0-flash" } = request.data;
    if (!prompt) {
        throw new https_1.HttpsError("invalid-argument", "Prompt is required");
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const geminiModel = genAI.getGenerativeModel({
        model,
        systemInstruction: systemPrompt,
    });
    try {
        const result = await geminiModel.generateContent(prompt);
        const text = result.response.text();
        return { text };
    }
    catch (error) {
        console.error("Gemini error:", error);
        throw new https_1.HttpsError("internal", "Failed to generate response");
    }
});
/**
 * Analyze image with Gemini Vision
 */
exports.analyzeImage = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be authenticated");
    }
    const { image, mimeType, prompt, model = "gemini-2.0-flash" } = request.data;
    if (!image || !prompt) {
        throw new https_1.HttpsError("invalid-argument", "Image and prompt are required");
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const geminiModel = genAI.getGenerativeModel({ model });
    try {
        const result = await geminiModel.generateContent([
            prompt,
            {
                inlineData: {
                    mimeType: mimeType || "image/jpeg",
                    data: image,
                },
            },
        ]);
        const text = result.response.text();
        // Extract mentioned pleasure dimensions
        const dimensions = extractDimensions(text);
        return { text, dimensions };
    }
    catch (error) {
        console.error("Gemini vision error:", error);
        throw new https_1.HttpsError("internal", "Failed to analyze image");
    }
});
/**
 * Process voice message for live coaching
 */
exports.processVoice = (0, https_1.onCall)({ secrets: [geminiApiKey] }, async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Must be authenticated");
    }
    const { audio, mimeType, sessionId, systemPrompt } = request.data;
    if (!audio) {
        throw new https_1.HttpsError("invalid-argument", "Audio is required");
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(geminiApiKey.value());
    const model = genAI.getGenerativeModel({
        model: "gemini-2.0-flash",
        systemInstruction: systemPrompt,
    });
    try {
        // For now, transcribe and respond with text
        // Full Live API with bidirectional audio requires different architecture
        const result = await model.generateContent([
            {
                inlineData: {
                    mimeType: mimeType || "audio/wav",
                    data: audio,
                },
            },
            "Listen to this audio and respond as a somatic coach. Keep response brief (1-2 sentences).",
        ]);
        const text = result.response.text();
        const dimensions = extractDimensions(text);
        return {
            text,
            dimensions,
            sessionId,
        };
    }
    catch (error) {
        console.error("Gemini voice error:", error);
        throw new https_1.HttpsError("internal", "Failed to process voice");
    }
});
/**
 * Extract pleasure dimensions mentioned in text
 */
function extractDimensions(text) {
    const dimensionNames = [
        "order", "anxiety", "post", "enclosure", "path", "horizon",
        "ignorance", "repetition", "food", "mobility", "power",
        "erotic uncertainty", "material play", "nature mirror",
        "serendipity following", "anchor expansion"
    ];
    const lowerText = text.toLowerCase();
    return dimensionNames.filter(dim => lowerText.includes(dim));
}
//# sourceMappingURL=index.js.map