# Couple To-Do

Foundation baseline for the iOS couple to-do app.

## What is included
- Swift Package core module: `CoupleTodoCore`
- Expanded domain models for users/couples/tasks/plans/settlement/reward/events/shared snapshot
- Local timezone/day/week context utility
- Task sorting service (required > optional, then priority/order)
- Use cases for planning, dashboard loading, couple lifecycle, settlement, rewards, and task mutation
- SwiftUI app shell with routing, deep links, planning/settlement/rewards/settings surfaces
- Demo in-memory repositories that make the app shell runnable without Firebase
- Backend skeleton under `Backend/` for Firebase Functions and Firestore rules

## Run tests
```bash
swift test
```

## Open in Xcode
```bash
xcodegen generate
open CoupleTodo.xcodeproj
```

### Firebase `GoogleService-Info.plist` (required for real auth / Firestore)

This repo does **not** commit `App/GoogleService-Info.plist` because it contains project-specific keys. Each developer and CI must add their own file:

1. In [Firebase Console](https://console.firebase.google.com), open your project → Project settings → Your apps → download **GoogleService-Info.plist** for the iOS app with bundle ID `com.coupletodo.app`.
2. Place it at `App/GoogleService-Info.plist` (same folder as the example).
3. You can start from the template: `cp App/GoogleService-Info.plist.example App/GoogleService-Info.plist` and replace every `YOUR_*` placeholder with values from the downloaded file.

If an API key was ever committed to git, **rotate it** in Google Cloud Console (APIs & Services → Credentials) and download a fresh plist from Firebase.

> The existing `IOS_COUPLE_TODO_APP_DEVELOPMENT_SPEC.md` remains the source of truth for product and backend rules.


## Current status
- `CoupleTodoCore` is the shared source of truth for domain models and core use cases.
- `App/` now imports `CoupleTodoCore` directly and no longer carries duplicate domain models.
- `Backend/` contains the initial Firebase project layout, callable/scheduled function names, and Firestore rules scaffold.
