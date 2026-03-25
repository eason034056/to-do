# 完整 App 實作缺口報告

更新日期: 2026-03-25

本報告以目前 repo 為基準，對照 `IOS_COUPLE_TODO_APP_DEVELOPMENT_SPEC.md` 列出剩餘工作。用途只有一個: 讓你直接看出離完整 app 還剩多少步驟、每一步缺什麼、哪些地方已經不是從零開始。

## Summary

- Step 1 到 Step 12 已落地到程式碼: baseline 紅燈修正、真實 auth/pairing、Firestore schema/repository、同步策略、planning/settlement/payment/reward/settings 流程、backend callable/jobs、裝置同步/通知/deep link、Widget/Live Activity/App Intents 全部已串起。
- App 目前已接入 `AppEnvironment.live()`、`FirebaseAppServices`、`FirebaseAppleAuthenticationService`、`UserProfileBootstrapper`，並新增 settlement/payment/history 與 rewards/settings 強化流程。
- 新增 `FirebaseMessaging` 整合、APNs/FCM token 同步、notification categories 註冊、foreground gate 行為、Live Activity lifecycle、Widget extension、App Intents。
- Backend Functions 已補齊 `submitPlan`、`acknowledgeSettlement`、`saveNextWeekReward`、`markPaymentPaid` 與 5 個 scheduler jobs（含 push dedupe）。
- 最新 backend 驗證: `cd Backend/functions && npm run build` 成功。

## 已完成基礎

- `CoupleTodoCore` 已建立主要 domain models、repository protocols、`LocalTimeContext`、`SettlementEngine`。
- 已有 use cases: `LoadDashboard`、`SubmitNextDayPlan`、task mutation、`AcknowledgeSettlement`、`FinalizeDailySettlement`、reward draft/finalize、couple lifecycle。
- SwiftUI app shell 已有 `RootView`、`AppCoordinator`、Dashboard、Planning、Settlement、Rewards、Settings、deep link router。
- Firebase app 啟動已接入 `FirebaseApp.configure()`，Firestore rules 也有初步 scaffold。
- App Group snapshot writer 已存在，可把 dashboard 摘要寫成共享 JSON。

## 目前狀態總覽

| 區塊 | 狀態 | 現況 | 主要缺口 |
| --- | --- | --- | --- |
| Spec | 完成 | 主 spec 可直接做開發依據 | 之後只需隨實作更新 |
| Core domain | 完成 Step 1-12 可用範圍 | 新增 payment use cases、planning re-edit 截止、task settlement lock、dashboard countdown/pending payments、EventLogType 補齊 settlement_acknowledged/payment_marked_paid | Step 13 的離線衝突體驗仍待補齊 |
| App shell | 完成 Step 1-12 範圍 | settlement gate 強制、Settlement History、Payment Acknowledgement、carry-over、settings/rewards 強化、同步循環、foreground gate、notification permission request、Live Activity lifecycle、App Intents routing | 無主要缺口 |
| Firebase data layer | 已完成基礎層 | Firestore path constants、DTO、mapper、repositories 已建立、FirebaseMessaging token sync | offline/conflict 深化策略仍在 Step 13 |
| Backend logic | 完成 Step 1-10 範圍 | callable 與 scheduled jobs 已落地（含 idempotency 與 push dedupe） | 無主要缺口 |
| System integration | 完成 Step 11-12 | APNs/FCM token sync、notification categories、deep link routing、foreground gate、Widget extension (small/medium/accessory)、Live Activity (planning/settlement)、App Intents (planning/dashboard/settlement/rewards)、SharedSnapshot 含 reward/payment | 無主要缺口 |
| QA/release | 部分完成 | core/firebase 測試與 iOS build 已回歸綠燈 | integration/UI/device/emulator/release 驗證 |

## 剩餘步驟

### Step 1. 先把 baseline 拉回綠燈

狀態: 已完成

已完成:

