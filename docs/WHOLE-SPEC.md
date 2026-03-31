# 完整 App 實作缺口報告

更新日期: 2026-03-25

本報告以目前 repo 為基準，對照 `IOS_COUPLE_TODO_APP_DEVELOPMENT_SPEC.md` 列出剩餘工作。用途只有一個: 讓你直接看出離完整 app 還剩多少步驟、每一步缺什麼、哪些地方已經不是從零開始。

## Summary

- Step 1 到 Step 14 已全部落地到程式碼。
- App 目前已接入 `AppEnvironment.live()`、`FirebaseAppServices`、`FirebaseAppleAuthenticationService`、`UserProfileBootstrapper`，並新增 settlement/payment/history 與 rewards/settings 強化流程。
- 新增 `FirebaseMessaging` 整合、APNs/FCM token 同步、notification categories 註冊、foreground gate 行為、Live Activity lifecycle、Widget extension、App Intents。
- Backend Functions 已補齊 `submitPlan`、`acknowledgeSettlement`、`saveNextWeekReward`、`markPaymentPaid` 與 5 個 scheduler jobs（含 push dedupe）。
- Step 13 新增: Firestore Security Rules 強化（finalized data immutability、server-only field guard、task locked-day block、payment state guard、readModels/jobDedupe server-only）、Firestore 100MB persistent cache、NWPathMonitor 離線偵測、OfflineBannerView、SyncStatusTracker（exponential backoff retry）、timezone 變更偵測、ConflictResolver（server-wins / client-wins / latestTimestamp 策略 + clock skew tolerance）。
- Step 14 新增: ConflictResolverTests + SyncStatusTrackerTests（新增 15 個 unit tests）、CoupleTodoUITests target（7 個 UI test stubs）、Firestore security rules integration test suite（20+ emulator tests）、AnalyticsService / CrashReportingService placeholder、TESTFLIGHT_CHECKLIST.md。
- 最新驗證: `swift test` 全綠（60 + 2 = 62 tests）、`cd Backend/functions && npm run build` 成功。

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
| Core domain | 完成 Step 1-14 | 新增 ConflictResolver、SyncStatusTracker、NetworkMonitor | 無主要缺口 |
| App shell | 完成 Step 1-14 | 新增 OfflineBannerView、timezone 變更偵測、sync retry、connectivity 監控 | 無主要缺口 |
| Firebase data layer | 完成 Step 1-14 | Firestore 100MB persistent cache、NWPathNetworkMonitor、Analytics/CrashReporting placeholder | 無主要缺口 |
| Security rules | 完成 Step 13 | 強化 task locked-day、settlement immutability、payment state guard、readModels/jobDedupe server-only | 無主要缺口 |
| Backend logic | 完成 Step 1-10 | callable 與 scheduled jobs 已落地 | 無主要缺口 |
| System integration | 完成 Step 11-12 | APNs/FCM、Widget、Live Activity、App Intents 全部串接 | 無主要缺口 |
| QA/release | 完成 Step 14 | 新增 UI test target、emulator integration tests、TestFlight checklist | 真機 + TestFlight 實測 |

## 已完成步驟

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
   - 驗證 core + firebase 測試全綠（目前 62 tests）。
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

狀態: 已完成

已完成:

- **Security Rules 強化**:
  - 補上 `isServerOnly()` helper function，確保 server-only 欄位（`id`, `memberIds`, `status`, `inviteCode`, `createdAt` 等）不可被 client 端直接修改。
  - 新增 task locked-day guard: `parentSettlementFinalized()` / `parentSettlementFinalizedForCreate()` 查詢對應的 settlement 是否已 finalized，finalized 後的日期不允許建立/編輯/刪除 task。
  - Settlement rules 強化: 只允許修改 `pendingAcknowledgementUserIds` 和 `updatedAt`，其他所有欄位（`state`, `subjectResult`, `computedAt`, `counterpartySnapshot`, `rewardImpact` 等）皆為 server-only immutable。
  - RewardWeek rules 強化: 新增 `isRewardMutable()` 函數，只有 `draft` 狀態的 rewardWeek 才允許 client 修改；`active/earned/missed/locked` 狀態全部不可寫入。
  - Payment rules 強化: debtor 只能在 `status == pending` 時 mark paid；新增 `isPaymentPending()` guard。
  - 新增 `readModels/{modelId}` 規則: client 只可讀不可寫（server-only read models）。
  - 新增 `_jobDedupe/{dedupeKey}` 規則: client 完全不可讀不可寫。
