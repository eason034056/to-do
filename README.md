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

> The existing `IOS_COUPLE_TODO_APP_DEVELOPMENT_SPEC.md` remains the source of truth for product and backend rules.


## Current status
- `CoupleTodoCore` is the shared source of truth for domain models and core use cases.
- `App/` now imports `CoupleTodoCore` directly and no longer carries duplicate domain models.
- `Backend/` contains the initial Firebase project layout, callable/scheduled function names, and Firestore rules scaffold.