- 修正 `LoadDashboardUseCaseTests` 的 seed membership，避免 dashboard baseline 再落到 `coupleNotFound`。
- 在 `SubmitNextDayPlanUseCase` 加入 timezone identifier normalization，處理 `GMT` / `UTC` alias mismatch。
- 補上 `PaymentRecord` / `PaymentRepository` core contract，避免 Step 4 之後還要回頭改 domain。
- 新增 `CoupleTodoFirebaseTests`，覆蓋 payment payload、client-writable 欄位、server-owned 欄位與 Firestore path builder。

### Step 2. 把 demo-only 啟動流程換成真實 Auth

狀態: 已完成

已完成:

- 建立 `FirebaseAuthenticationService`，以 `Sign in with Apple + FirebaseAuth` 處理登入與 session persistence。
- `AuthView` 已從 demo button 改成真實 `Continue with Apple` 入口。
- 新增 `UserProfileBootstrapper`，登入後會 bootstrap / refresh `users/{userId}` profile。
- `AppCoordinator` 現在會在未登入 deep link 時先保存 route，登入成功後再導回。

### Step 3. 完成 Pairing 與 couple lifecycle 真實流程

狀態: 已完成

已完成:

- 新增 `FirebaseCoupleLifecycleGateway`，透過真實 callable 走 `createCouple` / `joinCouple`。
- `PairingView` 已提供 create/join flow、invite code 顯示與 pending couple 狀態。
- backend callable 現在會擋 `already_paired` / `couple_full`，避免重複加入或超過兩人。
- `AppCoordinator.saveSettings()` 已改走真實 `CoupleRepository`，couple policy 與 reminder config 不再只停留在 demo seed。

### Step 4. 落地 Firestore schema、DTO、mapper、repositories

狀態: 已完成

已完成:

- 在 `CoupleTodoFirebase` target 內建立 `FirestorePaths` 與所有 Firestore document mapper。
- 補齊 Firestore-backed `UserRepository`、`CoupleRepository`、`DeviceInstallationRepository`、`PlanRepository`、`TaskRepository`、`SettlementRepository`、`RewardWeekRepository`、`EventRepository`、`PaymentRepository`。
- mapper 已明確區分 client payload、server-owned 欄位與 acknowledgement / payment status update payload。
- `AppEnvironment.live()` 與 `FirebaseAppServices.live()` 已建立，App 不再只能靠 `DemoAppEnvironment` 啟動。

### 你可以做的 test case

1. `swift test`
   - 驗證 core + firebase 測試全綠（目前 42 tests）。
2. `xcodebuild -scheme CoupleTodo -destination 'generic/platform=iOS Simulator' build`
   - 驗證 App target 可完整編譯。
3. Auth 首次登入
   - 重裝 app 後 `Continue with Apple`，確認會建立/刷新 `users/{userId}` 後進 pairing。
4. Auth session persistence
   - 登入後重啟 app，確認不會回 auth，會回 pairing 或 dashboard。
5. Create / Join couple
   - A 建立 invite code、B 加入，確認 `couples/{coupleId}` 成員變 2 且 `status = active`。
6. Duplicate join / full couple guard
   - 已配對帳號再次 join 回 `already_paired`；第三人 join 同 code 回 `couple_full`。
7. Dashboard countdown 與 pending payment
   - dashboard 顯示 self/partner planning+settlement 倒數，且 pending payment 會出現在 `Pending Payments` 區塊。
8. 同步循環自動刷新
   - dashboard 停留 20 秒以上，確認資料會自動 refresh（不用手動下拉）。
9. Planning optional carry-over
   - 在 Planning 點 `Carry Over Optional From Today`，確認 optional task 會複製到隔日草稿且保留 `carriedFromTaskId`。
10. Planning 再編輯截止
   - 已送出的 plan 在 cutoff 後但午夜前可再送；超過隔日 00:00 後會被擋。
11. Planning missed 自動標記
   - 超過 cutoff 且未提交，refresh 後確認 `planningMissed` 會被寫入並產生 event。
12. Task lock after settlement finalized
   - 該日 settlement finalized 後，create/update/delete/reorder/toggle task 應被拒絕。
13. Settlement gate 不可略過
   - 有 pending acknowledgement 時，full-screen settlement 不可 swipe down 或 Close 離開。
