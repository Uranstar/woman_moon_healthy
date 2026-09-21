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

`xcodegen` is not installed by default. Install with `brew install xcodegen`, or run
`xcodegen generate` must be re-run **every time a file is added, renamed, or deleted** —
the `.xcodeproj` is generated from `project.yml` and will silently omit new files otherwise.

The app target is `WomenMoon`, bundle ID `com.womenmoon.app`. The scheme defines a `DEEPSEEK_API_KEY` environment variable for debug runs.

For physical devices, set `DEVELOPMENT_TEAM` in `project.yml` (currently empty).

### Tests

Unit test target `WomenMoonTests`, sources in [Tests/](Tests/):

```bash
xcodebuild test -scheme WomenMoon \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:WomenMoonTests
```

Coverage: `CycleCalculator` (cycle math, phase boundaries, short-cycle crash regressions),
`NutritionCalculator` (BMR/TDEE/macros), `UserProfile` (BMI regression).

## Architecture

### Data Layer (SwiftData `@Model` classes in [Models/](Models/))

All models use `@Model` with SwiftData. The schema is registered in `WomenMoonApp.swift`:

- **`UserProfile`** — Single-user profile (name, birthDate, cycleLength/periodLength/lutealLength, goals, height, activityLevel). Cycle phase is a computed property on the model.
- **`CycleRecord`** — One record per cycle start, with symptoms, flow intensity, phase. `isPredicted` flag distinguishes real from forecasted records.
- **`CycleEvent`** — Per-day cycle observations (cervical mucus, ovulation test, BBT, free-form notes), typed by `CycleEventType`.
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
- **`CycleCalculator`** (static struct) — Cycle math: predict next start, ovulation day, fertility window, phase determination from day-of-cycle, generate 3-month predictions. `currentPhase(from:...to:)` takes an explicit `to:` date so it is unit-testable.
- **`CycleService`** (`@MainActor` class) — Write path for cycle data: records periods, regenerates predictions, saves day-level `CycleEvent`s, computes average cycle/period length from real records. Instantiated per call (not a singleton).
- **`NutritionCalculator`** (static struct) — BMR (Mifflin-St Jeor), TDEE, calorie targets by goal, macro splits, cycle-adjusted nutrition (extra iron in menstrual, extra magnesium/B6 in luteal).
- **`CloudKitService`** (singleton, `@MainActor`) — iCloud sync for custom food items and supplement records. Container: `iCloud.com.womenmoon.app`. Only syncs non-sensitive data.
- **`SeasonalWellnessService`** (static struct) — 24 solar terms (节气) lookup and wellness advice. Delegates to `SeasonalTerms` data engine.

### App State & Routing

- **`AppState`** (`@MainActor` `ObservableObject`) — Global state: onboarding flag, current cycle phase, user name/goals, and `storageWarning` (set when SwiftData has fallen back to in-memory storage). Persisted via `UserDefaults` for `isOnboarded`.
- **`StorageBootstrap`** ([WomenMoonApp.swift](WomenMoonApp.swift)) — Builds the `ModelContainer`. Returns `.persistent` or `.volatile(container, reason)`; on disk failure it logs the real error, keeps the **full** schema in the in-memory fallback, and surfaces the reason to the UI. Never silently discards user data.
- **`ContentView`** — Root view: a red banner when `storageWarning` is set, then `OnboardingView` or `MainTabView` based on `isOnboarded` and whether a `UserProfile` exists.
- **`MainTabView`** — 5-tab layout: Home, Cycle, Nutrition, Exercise, Profile. Each tab wrapped in its own `NavigationStack`.

### 周期阶段的判定口径

**只有一处真源：`CycleCalculator.currentPhase(from:cycleLength:periodLength:lutealLength:to:)`。**
`Date.cyclePhase(...)` 是薄封装，直接委托给它。不要在别处另写一套阶段边界 ——
历史上一度存在两套口径（一套硬编码 13/14/16/17 天，一套参数化），结果不一致。

实现上使用 `if/else` 比较而非 `switch` + `ClosedRange`：短周期下
`case (periodLength+1)...(cycleLength-lutealLength-1)` 会构造出下界大于上界的 Range 并崩溃
（周期 15–29 天在特定经期/黄体期长度下均会触发）。`Tests/CycleCalculatorTests.swift` 有回归用例。

