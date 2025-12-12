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

  * **Auth:** Firebase Authentication (anonymous + future social auth).
  * **Database:** Cloud Firestore (NoSQL) with vector search for embeddings.
  * **Compute:** Cloud Functions (TypeScript) as secure middleware to Gemini.
  * **Storage:** Firebase Storage (Audio logs, Photos).
  * **Secrets:** Firebase Secret Manager for API keys (never in client).

### Cloud Functions (Gemini Middleware)

The iOS client **never** holds API keys. All Gemini calls route through Cloud Functions:

```
┌─────────────┐    Firebase Auth    ┌──────────────────┐    Secret Key    ┌─────────────┐
│ iOS Client  │ ─────────────────→  │ Cloud Functions  │ ───────────────→ │ Gemini API  │
│ (no keys)   │    authenticated    │ (GEMINI_API_KEY) │                  │             │
└─────────────┘                     └──────────────────┘                  └─────────────┘
```

**Functions:**

| Function | Purpose | Model |
|----------|---------|-------|
| `callGemini` | Text generation, coaching responses | gemini-2.0-flash |
| `analyzeImage` | Vision analysis with dimension extraction | gemini-2.0-flash |
| `processVoice` | Audio transcription + somatic coaching | gemini-2.0-flash |

**Setup:**
```bash
# Set the API key as a secret (one-time)
firebase functions:secrets:set GEMINI_API_KEY

# Deploy functions
cd functions && npm install && npm run deploy
```

### Intelligence Layer (Google Gemini)

  * **Primary Model:** `gemini-2.0-flash` (Fast, multimodal, real-time interactions).
  * **Fallback Model:** `gemini-1.5-pro` (Complex reasoning if needed).
  * **Vector Embeddings:** Firestore Vector Search for 16D pleasure embeddings.

-----

## 3\. Data Schema (Firestore)

### `users/{uid}`

Stores global preferences and the "Pleasure Profile" using 16 compositional dimensions.

```json
{
  "uid": "string",
  "pleasure_profile": {
    // Spatial/Environmental
    "order": 0.6,           // Satisfaction from structure, organization
    "enclosure": 0.4,       // Preference for contained vs. expansive spaces
    "path": 0.7,            // Joy in route-finding, directed movement
    "horizon": 0.5,         // Drawn to vistas, big-picture views
    
    // Cognitive/Existential  
    "anxiety": 0.3,         // Tolerance/appetite for productive tension
    "ignorance": 0.8,       // Comfort with not-knowing, mystery
    "repetition": 0.5,      // Pleasure in ritual, recurrence
    
    // Temporal
    "post": 0.6,            // Appreciation of aftermath, reflection
    
    // Embodied
    "food": 0.7,            // Gustatory pleasure sensitivity
    "mobility": 0.8,        // Kinesthetic joy, movement
    "erotic_uncertainty": 0.4,  // Attraction to ambiguous intimacy
    "material_play": 0.6,   // Tactile exploration, making
    
    // Relational/External
    "power": 0.3,           // Agency, influence, mastery over
    "nature_mirror": 0.7,   // Resonance with natural systems
    "serendipity_following": 0.9,  // Openness to chance encounters
    "anchor_expansion": 0.5 // Building from stable points outward
  },
  "circadian_profile": {
    "dawn": ["nature_mirror", "mobility"],
    "morning": ["order", "path", "power"],
    "afternoon": ["material_play", "serendipity_following"],
    "evening": ["enclosure", "food", "repetition"],
    "night": ["ignorance", "horizon", "erotic_uncertainty"]
  },
  "current_state": "depleted", // inferred by Scribe
  "session_state": "idle",    // idle, drift, mastery, social_sync, reflection
  "context": "nyc"
}
```

### `inventory/{itemId}`

Tracks both owned items and accessible infrastructure with structured affordances.

```json
{
  "id": "string",
  "name": "Zoom H4n Recorder",
  "type": "tool", // tool, space, expert
  "access_mode": "public_library", // owned, peer, rental, public_library
  "location_coords": { "lat": 40.7, "lng": -73.9 },
  "status": "available", // available, booked, maintenance
  "affordances": [
    { "sense": "auditory", "intensity": "high", "context": "solitude" },
    { "sense": "technical", "intensity": "medium", "context": "mastery" },
    { "pleasure_dims": ["material_play", "order", "repetition"] }
  ],
  "temporal_tags": {
    "best_times": ["morning", "afternoon"],
    "duration_range": { "min": 30, "max": 120 },
    "seasonal": ["all"]
  }
}
```