14. Settlement history
   - 從 Dashboard/Settlement 進入 `Settlement History`，確認可看到每日 gross owed/receivable 與 net。
15. Payment acknowledgement flow
   - debtor `Mark Paid` 後，creditor 可 `Acknowledge` 或 `Dispute`；狀態與時間戳需正確更新。
16. Settings notification + timezone sync
   - Settings 顯示系統通知權限、Time Sensitive toggle、device timezone/UTC offset，儲存後重開 app 仍可讀回。
17. Backend functions build
   - `cd Backend/functions && npm run build`，確認 Functions TypeScript 可編譯。
18. `submitPlan` success path
   - 在 planning 視窗內送出有效 `targetDateKey + tasks[]`，確認回傳 `planId/submittedAt/requiredCount/optionalCount` 並寫入 `plans/{userId_dateKey}` 與 `tasks`。
19. `submitPlan` invalid window guard
   - 視窗外送出（提醒前或截止後且無既有 submitted plan），確認回 `invalid_window`。
20. `submitPlan` date mismatch guard
   - 傳錯 `targetDateKey` 或 task 的 `dateKey/localTimezone` 不一致，確認回 `date_mismatch`。
21. `acknowledgeSettlement` idempotency
   - 同一使用者連續呼叫兩次，第二次不應報錯且 `pendingAcknowledgementUserIds` 不會反向增加。
22. `saveNextWeekReward` lock guard
   - rewardWeek 狀態非 `draft` 時再次儲存，確認回 `reward_locked`。
23. `markPaymentPaid` permission + state guard
   - 非 debtor 呼叫應回 `forbidden`；payment 狀態非 `pending` 時應回 `invalid_state`。
24. `markPaymentPaid` idempotency
   - debtor 對同一 record 重複呼叫，`markedPaidAt` 已存在時應回成功且不破壞既有狀態。
25. `planningReminderJob` dedupe
   - 在同一 `userId + dateKey + bucket` 重跑 job，不應重複發送；`_jobDedupe` 應只保留一筆 key。
26. `planningMissJob` one-way transition
   - cutoff 後未提交 plan，`planningMissed` 僅從 `false -> true` 一次，重跑 job 不應重複建立 miss event。
27. `dailySettlementJob` idempotent finalize
   - 重跑 job 時同一 `settlementId = userId_dateKey` 不應重複 finalize，也不應重複建立 payment record。
28. `weeklyRewardFinalizeJob` active-only finalize
   - 只會 finalize `status=active` 的 rewardWeek；`draft/earned/missed` 不應被重寫。
29. `snapshotCompactionJob` read-model rebuild
   - 確認會更新 `readModels/eventCompaction` 與 `readModels/paymentNetSummary`，且不改寫 finalized settlement/reward。
30. Push routing payload
   - 驗證 `planning_reminder/planning_escalation/settlement_ready/reward_earned/payment_pending` 皆附正確 deep link（`coupletodo://...`）。

### Step 5. 完成同步策略與 dashboard 真實資料化

狀態: 已完成

已完成:

- 新增等價同步層: `AppCoordinator` 背景同步循環（20 秒）自動 refresh dashboard。
- 定義 task sync state 流程: dashboard 讀取時會把 `local_pending -> synced`，結算 finalized 當日轉為 `server_final`。
- `LoadDashboardUseCase` 已補齊真實欄位: self/partner planning countdown、settlement countdown、pending payment。
- Dashboard UI 已顯示 partner submitted、reward status、pending payments、跨時區倒數。

### Step 6. 補齊 task CRUD 與 planning 真實規則

狀態: 已完成

已完成:

- task mutation use cases 補上 finalized day lock（create/update/delete/toggle/reorder 全部擋下）。
- Planning UI 補上 `Carry Over Optional From Today`，會建立隔日 optional task 並回填 `carriedFromTaskId`。
- `SubmitNextDayPlanUseCase` 支援「已提交計畫」在 cutoff 後、午夜前可再提交；午夜後拒絕編輯。
- `MarkPlanningMissedUseCase` 改為 idempotent，App 在 cutoff 後會自動寫入 `planningMissed` 並保留 event 記錄。

