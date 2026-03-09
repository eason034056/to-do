# 完整 Spec 剩餘事項總表

## Summary
- 目前已完成的只有 `CoupleTodoCore` 基礎 domain、`LocalTimeContext`、`TaskSortingService`、`SettlementEngine`、部分 nightly planning use case，App 端仍是 mock dashboard，尚未接真實資料、後端、通知、Widget、Live Activity。
- 接下來應完成的事項要按「先資料正確、再規則完整、最後系統整合」排序，否則 Widget、通知與結算畫面會反覆重寫。
- 目標範圍採「完整 spec」而不是只做 MVP，所以包含 iOS app、Firebase/Firestore/Functions、提醒系統、Widget、Live Activity、設定、測試與 TestFlight。

## 實作待辦
- Phase 0.1 架構整併：把 App 內重複的 `App/Core/Models` 與 `App/Core/Utilities` 收斂到 `CoupleTodoCore`，改成 core package 是唯一 domain source of truth。
- Phase 0.2 專案基礎：補齊 app target 依賴、Firebase SDK、bundle IDs、URL scheme、App Group、push capabilities、Widget target、Notification Service Extension、必要的 App Intents target 或 app-intents-in-app 配置。
- Phase 0.3 App 根架構：建立 `AppCoordinator`/`RootView`/route state，定義 `/auth`、`/pairing`、`/dashboard/today`、`/planning/{dateKey}`、`/settlement/{dateKey}`、`/rewards/current`、`/settings` 導覽與深連結入口。
- Phase 1.1 Auth 與配對：完成 Sign in with Apple、session persistence、使用者 profile 同步、建立 couple、invite code/link、join couple、雙人關係鎖定。
- Phase 1.2 Couple 設定：完成 couple policy 與 reminder config 的讀寫，包括 `planningReminderTime`、`planningCutoffTime`、`planningEscalationEveryMinutes`、`dailySettlementTime`、`dailySettlementGraceMinutes`、`weekStartsOn`、`penaltyAmount`、`currency`、`planningMissPenaltyEnabled`。
- Phase 1.3 Firestore schema 落地：建立 `users`、`deviceInstallations`、`couples`、`invites`、`plans`、`tasks`、`settlements`、`rewardWeeks`、`events` 對應 DTO、mapper、path constants、server timestamp handling。
- Phase 1.4 Repository 層：補齊 `UserRepository`、`CoupleRepository`、`DeviceInstallationRepository`、`SettlementRepository`、`RewardWeekRepository`、`EventRepository`，並完成 Firestore-backed `PlanRepository`、`TaskRepository`。
- Phase 1.5 Sync 與快取：實作 Firestore listeners、SwiftData cache、sync state (`local_pending` / `synced` / `server_final`)、前景更新策略與錯誤回補。
- Phase 1.6 Dashboard 真實化：用 listeners 驅動首頁，顯示自己今天、對方當地今天、雙方 required/optional、完成率、partner 是否已提交明日計畫、距結算倒數、週獎勵摘要。
- Phase 1.7 Task CRUD：完成新增、編輯、刪除、完成/取消完成、拖曳排序、optional 任務帶到隔天、owner-only 驗證、settlement finalized 後禁止改寫。
- Phase 1.8 Tomorrow Planning：完成明日規劃頁、required/optional 分區、partner submitted 狀態、提交後完成狀態、隔日 00:00 前允許再編輯、`noRequiredTasksConfirmed` UX。
- Phase 2.1 Planning 規則補齊：除了已完成的提交驗證，還要補 `planningMissed` 寫入流程、count summary 更新、partner side read model、事件紀錄、提醒狀態清除。
- Phase 2.2 Completion 規則：定義 `completedAtClient`/`completedAtServer` 的接受策略、clock skew 容忍、server-final 判定邏輯、離線補傳處理。
- Phase 2.3 Settlement domain：完成每日結算 use case、grace 邏輯、penalty policy、counterparty snapshot、settlement repository 寫入、acked state、歷史不可改寫規則。
- Phase 2.4 Reward domain：完成下週 reward draft 編輯、當週 eligibility 更新、`planningMissed` 對 eligibility 的影響、雙方 local week 關閉後的 earned/missed finalize。
- Phase 2.5 Audit/Event log：把 `task_created`、`task_updated`、`task_deleted`、`task_completed`、`task_uncompleted`、`plan_submitted`、`planning_missed`、`settlement_finalized`、`weekly_reward_drafted`、`weekly_reward_earned`、`weekly_reward_missed` 全數落地。
- Phase 2.6 Settings UI：完成提醒時間、罰則、週起始日、通知狀態檢查與修正提示。
- Phase 3.1 Callable Functions：完成 `createCouple`、`joinCouple`、`submitPlan`、`acknowledgeSettlement`、`saveNextWeekReward`，並與 iOS repositories/use cases 對齊。
- Phase 3.2 Scheduled Jobs：完成 `planningReminderJob`、`planningMissJob`、`dailySettlementJob`、`weeklyRewardFinalizeJob`、`snapshotCompactionJob`。
- Phase 3.3 Push：完成 FCM/APNs token 註冊、device capability sync、Time Sensitive payload、notification categories、remote settlement result push、local fallback reminder。
- Phase 3.4 In-app gate：完成 settlement 優先於 planning 的 full-screen gate，支援 app 前景自動彈出與 reopen blocking。
- Phase 3.5 Deep links：完成 `coupletodo://planning/{dateKey}`、`coupletodo://settlement/{dateKey}`、`coupletodo://rewards/{weekKey}` 的 router、notification tap、widget tap、live activity tap 整合。
- Phase 3.6 App Group snapshot：完成 shared snapshot DTO、snapshot writer、widget reload 策略、結算與規劃狀態同步。
- Phase 3.7 Widget：完成 small、medium、lock screen/accessory widget，顯示 required 完成數、top tasks、剩餘未完成數，並接 App Intents 快速操作。
- Phase 3.8 Live Activity：完成 `PlanningReminderActivity` 與 `DailySettlementActivity` 的 attributes、content state、啟動/更新/結束邏輯、交互入口。
- Phase 4.1 Security rules：完成 Firestore rules，限制本人只能改自己的 plans/tasks，couple members 共享讀取，settlement/reward finalize 只能 server 寫，locked day 禁止 client 改寫。
- Phase 4.2 錯誤與離線 UX：完成 network/offline 提示、衝突呈現、server-final 覆蓋策略、timezone 變更同步策略。
- Phase 4.3 驗證與運維：完成 Firebase Emulator 測試、真機通知驗證、Widget/Live Activity 真機驗證、analytics/crash logging、TestFlight 準備與 smoke checklist。

