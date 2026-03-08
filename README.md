# Couple To-Do

Phase 1 baseline for the iOS couple to-do app.

## What is included
- Swift Package core module: `CoupleTodoCore`
- Domain models for tasks/plans/settlement/reward
- Local timezone/day/week context utility
- Task sorting service (required > optional, then priority/order)
- Unit tests for cross-timezone date/week logic and task ordering

## Run tests
```bash
swift test
```

## Open in Xcode
```bash
open Package.swift
```

> The existing `IOS_COUPLE_TODO_APP_DEVELOPMENT_SPEC.md` remains the source of truth for product and backend rules.


## Phase 2 status
- Planning domain kickoff implemented: repository protocols and `SubmitNextDayPlanUseCase`.
- See `docs/PHASE2_IMPLEMENTATION.md` for details and next steps.