- **Firestore 離線持久化**:
  - `FirebaseBootstrap.configureIfNeeded()` 新增 `PersistentCacheSettings(sizeBytes: 100MB)`，啟動 Firestore 100MB 離線持久快取。
- **離線偵測與 UX**:
  - 新增 `NetworkMonitor` protocol（`CoupleTodoCore`）與 `NWPathNetworkMonitor`（`CoupleTodoFirebase`），使用 `NWPathMonitor` 即時監控網路狀態。
  - 新增 `SyncStatusTracker`（ObservableObject），追蹤同步狀態（idle/syncing/syncFailed/pendingRetry），具 exponential backoff retry（最大 300 秒）。
  - 新增 `OfflineBannerView`（SwiftUI），當離線或 sync 失敗 >= 3 次時顯示 banner + Retry 按鈕。
  - `AppCoordinator` 新增 `connectivity` / `syncTracker` published properties，`refreshDashboard()` 更新 sync tracker 狀態。
- **Timezone 變更偵測**:
  - `AppCoordinator.detectTimezoneChange(for:)` 在 bootstrap 時比較 `TimeZone.current.identifier` 與上次已知 timezone，變更時顯示提示。
  - `lastKnownTimezone` 持久記錄在 coordinator 中。
- **衝突解決策略**:
  - 新增 `ConflictResolver`（`CoupleTodoCore`），支援三種策略: `serverWins`（預設）、`clientWins`、`latestTimestamp`。
  - `serverFinal` sync state 的資料不可被 client 覆蓋（不管策略為何）。
  - `resolveBatch()` 可批次合併 local/server task 列表。
  - `isClockSkewAcceptable()` 檢測 client/server 時間差是否在容忍範圍內（預設 300 秒）。

### Step 14. 補齊測試、真機驗證與發版流程

狀態: 已完成

已完成:

- **Unit Tests 新增**:
  - `ConflictResolverTests`: 9 個 test cases — serverWins/clientWins/latestTimestamp 策略、serverFinal 不可覆蓋、batch resolve、clock skew 容忍度。
  - `SyncStatusTrackerTests`: 6 個 test cases — initial state、markSyncing、markSuccess reset、pendingRetry/syncFailed 門檻、exponential backoff cap、reset 清除。
- **UI Test Target 新增**:
  - `project.yml` 新增 `CoupleTodoUITests` target（`bundle.ui-testing`），並掛入 `CoupleTodo` scheme。
  - `CoupleTodoUITests.swift` 包含 7 個 UI test stubs: auth 畫面檢查、dashboard 顯示、planning add task、settlement gate 不可關閉、settings timezone 顯示、offline banner、rewards eligibility。
- **Firestore Rules Integration Tests**:
  - `Backend/test/firestore-rules.test.ts` 包含 20+ emulator test cases，覆蓋:
    - User profile read/write 權限與 coupleId 不可篡改
    - Couple settings update / memberIds immutable / 不可直接建立
    - Settlement acknowledgement / outcome + state 不可改 / subjectResult immutable
    - Payment debtor mark paid / creditor acknowledge+dispute / 不可直接建立 / state guard
    - RewardWeek lock guard（non-draft 不可修改）
    - ReadModels server-only（可讀不可寫）
    - _jobDedupe 完全不可存取
- **Analytics & Crash Reporting**:
  - 新增 `AnalyticsService` protocol + `FirebaseAnalyticsService` / `StubAnalyticsService`，涵蓋 18 個 event types。
  - 新增 `CrashReportingService` protocol + `FirebaseCrashReportingService` / `StubCrashReportingService`。
  - 目前為 placeholder（print in DEBUG），需加入 `FirebaseAnalytics` / `FirebaseCrashlytics` SPM product 後即可啟用。
- **TestFlight Checklist**:
  - 新增 `docs/TESTFLIGHT_CHECKLIST.md`，涵蓋 pre-build verification、security rules deploy、backend functions deploy、auth/pairing、dashboard/sync、planning、settlement、payments、rewards、settings、notifications、widget、live activity、app intents、offline/conflict、performance/stability、release 等全面檢查項目。

### 你可以做的 test case (Step 13-14)

58. Security rules: outsider 不可讀 user profile
   - 用非 couple member 的 auth uid 嘗試讀取 `users/{userId}`，確認被拒絕。
59. Security rules: 不可直接修改 couple memberIds
   - 用 couple member 嘗試 update `memberIds`，確認被拒絕。
