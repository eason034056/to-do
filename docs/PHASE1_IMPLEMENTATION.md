# Phase 1 Implementation (Completed)

## Scope
- Build a testable baseline instead of UI-only placeholders.
- Establish deterministic local-time utilities for cross-timezone behavior.
- Add automated tests as merge gate.

## Delivered
1. `CoupleTodoCore` package target.
2. Domain models with timezone-aware fields.
3. `LocalTimeContextFactory` for `dateKey/weekKey/offset` generation.
4. `TaskSortingService` implementing required ordering rules from spec.
5. Unit tests validating timezone conversion and sorting behavior.

## Next (Phase 2)
- Add repository layer protocol (`PlanRepository`, `TaskRepository`).
- Add nightly planning use case + input validation.
- Keep PR target as `dev` per branching plan.
