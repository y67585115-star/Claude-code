# Ironlog

A minimal, dark workout tracker for **iPhone, iPad and Mac**, built with SwiftUI, SwiftData and Swift Charts. Data syncs automatically across all three through iCloud (CloudKit).

## Features

| | |
|---|---|
| **Routines** | Unlimited routines, each with its own exercises (and a target set count). Reorder by drag. |
| **Logging** | Sets × reps × weight only. Exercise names come from the routine. Each set is pre-filled with what you lifted last time ("Last: 60 × 8, 62.5 × 6"). |
| **Rest timer** | Starts when you tick off a set. −15 / +15 / Skip, with haptics when it ends. Default length is in Settings. |
| **Workout timer** | Starts on **Start workout** and is saved with the session. Survives app restarts, since it's stored as a start time. |
| **Streak** | Counts completed workouts in a row. Give each routine planned days. Missing a planned day resets the streak; rest days never do, and today is never counted as missed. |
| **Progress photos** | Multiple photos per day, each tagged with a date you can change later. Tap **Compare** and pick any two photos to see them side by side. |
| **Bodyweight** | Log entries and see a trend chart. The latest value shows on the home screen. |
| **Charts** | Top-set weight over time for every exercise (1M / 3M / 6M / 1Y / All), with PR points highlighted. |
| **Personal bests** | A toast appears the moment you beat your previous top weight for an exercise. PRs are flagged in history and charts. |
| **History** | Past sessions grouped by month: duration, sets, volume, and every set's weight and reps. |

Not included, as requested: voice control and reminders.

## Requirements

- Xcode 16 or later
- iOS / iPadOS 17+, macOS 14+

## Setup

1. Open `Ironlog.xcodeproj`.
2. Select the **Ironlog** target → *Signing & Capabilities*:
   - Choose your **Team**.
   - Change the **Bundle Identifier** from `com.example.ironlog` to your own, e.g. `com.yourname.ironlog`.
   - Under **iCloud**, replace the container `iCloud.com.example.ironlog` with `iCloud.<your bundle id>` and let Xcode create it. It lives in `Config/Ironlog-iOS.entitlements` and `Config/Ironlog-macOS.entitlements`; both must use the same container.
3. Pick a run destination (an iPhone, an iPad, or *My Mac*) and press Run.

Sync needs every device signed in to the same Apple Account with iCloud Drive turned on. Without iCloud the app still runs on local storage.

> Before shipping to the App Store, open the CloudKit Console and **Deploy Schema Changes** to Production.

## Project layout

```
Ironlog/
  IronlogApp.swift            App entry, CloudKit-backed ModelContainer
  Models/Models.swift         Routine, RoutineExercise, WorkoutSession, SetEntry, BodyweightEntry, ProgressPhoto
  Logic/
    WorkoutService.swift      Start / prefill / add set / finish / discard
    PersonalBests.swift       Live PR check + full PR recompute
    Streak.swift              Schedule-aware streak
    RestTimer.swift           Rest timer + workout presentation state
    ImageUtil.swift           HEIC/JPEG downscaling, thumbnails
    Format.swift
  Views/
    RootView.swift            Tabs on iPhone, sidebar on iPad and Mac
    Workouts/                 Home, routine editor, active workout, summary, settings
    History/                  Session list and detail
    Progress/                 Exercise charts, PRs, bodyweight
    Photos/                   Grid, add, detail, side-by-side compare
Config/                       Info.plist (background sync) and per-platform entitlements
```

The project uses Xcode 16's folder-synced groups, so any file added under `Ironlog/` is compiled automatically.