### Step 7. 完成 settlement、payment 與不可跳過 gate

狀態: 已完成

已完成:

- settlement gate 已不可略過: pending ack 狀態下禁止 full-screen dismiss/Close。
- 新增 `SettlementHistoryView` 與 `PaymentAcknowledgementView`，並完成 route/deep link wiring。
- 新增 `MarkPaymentPaidUseCase`、`ResolvePaymentStatusUseCase`（含權限與狀態驗證）。
- UI 已支援 debtor `mark paid`、creditor `acknowledge/dispute`，並在 history 顯示 gross obligation 與 net。

### Step 8. 完成 reward 與 settings 真實讀寫

狀態: 已完成

已完成:

- Rewards 頁補上當週狀態與 eligibility matrix（You/Partner）呈現，並加上 draft 編輯限制（locked 時 disabled）。
- `SaveNextWeekRewardUseCase` 補上 member 驗證與 lock 驗證（非 member / 非 draft 會拒絕）。
- Settings 頁補上通知權限狀態、Time Sensitive toggle、device timezone + UTC offset，同步讀寫 user/couple/device repositories。
- App bootstrap 會同步 `DeviceInstallation`，Settings 儲存會寫回 `UserProfile.notificationPreferences` 與 `Couple` 設定。

### Step 9. 實作 backend callable functions

狀態: 已完成

已完成:

- `createCouple` / `joinCouple` 補齊 policy 驗證、membership 檢查與 idempotent flow。
- `submitPlan` 已實作 server-side 視窗驗證（reminder/cutoff + re-edit 截止）、task ownership/date/timezone 驗證、plan/tasks 寫入與 `plan_submitted` event。
- `acknowledgeSettlement` 已實作 settlement/member 檢查、pending ack 陣列更新與 idempotent acknowledge。
- `saveNextWeekReward` 已實作 next-week key 計算、draft lock 驗證、reward 寫入與 `weekly_reward_drafted` event。
- `markPaymentPaid` callable 已新增，含 debtor 權限、狀態檢查與 idempotent update。
- callable response/error 行為已對齊 spec 的主要錯誤碼語義（`forbidden` / `date_mismatch` / `invalid_window` / `reward_locked` / `record_not_found`）。

### Step 10. 實作 scheduled jobs 與 push orchestration

狀態: 已完成

已完成:

- `planningReminderJob`：依使用者時區 + 視窗判斷推送 `planning_reminder/planning_escalation`，並用 `_jobDedupe` 以 `userId+dateKey+bucket` 去重。
- `planningMissJob`：cutoff 後 idempotent 寫入 `planningMissed=true`、追加 `planning_missed` event，並更新 reward eligibility。
- `dailySettlementJob`：依 `userId_dateKey` finalize settlement（含 reward impact）、建立 payment record、推送 `settlement_ready/payment_pending`。
- `weeklyRewardFinalizeJob`：僅處理 `active` rewardWeek，於雙方跨週後轉 `earned/missed` 並發 reward push。
- `snapshotCompactionJob`：壓縮舊 events、重建 payment net summary、清理過期 shared snapshot，不改寫 finalized 結果。
- push orchestration 已實作 FCM multicast + APNs category/time-sensitive payload 與 dedupe status trace。

### Step 11. 完成裝置同步、通知、deep link 與 app foreground behavior

狀態: 已完成

已完成:

- `Package.swift` 新增 `FirebaseMessaging` 依賴，`AppDelegate` 實作 `MessagingDelegate` 與 `UNUserNotificationCenterDelegate`。
- `syncCurrentDeviceInstallation` 已上報 APNs/FCM token、timezone、UTC offset、capabilities（含 `supportsLiveActivities`、`supportsTimeSensitive` 查詢實際系統狀態）。
- 新增 `NotificationService`，註冊 5 個 notification categories（`planning_reminder`、`planning_escalation`、`settlement_ready`、`reward_earned`、`payment_pending`），每個 category 含 foreground action。
- `AppDelegate.userNotificationCenter(didReceive:)` 會從 payload 擷取 `deepLink` 後透過 `AppCoordinator.handleIncomingURL` 導頁到對應畫面。
- `Info.plist` 新增 `UIBackgroundModes = [remote-notification, fetch]`。
- `CoupleTodo.entitlements` 新增 `aps-environment = development`。
- `AppCoordinator.handleAppBecameActive()` 在每次 app 回前景時自動 refresh dashboard 並套用 pending gate（planning 或 settlement full-screen）。
- bootstrap 階段會呼叫 `requestNotificationPermission()` 取得通知授權。
- FCM/APNs token 更新時會即時重新同步 `DeviceInstallation`。
- `EventLogType` 補齊 `settlementAcknowledged` 與 `paymentMarkedPaid` 兩個事件類型。

