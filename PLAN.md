# Technical Design Document: grain (iOS)

**Project Name:** grain
**Platform:** iOS 18+ (Target: iPhone 17)
**Tech Stack:** Swift 6, SwiftUI, Firebase (Backend), Google Gemini 1.5 Pro (Intelligence)
**Version:** 1.0 (MVP)

-----

## 1\. System Overview

**grain** is a "Hedonic Operating System" designed to systematically discover, catalog, and guide the user through new modes of pleasure using the principles of phenomenology and Barthesian philosophy.

The system consists of three integrated modules:

1.  **The Architect:** Planning, Inventory Management (NYC + Personal), and Logistics.
2.  **The Guide:** Real-time, voice-first somatic coaching and navigation.
3.  **The Scribe:** Passive logging, vector embedding, and insight generation.

-----

## 2\. High-Level Architecture

### Client-Side (iOS)

  * **Language:** Swift 6
  * **UI Framework:** SwiftUI
  * **Local Storage:** SwiftData (for offline caching of journals/plans).
  * **Sensors:** CoreLocation (Geofence), AVFoundation (Camera/Mic), Speech (Transcripts).

### Backend (Firebase)

  * **Auth:** Firebase Authentication.
  * **Database:** Cloud Firestore (NoSQL).
  * **Compute:** Cloud Functions (Node.js/Python) acting as middleware to Gemini.
  * **Storage:** Firebase Storage (Audio logs, Photos).

### Intelligence Layer (Google Gemini)

  * **Primary Model:** `gemini-1.5-pro` (Complex reasoning, Planning, Architect).
  * **Fast Model:** `gemini-1.5-flash` (Real-time Guide interactions, Vision analysis).
  * **Vector Embeddings:** For semantic search of past pleasures.

-----

## 3\. Data Schema (Firestore)

### `users/{uid}`

Stores global preferences and the "Pleasure Profile."

```json
{
  "uid": "string",
  "pleasure_bias": {
    "mastery": 0.7,  // 0.0 - 1.0
    "sensory": 0.4,
    "social": 0.2
  },
  "current_state": "depleted", // inferred by Scribe
  "context": "nyc"
}
```

### `inventory/{itemId}`

Tracks both owned items and accessible NYC infrastructure.

```json
{
  "id": "string",
  "name": "Zoom H4n Recorder",
  "type": "tool", // tool, space, expert
  "access_mode": "public_library", // owned, peer, rental, public_library
  "location_coords": { "lat": 40.7, "lng": -73.9 },
  "status": "available", // available, booked, maintenance
  "affordances": ["auditory", "technical", "capture"]
}
```

### `sessions/{sessionId}`

Logs completed or active experiences.

```json
{
  "id": "string",
  "user_id": "string",
  "mode": "drift", // drift, mastery, social_sync
  "timestamp_start": "timestamp",
  "transcript_url": "string",
  "media_urls": ["string"],
  "pleasure_vector": [0.1, 0.9, 0.4], // [Mastery, Sensory, Social]
  "notes": "string"
}
```

-----

## 4\. Module Specifications

### Module 1: The Architect (Inventory & Planning)

**Functionality:**
Generates "Missions" based on user state and available inventory. It treats NYC as a warehouse.

**Key Components:**

  * **`InventoryService`:** Fetches items. Filters by distance (using `CoreLocation`).
  * **`PlannerService`:** Calls Gemini Cloud Function `generate_mission`.
      * *Input:* User State ("Anxious"), Weather ("Rainy"), Local Inventory.
      * *Output:* Structured Plan (Tool: "Noise Cancelling Headphones", Location: "Lincoln Center Fountain", Duration: "20 mins").
  * **`CalendarManager`:** Wraps `EventKit`.
      * *Action:* Creates "Hard Block" calendar events for the mission.

**UI Views:**

  * `DashboardView`: Displays "Current State" and "Suggested Mission."
  * `InventoryMapView`: MapKit view showing "Owned" vs "Public" assets in NYC.

### Module 2: The Guide (Real-Time Companion)

