# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**月舒 (WomenMoon)** — iOS women's health app combining cycle tracking, nutrition, exercise, emotion logging, medical records, and TCM seasonal wellness. AI-powered via DeepSeek API.

- **Platform:** iOS 17.0+
- **Language:** Swift 5.9
- **UI:** SwiftUI
- **Persistence:** SwiftData (all models are `@Model` classes)
- **Build system:** XcodeGen (`project.yml` → `.xcodeproj`)

## Build & Run

```bash
# Generate Xcode project from project.yml (required after file adds/deletes)
xcodegen generate

# Then open WomenMoon.xcodeproj in Xcode and build/run normally
```

The app target is `WomenMoon`, bundle ID `com.womenmoon.app`. The scheme defines a `DEEPSEEK_API_KEY` environment variable for debug runs.

There are no test targets configured yet.

## Architecture

### Data Layer (SwiftData `@Model` classes in [Models/](Models/))

All models use `@Model` with SwiftData. The schema is registered in `WomenMoonApp.swift`:

- **`UserProfile`** — Single-user profile (name, birthDate, cycleLength/periodLength/lutealLength, goals, height, activityLevel). Cycle phase is a computed property on the model.
- **`CycleRecord`** — One record per cycle start, with symptoms, flow intensity, phase. `isPredicted` flag distinguishes real from forecasted records.
- **`HealthMetric`** — Point-in-time measurements (weight, bodyFat, waist, hip, etc.) with `source` (manual vs HealthKit).
- **`FoodItem`** / **`MealRecord`** — Food database items (per-100g nutrition) and meal logs (FoodEntry array with per-meal gram amounts). `FoodEntry` is a Codable struct embedded in MealRecord.
- **`EmotionRecord`** — Mood (1-5 scale) + emotion tags, optionally linked to cycle phase/day.
- **`ExercisePlan`** — Daily exercise schedule with multiple `Exercise` structs, keyed to cycle phase. Has static `recommended(for:)` that returns phase-specific workouts.
- **`MedicalRecord`** — Medical visit records with optional AI analysis and image attachments.
- **`SupplementRecord`** — Supplement intake log with time-of-day and cycle phase association.

### Services ([Services/](Services/))

All services are singletons or static structs:

- **`HealthKitService`** (singleton, `@MainActor`) — Reads/writes HealthKit: menstrual flow, body mass, step count, sleep analysis. Converts HK samples to app model types.
- **`AIService`** (singleton) — DeepSeek API client (OpenAI-compatible chat completions). Methods: `analyzeNutrition()`, `interpretBodySignal()`, `analyzeEmotion()`, `chat()`, `analyzeMedicalRecord()`, `getDailyDietAdvice()`. Handles JSON extraction from markdown-wrapped responses. API key sourced from env var `DEEPSEEK_API_KEY` or Keychain.
- **`CycleCalculator`** (static struct) — Cycle math: predict next start, ovulation day, fertility window, phase determination from day-of-cycle, generate 3-month predictions.
- **`NutritionCalculator`** (static struct) — BMR (Mifflin-St Jeor), TDEE, calorie targets by goal, macro splits, cycle-adjusted nutrition (extra iron in menstrual, extra magnesium/B6 in luteal).
- **`CloudKitService`** (singleton, `@MainActor`) — iCloud sync for custom food items and supplement records. Container: `iCloud.com.womenmoon.app`. Only syncs non-sensitive data.
- **`SeasonalWellnessService`** (static struct) — 24 solar terms (节气) lookup and wellness advice. Delegates to `SeasonalTerms` data engine.

### App State & Routing

- **`AppState`** (`@MainActor` `ObservableObject`) — Global state: onboarding flag, current cycle phase, user name/goals. Persisted via `UserDefaults` for `isOnboarded`.
- **`ContentView`** — Root view: shows `OnboardingView` or `MainTabView` based on `isOnboarded` and whether a `UserProfile` exists.
- **`MainTabView`** — 5-tab layout: Home, Cycle, Nutrition, Exercise, AI Assistant. Each tab wrapped in its own `NavigationStack`.

### Enums & Types ([Utils/Constants.swift](Utils/Constants.swift))

Central type definitions file — all enums live here:
- `CyclePhase` (menstrual/follicular/ovulatory/luteal) with icon and color
- `Goal`, `ActivityLevel`, `MetricType`, `DataSource`, `MealType`
- `Mood` (1-5 with emoji), `EmotionTag`, `Symptom`, `Intensity`, `TimeOfDay`
- `FoodCategory`, `MedicalCategory`
- `Constants` — API base URL, model name, default cycle/nutrition values

### Key Dependencies & External Integration

- **DeepSeek API** at `https://api.deepseek.com/v1` using model `deepseek-chat`. API key stored in Keychain (`KeychainHelper` in [Views/Settings/SettingsView.swift](Views/Settings/SettingsView.swift)) or env var.
- **HealthKit** — reads steps, heart rate, sleep, menstrual flow, body mass, body fat %, height. Writes menstrual flow, body mass, body fat %.
- **CloudKit** — container `iCloud.com.womenmoon.app`, used for custom food items and supplement sync only.
- **KeychainHelper** — defined in [Views/Settings/SettingsView.swift](Views/Settings/SettingsView.swift), used by `Constants.aiAPIKey` and `APIKeySettingsView`.

### 24 Solar Terms (节气) Data

[Utils/SeasonalTerms.swift](Utils/SeasonalTerms.swift) contains a hardcoded database of all 24 solar terms with diet/lifestyle/exercise recommendations and seasonal foods, following TCM principles. Dates are approximate (1-2 day annual variation). Currently hardcoded for 2026-2027.

### Color System

[Utils/ColorExtensions.swift](Utils/ColorExtensions.swift) defines named colors: `womenMoonPink` (#E91E63), `womenMoonPurple` (#9C27B0), and per-phase colors. A `Color(hex:)` initializer is defined in `ContentView.swift`.

## Patterns & Conventions

- Views use `@EnvironmentObject private var appState: AppState` for global state
- Views use `@Query` for SwiftData fetching, `@Environment(\.modelContext)` for writes
- Services use async/await throughout; HealthKit callbacks are bridged via `withCheckedThrowingContinuation`
- `@MainActor` on ObservableObject services that publish UI state
- All Chinese UI strings are inline (no localization files yet)
- `FoodDatabase.json` in Resources contains preloaded food items
- The `ViewModels/` directory exists but is currently empty — view logic lives in Views
