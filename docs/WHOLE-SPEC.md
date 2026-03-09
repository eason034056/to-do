# 完整 Spec 進度總表

## 狀態說明
- `[x]` 已完成
- `[~]` 部分完成
- `[ ]` 尚未完成

## Summary
- `[x]` `CoupleTodoCore` 已成為 shared source of truth，涵蓋 domain models、time context、sorting、planning / dashboard / settlement / reward / task mutation use cases。
- `[~]` `App/` 已經有 routed SwiftUI shell、deep link、dashboard / planning / settlement / rewards / settings 畫面，以及 demo task/planning CRUD，但目前仍是 in-memory environment，不是真實 Firestore。
- `[~]` Firestore schema layer 與 Firestore-style repository implementations 已完成到 document-store boundary；Firebase SDK adapter 與真實 listener/sync 尚未接上。
- `[~]` `Backend/` 已有 Firebase Functions / scheduler / rules 的 skeleton，但沒有真正業務邏輯。
- `[ ]` 通知、Widget、Live Activity、SwiftData cache、真機驗證、TestFlight 都還沒開始進入可交付狀態。

## 實作待辦
- `[x]` Phase 0.1 架構整併：App 內重複的 `App/Core/Models` 與 `App/Core/Utilities` 已收斂到 `CoupleTodoCore`。
- `[~]` Phase 0.2 專案基礎：已補 `project.yml`、URL scheme、App Group entitlements、支援檔與 Xcode project；Firebase SDK、push capabilities、Widget target、Notification Service Extension、Live Activity target 尚未完成。
- `[~]` Phase 0.3 App 根架構：`AppCoordinator` / `RootView` / route state / deep link router 已完成，但仍依賴 demo environment。
- `[~]` Phase 1.1 Auth 與配對：`CreateCouple` / `JoinCouple` core use cases 已完成；Sign in with Apple、session persistence、真實 invite/join flow 與 couple lock 尚未完成。
- `[~]` Phase 1.2 Couple 設定：config model 與 settings UI 已完成，couple policy 可在 demo repo 內寫回；真實後端同步與通知設定整合尚未完成。
- `[x]` Phase 1.3 Firestore schema 落地：`users`、`deviceInstallations`、`couples`、`invites`、`plans`、`tasks`、`settlements`、`rewardWeeks`、`events` 的 path constants、DTO、domain mapper、server timestamp write payload 已完成。
- `[~]` Phase 1.4 Repository 層：repository contracts、in-memory repositories，以及建基於 Firestore DTO/path 的 concrete repositories 已完成；最後一層 Firebase SDK adapter 與 app wiring 尚未完成。
- `[ ]` Phase 1.5 Sync 與快取：Firestore listeners、SwiftData cache、sync state、前景更新策略與錯誤回補尚未完成。
- `[~]` Phase 1.6 Dashboard 真實化：dashboard 已顯示雙方 local day、required/optional、planning status、settlement、reward 摘要；但仍不是 listener-driven，也不是 Firestore-backed。
- `[~]` Phase 1.7 Task CRUD：新增、編輯、刪除、完成/取消完成、同 bucket+priority 內重排序、owner-only validation 已完成；optional 帶到隔天與 settlement finalized 後禁止改寫尚未完成。
- `[~]` Phase 1.8 Tomorrow Planning：明日規劃頁、required/optional 分區、partner submitted 狀態、`noRequiredTasksConfirmed` UX、提交 use case 已完成；隔日 00:00 前再編輯規則與真實後端同步尚未完成。
- `[~]` Phase 2.1 Planning 規則補齊：planning window validation、submit metadata、`planningMissed` use case、事件紀錄已完成；partner-side read model、count summary sync、提醒狀態清除尚未完成。
- `[ ]` Phase 2.2 Completion 規則：`completedAtClient` / `completedAtServer` 欄位與基本 toggle 流程已存在，但 clock skew、server-final、離線補傳策略尚未實作。
- `[~]` Phase 2.3 Settlement domain：每日結算 use case、grace、penalty、counterparty snapshot、ack flow 已完成；歷史不可改寫與 server-authoritative finalize 流程尚未完成。
- `[~]` Phase 2.4 Reward domain：下週 reward draft 編輯、eligibility 更新、earned/missed finalize use cases 已完成；真實 backend finalize 與跨裝置同步尚未完成。
- `[~]` Phase 2.5 Audit/Event log：event types、event appending、task/planning/settlement/reward 事件入口已完成；Firestore audit log 與查詢整合尚未完成。
- `[~]` Phase 2.6 Settings UI：提醒時間、罰則、週起始日 UI 已完成；通知權限檢查與修正提示尚未完成。
- `[~]` Phase 3.1 Callable Functions：`createCouple`、`joinCouple`、`submitPlan`、`acknowledgeSettlement`、`saveNextWeekReward` skeleton 已建立；實作邏輯尚未完成。
- `[~]` Phase 3.2 Scheduled Jobs：`planningReminderJob`、`planningMissJob`、`dailySettlementJob`、`weeklyRewardFinalizeJob`、`snapshotCompactionJob` skeleton 已建立；實作邏輯尚未完成。
- `[ ]` Phase 3.3 Push：FCM/APNs token 註冊、device capability sync、Time Sensitive payload、notification categories、remote push/local fallback 尚未完成。
- `[~]` Phase 3.4 In-app gate：settlement / planning full-screen gate 在 demo shell 已有，但前景自動彈出、reopen blocking、push/notification 觸發整合尚未完成。
- `[~]` Phase 3.5 Deep links：`coupletodo://planning/{dateKey}`、`coupletodo://settlement/{dateKey}`、`coupletodo://rewards/{weekKey}` router 已完成；notification / widget / live activity tap 尚未整合。
- `[~]` Phase 3.6 App Group snapshot：shared snapshot DTO 與 writer 已完成；widget reload 策略與狀態同步尚未完成。
- `[ ]` Phase 3.7 Widget：small / medium / accessory widget 與 App Intents 尚未完成。
- `[ ]` Phase 3.8 Live Activity：`PlanningReminderActivity` 與 `DailySettlementActivity` target wiring / lifecycle 尚未完成。
- `[~]` Phase 4.1 Security rules：Firestore rules scaffold 已建立；本人寫入限制、server-only finalize、locked day 等完整規則尚未完成。
- `[ ]` Phase 4.2 錯誤與離線 UX：network/offline 提示、衝突呈現、server-final 覆蓋策略、timezone 變更同步策略尚未完成。
- `[ ]` Phase 4.3 驗證與運維：Firebase Emulator、真機通知、Widget/Live Activity 真機驗證、analytics/crash logging、TestFlight 準備尚未完成。