## 需要新增或補齊的核心介面
- Repository contracts 最少補齊：`UserRepository`、`CoupleRepository`、`DeviceInstallationRepository`、`SettlementRepository`、`RewardWeekRepository`、`EventRepository`。
- Domain use cases 最少補齊：`CreateCouple`、`JoinCouple`、`LoadDashboard`、`CreateTask`、`UpdateTask`、`DeleteTask`、`ReorderTasks`、`ToggleTaskCompletion`、`SubmitNextDayPlan`、`AcknowledgeSettlement`、`SaveNextWeekReward`、`FinalizeDailySettlement`、`FinalizeWeeklyReward`、`MarkPlanningMissed`。
- Shared models 最少補齊：`Couple`、`UserProfile`、`ReminderConfig`、`PenaltyPolicy`、`DeviceInstallation`、`DailySettlement`、`RewardWeek`、`EventLogEntry`、`SharedSnapshot`、兩種 Live Activity attributes/content state。
- 後端對外介面固定採 Firebase：callable functions + scheduled jobs；不要在 iOS 端自行計算最終 settlement/reward 結果後直接當真實來源。
- Widget 與 Live Activity 只能讀 App Group snapshot 或 server-driven state，不直接把 Firestore 查詢當主資料來源。

## 測試與驗收
- Unit tests 必測：排序、required/optional、planning cutoff、settlement grace、penalty、reward eligibility、planning missed、跨時區 dateKey/weekKey、時區切換。
- Integration tests 必測：`createCouple`、`joinCouple`、`submitPlan`、`dailySettlementJob`、`weeklyRewardFinalizeJob`、security rules、device installation sync。
- UI tests 必測：任務 CRUD、明日規劃提交、深連結進 settlement、前景 full-screen settlement、自動 gate、rewards 編輯限制。
- 真機驗收必測：APNs/FCM、Time Sensitive、Live Activity 啟停、Widget interaction、background 更新、notification tap routing。
- 完成定義：真實 Firestore + emulator + 真機通知鏈路跑通，首頁/規劃/結算/獎勵/設定五個主流程都不再依賴 mock data。

## Assumptions
- 後端維持 spec 的 Firebase + TypeScript Cloud Functions，不改成 Vapor。
- 先完成資料模型、rules、repositories、dashboard/planning/settlement/reward 主流程，再做 Widget 與 Live Activity 的互動細節。
- `CoupleTodoCore` 會成為 app、widget、測試共用的唯一 domain module；不再長期保留 App 內 duplicate models。
- 分支策略沿用 `docs/BRANCHING_PLAN.md`，以功能群拆 PR，基底分支為 `dev`。