**Functionality:**
Acts as a somatic coach during the session. Uses voice and vision to "debug" the user's experience.

**Key Components:**

  * **`AudioSessionManager`:**
      * Input: `SFSpeechRecognizer` or OpenAI Whisper (via API) for high-fidelity transcription.
      * Output: `AVSpeechSynthesizer` for text-to-speech.
  * **`VisionAnalysisService`:**
      * Action: Captures photo, sends to `gemini-1.5-flash`.
      * Prompt: *"Analyze this texture. Give me a phenomenological instruction on how to touch it."*
  * **`GeofenceManager`:**
      * Action: Monitors `CLCircularRegion` around inventory items (e.g., "Near Strand Bookstore"). Triggers local notification: *"Opportunity for Olfactory Pleasure nearby."*
  * **Hardware Trigger:**
      * **Action Button (iPhone 17):** Map long-press to "Start Drift Mode" instantly.

**UI Views:**

  * `ActiveSessionView`: Minimalist interface. Large "Mic" button. Background color shifts based on "Sentiment" (Bio-feedback simulation).

### Module 3: The Scribe (Integration & Insight)

**Functionality:**
Processes raw session data into "Wisdom" (Vectors).

**Key Components:**

  * **`BackgroundProcessor`:** Uses `BGTaskScheduler` to upload large audio files after the app closes.
  * **`VectorService`:**
      * Action: Sends session transcript to an embedding model.
      * Storage: Stores vector in Firestore (or Pinecone if scale is needed).
  * **`InsightEngine`:**
      * Action: Queries Gemini to compare *this* session with *past* sessions.
      * *Prompt:* "User felt bored today. Compare this with their 'Woodworking' session from last month. What is the pattern?"

**UI Views:**

  * `LogBookView`: Timeline of sessions.
  * `VectorPlotView`: Using Swift Charts to visualize the user's "Pleasure Map" (Mastery vs. Sensory axis).

-----

## 5\. Security & Privacy

  * **Data Sovereignty:** All raw audio logs are stored in a private bucket `users/{uid}/private/`.
  * **Anonymization:** Before sending text to Gemini, strip PII (Personal Identifiable Information) using a regex filter.
  * **Local First:** Cache sensitivity data in SwiftData; only sync vectors and abstract summaries if possible.

-----

## 6\. Implementation Roadmap (Cursor Prompts)

Copy these blocks into Cursor to generate the code.

### Phase 1: Setup & Backend

```text
Create a new iOS SwiftUI project named 'grain'.
Set up a FirebaseManager singleton that handles Auth and Firestore.
Define the Codable structs for User, InventoryItem, and Session matching the schema in the TDD.
Create a GeminiService class that calls a Firebase Cloud Function 'callGemini'.
```

### Phase 2: The Architect (Logic)

```text
Build a View 'ArchitectDashboard'.
Fetch inventory items from Firestore.
Add a 'Generate Mission' button.
When clicked, call GeminiService with the prompt: "Given inventory [items] and user state 'low_energy', suggest a 30-min sensory activity in NYC."
Display the result in a CardView with a 'Accept & Add to Calendar' button.
Implement EventKit to save this to the iOS Calendar.
```

### Phase 3: The Guide (Voice/Vision)

```text
Build 'ActiveSessionView'.
Implement a 'Push-to-Talk' button that records audio to a temporary file.
When released, transcribe audio using SFSpeechRecognizer.
Send text to GeminiService with system prompt: "You are a somatic coach. Reply in 1 sentence. Focus on texture and breath."
Play the response using AVSpeechSynthesizer.
Add a 'Camera' button that captures a photo and sends it to Gemini 1.5 Flash for 'Texture Analysis'.
```

### Phase 4: Location & Background

```text
Implement a LocationManager using CoreLocation.
Create a function 'monitorInventoryRegions' that takes a list of InventoryItems.
Start monitoring 100m geofences around them.
Trigger a UNUserNotification when entering a region: "Nearby Inventory: [Name]".
```