## 需要新增或補齊的核心介面
- `[x]` Repository contracts：`UserRepository`、`CoupleRepository`、`DeviceInstallationRepository`、`SettlementRepository`、`RewardWeekRepository`、`EventRepository` 已完成。
- `[x]` Domain use cases：`CreateCouple`、`JoinCouple`、`LoadDashboard`、`CreateTask`、`UpdateTask`、`DeleteTask`、`ReorderTasks`、`ToggleTaskCompletion`、`SubmitNextDayPlan`、`AcknowledgeSettlement`、`SaveNextWeekReward`、`FinalizeDailySettlement`、`FinalizeWeeklyReward`、`MarkPlanningMissed` 已完成。
- `[x]` Shared models：`Couple`、`UserProfile`、`ReminderConfig`、`PenaltyPolicy`、`DeviceInstallation`、`DailySettlement`、`RewardWeek`、`EventLogEntry`、`SharedSnapshot`、兩種 Live Activity content state 已完成。
- `[x]` 後端對外介面方向已固定採 Firebase：目前 skeleton 與文件都依此路線建立。
- `[ ]` Widget 與 Live Activity 僅讀 App Group snapshot / server-driven state 的完整資料鏈路尚未完成。

## 測試與驗收
- `[~]` Unit tests：已覆蓋排序、planning cutoff、settlement、reward、couple lifecycle、task mutation、跨時區 local context、Firestore mapping；仍缺 planning missed、更多 completion edge cases、時區切換等。
- `[ ]` Integration tests：`createCouple`、`joinCouple`、`submitPlan`、scheduled jobs、security rules、device installation sync 尚未建立。
- `[ ]` UI tests：任務 CRUD、明日規劃提交、深連結、full-screen settlement gate、rewards 編輯限制 尚未建立。
- `[ ]` 真機驗收：APNs/FCM、Time Sensitive、Live Activity、Widget interaction、background 更新、notification tap routing 尚未驗證。
- `[ ]` 完成定義：真實 Firestore + emulator + 真機通知鏈路尚未跑通，首頁/規劃/結算/獎勵/設定五個主流程仍未脫離 demo data。

## Assumptions
- 後端維持 spec 的 Firebase + TypeScript Cloud Functions，不改成 Vapor。
- 先完成資料模型、rules、repositories、dashboard/planning/settlement/reward 主流程，再做 Widget 與 Live Activity 的互動細節。
- `CoupleTodoCore` 會成為 app、widget、測試共用的唯一 domain module；不再長期保留 App 內 duplicate models。
- 分支策略沿用 `docs/BRANCHING_PLAN.md`，目前實作仍以功能群拆分。