### Step 12. 做完 Widget、Live Activity、App Intents 與 App Group 消費端

狀態: 已完成

已完成:

- 新增 `CoupleTodoWidgetExtension` target（`project.yml`），含 `CoupleTodoWidget.entitlements` 共用 App Group `group.com.coupletodo.shared`。
- Widget 提供三種型態: `systemSmall`（自己的 required 完成進度）、`systemMedium`（雙欄顯示 You/Partner 各自進度與 planning 狀態）、`accessoryRectangular`（lock screen 摘要）。
- Widget 透過 `SharedSnapshotReader` 讀取 App Group JSON，timeline 每 15 分鐘刷新一次。
- `SharedSnapshotWriter` 已更新，現在額外寫入 `reward`（weekKey/rewardText/status）與 `payments`（pendingCount/totalPendingAmount）到 shared snapshot。
- `SharedSnapshot` 新增 `RewardSnapshot` 與 `PaymentSummary` 兩個子結構。
- Widget URL 導回 `coupletodo://dashboard`，讓 tap 直接回到 dashboard。
- 新增 `PlanningReminderActivity`（Live Activity），在晚間 planning 視窗啟動，顯示 self/partner submitted 狀態、cutoff 倒數，cutoff 後自動結束。
- 新增 `DailySettlementActivity`（Live Activity），在 settlement pending 時啟動，顯示 self/partner outcome 與 owes amount，acknowledgement 完成後自動結束。
- `AppCoordinator.updateLiveActivitiesIfNeeded()` 在 bootstrap、dashboard refresh 與 app 前景回來時自動判斷是否開啟/更新/結束 Live Activity。
- 新增 4 個 `AppIntent`: `OpenPlanningIntent`、`OpenDashboardIntent`、`OpenSettlementIntent`、`OpenRewardsIntent`，並透過 `CoupleTodoShortcuts` 註冊到 Siri/Shortcuts。
- `CoupleTodoIntentRouter` 作為 singleton 橋接 AppIntents → AppCoordinator 導航。
- `handleAppBecameActive()` 同時處理 intent pending route。

### 你可以做的 test case (Step 11-12)

31. Notification permission request
   - 首次啟動 app 後確認系統彈出通知授權對話框。
32. Notification categories registration
   - 啟動後檢查 `UNUserNotificationCenter.current().getNotificationCategories()`，確認包含 `planning_reminder`、`planning_escalation`、`settlement_ready`、`reward_earned`、`payment_pending`。
33. FCM token sync
   - 登入後確認 `deviceInstallations/{installationId}` 包含 `fcmToken` 欄位。
34. APNs token relay
   - 在真機上啟動，確認 `Messaging.messaging().apnsToken` 有值且 `deviceInstallations` 有 `apnsToken`。
35. Time Sensitive capability reporting
   - `Settings > Time Sensitive allowed` 開啟/關閉後確認 `deviceInstallations.supportsTimeSensitive` 正確反映。
36. Notification tap routing (planning)
   - 收到 `planning_reminder` push 後點擊通知，確認導到 `PlanningView(dateKey:)`。
37. Notification tap routing (settlement)
   - 收到 `settlement_ready` push 後點擊通知，確認導到 `SettlementView(dateKey:)`。
38. Notification tap routing (rewards)
   - 收到 `reward_earned` push 後點擊通知，確認導到 `RewardsView(weekKey:)`。
