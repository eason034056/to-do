# Phase 2 Implementation (Kickoff)

## Goal
Start implementing nightly planning flow based on the product spec:
- user submits **next local day** plan
- server/domain validates ownership and local date context
- task ordering follows required/priority/sortOrder

## Implemented in this PR
1. Repository contracts:
   - `PlanRepository`
   - `TaskRepository`
2. Planning use case:
   - `SubmitNextDayPlanUseCase`
   - Request model + validation errors
   - `PlanningWindowPolicy`
   - `LocalClockTime`
3. Validation rules covered:
   - reject empty task submissions
   - reject optional-only submissions when `noRequiredTasksConfirmed == false`
   - reject tasks not owned by current user
   - reject dateKey mismatch against computed next local day
   - reject timezone mismatch
   - reject submissions before `planningReminderTime`
   - reject submissions after `planningCutoffTime`
   - reject invalid planning window policy
4. Tests:
   - success path writes plan and sorted tasks
   - empty tasks validation
   - optional-only validation
   - reminder window boundary validation
   - wrong dateKey validation

## Next
- Add Firestore-backed repository implementations.
- Add SwiftUI planning screen wired to this use case.