### `sessions/{sessionId}`

Logs completed or active experiences with full pleasure vector.

```json
{
  "id": "string",
  "user_id": "string",
  "state": "drift", // idle, drift, mastery, social_sync, reflection
  "state_history": ["idle", "drift", "mastery", "drift"], // transition log
  "timestamp_start": "timestamp",
  "timestamp_end": "timestamp",
  "transcript_url": "string",
  "media_urls": ["string"],
  "pleasure_vector": {
    // Activated dimensions during this session
    "primary": ["serendipity_following", "mobility", "nature_mirror"],
    "secondary": ["ignorance", "horizon"],
    "intensities": {
      "serendipity_following": 0.9,
      "mobility": 0.7,
      "nature_mirror": 0.8,
      "ignorance": 0.4,
      "horizon": 0.3
    }
  },
  "notes": "string",
  "embedding_id": "string" // Reference to vector store
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

  * **`LiveSessionManager`:** (Gemini Live API)
      * Establishes bidirectional WebSocket connection to Gemini 2.0 Flash Live API.
      * Sub-second voice interaction: streams audio in, receives audio out.
      * Maintains conversation context across the session.
      * System prompt: *"You are a somatic coach. Focus on the 16 pleasure dimensions. Guide attention to texture, breath, and spatial awareness."*
  * **`VisionAnalysisService`:**
      * Action: Captures photo, sends to `gemini-2.0-flash`.
      * Prompt: *"Analyze this texture. Give me a phenomenological instruction on how to engage with it. Reference pleasure dimensions: material_play, nature_mirror."*
  * **`GeofenceManager`:**
      * Action: Monitors `CLCircularRegion` around inventory items (e.g., "Near Strand Bookstore"). Triggers local notification: *"Opportunity for Olfactory Pleasure nearby."*
  * **`SessionStateMachine`:**
      * Manages transitions between states: `idle → drift → mastery → drift/social_sync → drift/mastery`
      * Valid transitions:
        ```
        idle → drift
        drift → mastery | social_sync
        mastery → drift | social_sync
        social_sync → drift | mastery
        * → reflection (on session end)
        reflection → idle
        ```
  * **Hardware Trigger:**
      * **Action Button (iPhone 15 Pro+):** Map long-press to "Start Drift Mode" instantly.
      * **Fallback:** Triple-tap back gesture for older devices.

**UI Views:**

  * `ActiveSessionView`: Minimalist interface. Waveform visualization for Live API audio. Background color shifts based on current state and pleasure activation.

### Module 3: The Scribe (Integration & Insight)

**Functionality:**
Processes raw session data into "Wisdom" (Vectors) using Firebase Vector Search.

**Key Components:**

  * **`BackgroundProcessor`:** Uses `BGTaskScheduler` to upload large audio files after the app closes.
  * **`VectorService`:** (Firebase Vector Search)
      * Action: Sends session transcript + pleasure vector to embedding model.
      * Storage: Uses Firestore's native vector search with `FieldValue.vector()` for 16D pleasure embeddings.
      * Index: Create vector index on `sessions` collection for semantic similarity queries.
  * **`InsightEngine`:**
      * Action: Queries Gemini to compare *this* session with semantically similar past sessions.
      * *Prompt:* "User activated serendipity_following (0.9) and nature_mirror (0.8) today. Find similar sessions and identify patterns."
      * Uses vector similarity to retrieve relevant sessions before LLM analysis.

**UI Views:**

  * `LogBookView`: Timeline of sessions with pleasure dimension badges.
  * `PleasureSpaceView`: Swift Charts 3D/2D projection of user's 16-dimensional pleasure profile over time. Cluster visualization of session types.

-----

## 5\. Security & Privacy

  * **Data Sovereignty:** All raw audio logs are stored in a private bucket `users/{uid}/private/`.
  * **Anonymization:** Before sending text to Gemini, use Apple's `NLTagger` (on-device NLP) to detect and redact PII:
      * Detect: `.personalName`, `.placeName`, `.organizationName`
      * Replace with generic tokens: `[PERSON]`, `[PLACE]`, `[ORG]`
  * **Local First:** Cache sensitive data in SwiftData; only sync vectors and abstract summaries if possible.

-----

## 6\. Implementation Roadmap

### Phase 0: Firebase Infrastructure Setup

**0.1 Project Initialization**
```bash
# Create Firebase project
firebase login
firebase init