### Enums & Types ([Utils/Constants.swift](Utils/Constants.swift))

Central type definitions file — all enums live here:
- `CyclePhase` (menstrual/follicular/ovulatory/luteal) with icon and color
- `Goal`, `ActivityLevel`, `MetricType`, `DataSource`, `MealType`
- `Mood` (1-5 with emoji), `EmotionTag`, `Symptom`, `Intensity`, `TimeOfDay`
- `FoodCategory`, `MedicalCategory`
- `Constants` — API base URL, model name, default cycle/nutrition values

### Key Dependencies & External Integration

- **DeepSeek API** at `https://api.deepseek.com/v1`. Model name lives in `Constants.aiModel`
  (currently `deepseek-v4-flash`) — do not hardcode it elsewhere. API key stored in Keychain
  (`KeychainHelper` in [Views/Settings/SettingsView.swift](Views/Settings/SettingsView.swift)) or env var.
- **HealthKit** — reads steps, heart rate, sleep, menstrual flow, body mass, body fat %, height. Writes menstrual flow, body mass, body fat %.
- **CloudKit** — container `iCloud.com.womenmoon.app`. **Not wired up yet**: nothing calls
  `CloudKitService`, and `WomenMoon.entitlements` declares HealthKit only — no iCloud
  container identifiers. Enabling it requires creating the container in App Store Connect
  and adding the iCloud entitlements. The `CKContainer` is created lazily so that the
  missing capability cannot crash the app at launch.
- **KeychainHelper** — defined in [Views/Settings/SettingsView.swift](Views/Settings/SettingsView.swift), used by `Constants.aiAPIKey` and `APIKeySettingsView`.

### 24 Solar Terms (节气) Data

[Utils/SeasonalTerms.swift](Utils/SeasonalTerms.swift) holds the TCM wellness content for all
24 terms (diet/lifestyle/exercise/seasonal foods), but **dates are computed astronomically**,
not stored: the engine solves for the moment the Sun's apparent longitude (Meeus simplified
formula) reaches each 15° multiple, scanning for the crossing then bisecting to sub-second
precision. Results are cached per year and judged in Asia/Shanghai time.

Consequences worth knowing:
- Any year works — verified 2027/2030/2035/2050 return a full 24 terms.
- The term switches by **calendar day**, not by exact instant. 小寒 2026 lands at 16:19, and
  the whole of Jan 5 counts as 小寒 — otherwise the app would show "冬至" on the morning of
  the 5th, which no user expects.
- `currentTermName(for:)` merges the previous year's terms, because roughly 4 days each
  January (before 小寒) belong to the previous year's 冬至.
- The old hardcoded table was also simply wrong in places: 2026 大暑 is 7-23 03:12 (table said
  7-22), 雨水 is 2-18 (table said 2-19).

### Color System

[Utils/ColorExtensions.swift](Utils/ColorExtensions.swift) defines named colors: `womenMoonPink` (#E91E63), `womenMoonPurple` (#9C27B0), and per-phase colors. A `Color(hex:)` initializer is defined in `ContentView.swift`.

## Patterns & Conventions

- Views use `@EnvironmentObject private var appState: AppState` for global state
- Views use `@Query` for SwiftData fetching, `@Environment(\.modelContext)` for writes
- Services use async/await throughout; HealthKit callbacks are bridged via `withCheckedThrowingContinuation`
- `@MainActor` on ObservableObject services that publish UI state
- All Chinese UI strings are inline (no localization files yet)
- `FoodDatabase.json` in Resources holds 118 built-in foods. It is imported on first launch by
  `FoodSeeder.seedIfNeeded`, which only runs when the library is empty so it never overwrites
  user-created entries. **The `category` field uses English keys** (`staple`, `meat`, …) while
  `FoodCategory.rawValue` is the Chinese display name — resolve via `FoodCategory(seedKey:)`,
  never `FoodCategory(rawValue:)`.
- The `ViewModels/` directory exists but is currently empty — view logic lives in Views.
  `CycleTrackerView` (627 lines) and `HomeView` (479 lines) are the main candidates for extraction.