39. Notification tap routing (payment)
   - 收到 `payment_pending` push 後點擊通知，確認導到 `PaymentAcknowledgementView(recordId:)`。
40. Foreground auto gate (settlement)
   - 有 pending settlement 時按 Home 再回 app，確認自動蓋上 settlement full-screen gate。
41. Foreground auto gate (planning)
   - 在 planning window 且未提交 plan 時回前景，確認自動蓋上 planning full-screen。
42. Widget snapshot read
   - 在 Simulator 上加 small widget，確認顯示 required completed/remaining 數字與 "Plan needed" / "Plan ✓"。
43. Widget medium view
   - 加 medium widget，確認雙欄顯示 You/Partner 各自 dateKey 與 required 進度。
44. Widget lock screen accessory
   - 加 accessoryRectangular widget，確認顯示 CoupleTodo 與 remaining 數字。
45. Widget deep link
   - 點擊 widget，確認 app 開啟並導到 Dashboard。
46. Widget auto-refresh
   - 等待 15 分鐘或手動觸發 timeline reload，確認 widget 資料更新。
47. SharedSnapshot includes reward
   - 有 active rewardWeek 時，確認 App Group JSON 含 `reward.weekKey`、`reward.status`。
48. SharedSnapshot includes payment summary
   - 有 pending payment 時，確認 App Group JSON 含 `payments.pendingCount > 0`。
49. Planning Live Activity start
   - 21:30 後且未提交 plan，確認 Dynamic Island / Lock Screen 出現 planning Live Activity，顯示 cutoff 倒數。
50. Planning Live Activity update
   - 提交 plan 後，確認 Live Activity 中 "You" 變綠色。
51. Planning Live Activity end
   - 23:00 後（或已提交且雙方皆已提交），確認 planning Live Activity 自動消失。
52. Settlement Live Activity start
   - settlement finalized 且 pending ack 時，確認出現 settlement Live Activity。
53. Settlement Live Activity end
   - acknowledge 後，確認 settlement Live Activity 自動消失。
54. App Intent - Open Planning
   - 透過 Siri 說 "Open planning in CoupleTodo"，確認 app 開啟並導到 PlanningView。
55. App Intent - Open Dashboard
   - 透過 Shortcuts app 執行 Open Dashboard intent，確認導到 Dashboard。
56. EventLogType settlement_acknowledged
   - acknowledge settlement 後確認 events 中有 `settlement_acknowledged` type 記錄。
57. EventLogType payment_marked_paid
   - mark payment paid 後確認 events 中有 `payment_marked_paid` type 記錄。

### Step 13. 收斂 Security Rules、離線 UX、衝突策略

狀態: 部分完成

未完成:

- 現有 rules 只有初步限制，尚未涵蓋 payments、fine-grained acknowledgement 與 locked day。
- 補 server-only 欄位驗證與 immutable finalized data。
- 補離線提示、同步失敗回補、timezone 突變策略、server-final 覆蓋 UX。
- 補雙方同時編輯與 clock skew 的衝突處理。

### Step 14. 補齊測試、真機驗證與發版流程

狀態: 未開始

未完成:

- Firebase Emulator integration tests。
- UI tests 覆蓋 auth、pairing、dashboard、planning、settlement gate、payments、rewards。
- 真機驗證 APNs/FCM、Time Sensitive、Widget、Live Activity、App Group snapshot。
- analytics、crash logging、TestFlight smoke checklist。
- 完成定義對照 spec 全數過關。

## 目前已知紅燈

- 目前無已知紅燈。
- 最新驗證結果:
  - `swift test` 全綠（43 tests + 2 macro tests）
  - `cd Backend/functions && npm run build` 成功
  - Widget extension target 已在 `project.yml` 定義，需執行 `xcodegen generate` 或手動重新載入 Xcode project 使其生效。

## 你還差多少步

- 以高層步驟來看，Step 1 到 Step 12 已完成，剩下 Step 13 到 Step 14 共 2 個主要步驟。
- 目前主要後續工作是 security rules/offline UX/conflict 策略（Step 13）與測試/真機驗證/發版流程（Step 14）。

先完成的合理順序:

1. Step 13
2. Step 14