# Select: Functions, Firestore, Storage, Hosting (optional)
# Use TypeScript for functions
```

**0.2 Firestore Security Rules** (`firestore.rules`)
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can only access their own data
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // Inventory is readable by authenticated users
    match /inventory/{itemId} {
      allow read: if request.auth != null;
      allow write: if request.auth.token.admin == true;
    }
    
    // Sessions belong to users
    match /sessions/{sessionId} {
      allow read, write: if request.auth != null 
        && resource.data.user_id == request.auth.uid;
      allow create: if request.auth != null 
        && request.resource.data.user_id == request.auth.uid;
    }
  }
}
```

**0.3 Firestore Indexes** (`firestore.indexes.json`)
```json
{
  "indexes": [
    {
      "collectionGroup": "sessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "user_id", "order": "ASCENDING" },
        { "fieldPath": "timestamp_start", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "inventory",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "type", "order": "ASCENDING" }
      ]
    }
  ],
  "fieldOverrides": [
    {
      "collectionGroup": "sessions",
      "fieldPath": "pleasure_vector.embedding",
      "indexes": [
        {
          "order": "ASCENDING",
          "queryScope": "COLLECTION"
        },
        {
          "arrayConfig": "CONTAINS",
          "queryScope": "COLLECTION"
        },
        {
          "order": "ASCENDING",
          "queryScope": "COLLECTION_GROUP"
        },
        {
          "dimensions": 16,
          "queryScope": "COLLECTION",
          "vectorConfig": {
            "flat": {}
          }
        }
      ]
    }
  ]
}
```

**0.4 Storage Rules** (`storage.rules`)
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Private user storage
    match /users/{uid}/private/{allPaths=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    
    // Public inventory images
    match /inventory/{allPaths=**} {
      allow read: if request.auth != null;
    }
  }
}
```

**0.5 Cloud Functions Deployment**
```bash
cd functions
npm install

# Set Gemini API key as secret
firebase functions:secrets:set GEMINI_API_KEY

# Deploy
npm run deploy
```

-----

### Phase 1: iOS Project Setup

| Task | Description |
|------|-------------|
| Create Xcode project | SwiftUI, iOS 18+, Swift 6 |
| Add Firebase SDK | SPM: firebase-ios-sdk |
| Add GoogleService-Info.plist | From Firebase Console |
| Create Models | `PleasureProfile`, `User`, `InventoryItem`, `Session` |
| Create Services | `FirebaseManager`, `GeminiService`, `SessionStateMachine` |
| Create Utilities | `PIIRedactor` (NLTagger) |

-----

### Phase 2: The Architect

| Task | Description |
|------|-------------|
| `InventoryService` | Fetch/filter inventory by location, affordances, temporal tags |
| `PlannerService` | Call `callGemini` with user state + inventory context |
| `CalendarManager` | EventKit integration for mission scheduling |
| `DashboardView` | State display, circadian context, mission cards |
| `InventoryMapView` | MapKit with clustered inventory markers |

-----

### Phase 3: The Guide

| Task | Description |
|------|-------------|
| `LiveSessionManager` | Audio recording, chunking, send to `processVoice` |
| `VisionAnalysisService` | Camera capture, compress, call `analyzeImage` |
| `GeofenceManager` | CoreLocation monitoring, inventory proximity alerts |
| `ActiveSessionView` | State-aware UI, waveform, dimension badges |
| Action Button | Map to start Drift Mode (iPhone 15 Pro+) |

-----

### Phase 4: The Scribe

| Task | Description |
|------|-------------|
| `BackgroundProcessor` | BGTaskScheduler for deferred audio uploads |
| `VectorService` | Generate 16D embedding, store with `FieldValue.vector()` |
| `InsightEngine` | Vector similarity search + Gemini pattern analysis |
| `LogBookView` | Session timeline with pleasure badges |
| `PleasureSpaceView` | Swift Charts 2D/3D projection of 16D space |

-----

### Phase 5: Testing & Polish

| Task | Description |
|------|-------------|
| Unit tests | Models, state machine transitions |
| Integration tests | Firebase Functions (emulator) |
| UI tests | Session flow, state transitions |
| Accessibility | VoiceOver, Dynamic Type |
| Performance | Optimize vector queries, image compression |

-----

### Deployment Checklist

- [ ] Firebase project created
- [ ] Firestore rules deployed
- [ ] Firestore indexes deployed  
- [ ] Storage rules deployed
- [ ] Cloud Functions deployed
- [ ] GEMINI_API_KEY secret set
- [ ] GoogleService-Info.plist in Xcode project
- [ ] App Store Connect setup
- [ ] TestFlight beta