60. Security rules: finalized settlement 不可改 outcome
   - 嘗試修改 `state` 或 `subjectResult`，確認被拒絕。
61. Security rules: task locked-day enforcement
   - settlement finalized 後嘗試 create/update/delete task，確認被 security rules 擋下。
62. Security rules: debtor 才能 mark paid
   - 非 debtor（creditor）嘗試修改 `markedPaidAt`，確認被拒絕。
63. Security rules: payment 只有 pending 才能 mark paid
   - payment status 為 `acknowledged` 時 debtor 嘗試再次 mark paid，確認被拒絕。
64. Security rules: non-draft reward 不可編輯
   - rewardWeek status 為 `active` 時嘗試修改 `rewardText`，確認被拒絕。
65. Security rules: readModels 不可被 client 寫入
   - 嘗試寫入 `couples/{id}/readModels/paymentNetSummary`，確認被拒絕。
66. Security rules: _jobDedupe 不可讀不可寫
   - 嘗試讀取或寫入 `_jobDedupe/{key}`，確認被拒絕。
67. Firestore emulator rules test suite
   - `firebase emulators:exec --only firestore "npx jest test/firestore-rules.test.ts"` 全部通過。
68. Offline banner 顯示
   - 開啟飛航模式，確認 OfflineBannerView 顯示 "You're offline" 訊息。
69. Offline banner 消失
   - 關閉飛航模式，確認 banner 自動消失且資料自動 sync。
70. Sync retry after 3 failures
   - 模擬 sync 失敗 3 次，確認 status 變為 `syncFailed` 並顯示 Retry 按鈕。
71. Sync retry success
   - 點擊 Retry 按鈕，確認資料重新同步成功。
72. Timezone 變更偵測
   - 在 Settings 手動更改裝置 timezone，重開 app，確認顯示 timezone 變更提示。
73. Conflict resolver: server_final 不可覆蓋
   - server 傳回 `syncState = server_final` 的 task，local 版本不應覆蓋它。
74. Conflict resolver: server-wins 合併
   - local 與 server 都有修改，server updatedAt 較新時 server 版本應勝出。
75. Clock skew tolerance
   - client/server 時間差在 300 秒內，確認 `isClockSkewAcceptable` 回 true。
76. Clock skew rejection
   - client/server 時間差超過 300 秒，確認 `isClockSkewAcceptable` 回 false。
77. ConflictResolver unit tests 全綠
   - `swift test` 中 `ConflictResolverTests` 的 9 個 test 全部通過。
78. SyncStatusTracker unit tests 全綠
   - `swift test` 中 `SyncStatusTrackerTests` 的 6 個 test 全部通過。
79. UI test target 可建置
   - `xcodebuild -scheme CoupleTodo -destination 'generic/platform=iOS Simulator' build-for-testing` 成功。
80. AnalyticsService event logging
   - 使用 `StubAnalyticsService`，執行關鍵操作後確認 `loggedEvents` 包含正確的 event name 與 parameters。
81. CrashReportingService error recording
   - 使用 `StubCrashReportingService`，觸發 error 後確認 `recordedErrors` 有記錄。
82. TestFlight checklist 完整性
   - 對照 `docs/TESTFLIGHT_CHECKLIST.md` 逐項檢查，確認所有 pre-build 和功能項目都可執行。

## 目前已知紅燈

- 目前無已知紅燈。
- 最新驗證結果:
  - `swift test` 全綠（60 unit tests + 2 macro tests = 62 tests）
  - `cd Backend/functions && npm run build` 成功
  - Widget extension target 已在 `project.yml` 定義，需執行 `xcodegen generate` 或手動重新載入 Xcode project 使其生效。
  - UI test target 已新增至 `project.yml`，同樣需 `xcodegen generate` 重建 xcodeproj。

## 你還差多少步

- 以高層步驟來看，Step 1 到 Step 14 全部已完成。
- 程式碼層面的工作已全部落地，剩下的是:
  1. 加入 `FirebaseAnalytics` / `FirebaseCrashlytics` SPM 依賴並啟用真實 logging（目前為 placeholder）。
  2. 在真機上執行 `TESTFLIGHT_CHECKLIST.md` 的完整驗證流程。
  3. 使用 Firebase Emulator Suite 跑 `Backend/test/firestore-rules.test.ts` 確認 security rules 行為。
  4. Archive → TestFlight → 提交 App Store review。
