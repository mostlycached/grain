# grain

A Hedonic Operating System for iOS.

## Overview

**grain** is designed to systematically discover, catalog, and guide you through new modes of pleasure using principles of phenomenology and Barthesian philosophy.

## Architecture

The system consists of three integrated modules:

1. **The Architect** — Planning, Inventory Management (NYC + Personal), and Logistics
2. **The Guide** — Real-time, voice-first somatic coaching and navigation
3. **The Scribe** — Passive logging, vector embedding, and insight generation

## 16 Pleasure Dimensions

grain uses a compositional model of pleasure with 16 dimensions:

### Spatial/Environmental
- **Order** — Satisfaction from structure, organization
- **Enclosure** — Preference for contained vs. expansive spaces
- **Path** — Joy in route-finding, directed movement
- **Horizon** — Drawn to vistas, big-picture views

### Cognitive/Existential
- **Anxiety** — Tolerance/appetite for productive tension
- **Ignorance** — Comfort with not-knowing, mystery
- **Repetition** — Pleasure in ritual, recurrence

### Temporal
- **Post** — Appreciation of aftermath, reflection

### Embodied
- **Food** — Gustatory pleasure sensitivity
- **Mobility** — Kinesthetic joy, movement
- **Erotic Uncertainty** — Attraction to ambiguous intimacy
- **Material Play** — Tactile exploration, making

### Relational/External
- **Power** — Agency, influence, mastery over
- **Nature Mirror** — Resonance with natural systems
- **Serendipity Following** — Openness to chance encounters
- **Anchor Expansion** — Building from stable points outward

## Tech Stack

- **Platform:** iOS 18+ (Swift 6, SwiftUI)
- **Backend:** Firebase (Auth, Firestore, Storage)
- **AI:** Google Gemini 2.0 Flash (Live API for voice, standard API for vision)
- **Privacy:** On-device PII redaction via Apple NLTagger

## Setup

1. Add your `GoogleService-Info.plist` to the project
2. Set `GEMINI_API_KEY` environment variable
3. Build and run on iOS 18+ device

## State Machine

```
idle → drift ↔ mastery ↔ social_sync → reflection → idle
```

## License

See LICENSE file.
