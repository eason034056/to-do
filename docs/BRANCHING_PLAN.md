# Branching Plan (target base: `dev`)

## 1) Integration branch
- `dev`: integration branch for all features.

## 2) Feature branches
- `feature/project-bootstrap`: SwiftUI app skeleton, core models, local time context.
- `feature/auth-couple-onboarding`: Auth, invite/join flow, couple binding.
- `feature/daily-planning`: nightly planning, required/optional task creation.
- `feature/dashboard-cross-timezone`: dual-date dashboard (self today + partner today).
- `feature/daily-settlement`: daily settlement engine + penalty presentation.
- `feature/weekly-reward`: reward input (N-1 week) + earned/missed lifecycle.
- `feature/notifications-live-activity`: Time Sensitive push + Live Activity states.
- `feature/widget-home-surface`: widget snapshot rendering for key statuses.
- `feature/firestore-sync`: Firestore repositories, data mapping, conflict policy.
- `feature/rules-audit-log`: immutable event log for plan/task edits.
- `feature/settings`: notification windows, penalty amount/currency, week start.

## 3) PR policy
- Every feature branch opens a PR **into `dev`**.
- Keep each PR focused on one feature group.
- Include smoke-test evidence in PR body.
