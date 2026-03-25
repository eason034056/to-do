# CoupleTodo iOS App 實作規格

更新日期: 2026-03-24

本文件是 CoupleTodo v1 的單一 source of truth。目標不是 PRD，而是讓 iOS、Firebase、通知、Widget、Live Activity、測試與發版工作可以直接按本文開發，不再依賴分散文件補決策。

## 1. 產品範圍

- 正式技術基線固定為 `Swift + SwiftUI + Firebase + CoupleTodoCore`。
- `Sources/CoupleTodoCore` 是唯一 domain/use case 規則來源，不依賴 Firebase 或 SwiftUI。
- `App/` 負責 SwiftUI、路由、通知、App Group snapshot、Widget/Live Activity 啟停。
- `Backend/functions/src/index.ts` 對應 Firebase Functions、Firestore、Cloud Scheduler、FCM/APNs。
- v1 只支援一對一 couple，不做多人群組、家庭模式、Apple Watch、macOS/iPad 特化。
- v1 只做每日結算、欠款紀錄、手動確認已支付，不串第三方支付或自動扣款。
- 登入以 `Sign in with Apple` 為主，Email/Password 可延後作為備援。

## 2. 核心語言

- `required`: 當日一定要完成，結算唯一檢查對象。
- `optional`: 可做可不做，不影響每日是否失敗。
- `planning`: 晚間填寫隔日計畫的流程。
- `settlement`: 伺服器對單一使用者單一本地日期的最終結算。
- `reward`: 前一週先寫、下一週才可解鎖的獎勵。
- `penalty`: 每日未達標產生的固定金額義務。
- `acknowledgement`: 對 settlement 或 payment record 的確認動作。

## 3. iOS 平台限制

### 3.1 不可從 Home Screen 強制打開自家全螢幕 UI

- App 不能在使用者停留主畫面時主動蓋上全螢幕 UI。
- 正式替代方案固定為 `Time Sensitive 通知 + Live Activity + Widget + App 內 full-screen gate`。

### 3.2 系統通知不能被 App 設成永遠不可清除

- 一般 App 無法阻止使用者手動清掉通知。
- 正式策略是持續遠端重送提醒、保留 Widget 與 Live Activity 狀態、並在 App 前景內持續 gate。

### 3.3 背景排程不是精準鬧鐘

- iOS `Background Refresh` 只能當輔助，不可當正式提醒或結算來源。
- 真正準時的提醒、逾時標記、每日結算與週獎勵 finalize 一律由伺服器排程驅動。

### 3.4 Live Activity 只能用於短時窗

- Live Activity 不當 24 小時儀表板。
- 正式用途只限「晚間 planning 視窗」與「每日 settlement 視窗」。

### 3.5 不採用 Critical Alerts

- v1 不假設有 Apple 特批 entitlement。
- 正式可用最高等級為 Time Sensitive。

## 4. 固定商業規則

### 4.1 時區、日界線與週界線

- 每位使用者都以自己的本地時區作為唯一日界線與週界線。
- 同一個真實時間點，兩位成員可以處於不同的 `dateKey` 與 `weekKey`。
- Dashboard、Planning、Settlement、Rewards 都必須同時顯示兩人的日期標籤、時區縮寫與倒數資訊。
- 伺服器根據 `users.currentTimezone` 與 `deviceInstallations.timezone` 決定排程與結算掃描，不可假設 couple 共用同一時區。

### 4.2 固定常數

| Rule | Value |
| --- | --- |
| `planningReminderTime` | `21:30` |
| `planningCutoffTime` | `23:00` |
| `planningEscalationEveryMinutes` | `15` |
| `dailySettlementTime` | `23:59` |
| `dailySettlementGraceMinutes` | `5` |
| `weekStartsOn` | `Monday` |
| `penaltyMode` | `flat_per_day` |
| `penaltyAmount` | `50 USD` |

### 4.3 任務與排序

- 每個 task 必有 `bucket` 與 `priority` 兩個維度，不可混成同欄位。
- `bucket` 只有 `required` 與 `optional`。
- `priority` 只有 `p0`、`p1`、`p2`、`p3`。
- 正式排序規則固定為 `required` 在前，再依 `priority`，再依 `sortOrder`。
- `optional` 任務可提供一鍵帶到隔日，但不影響當日 settlement。

### 4.4 Tomorrow Planning

- Planning 目標永遠是「下一個本地日期」。
- 計畫由 `required` 與 `optional` 兩區組成。
- 可提交條件:
  - task 清單不可為空。
  - 若沒有 `required` task，使用者必須明確勾選 `noRequiredTasksConfirmed`。
- 已提交計畫可編輯到隔日本地 `00:00` 前。
- 超過 `planningCutoffTime` 仍未提交，伺服器必須寫入 `planningMissed = true`。
- `planningMissed = true` 的效果:
  - 本週 reward 直接失格。
  - 預設不直接產生 50 美金罰款。
  - `planningMissPenaltyEnabled` 保留為 couple 設定欄位，供後續版本開啟。
- escalation 由伺服器 remote push 驅動，本地通知只做 fallback。

### 4.5 Daily Settlement

- 每日 settlement 在 `dailySettlementTime + dailySettlementGraceMinutes` 之後執行。
- 只檢查該使用者該本地日期的 `required` tasks。
- 只要有任一 `required` 未完成，即視為該日失敗。
- 懲罰規則固定為 `flat_per_day`:
  - A 失敗，A 欠 B `50 USD`。
  - B 失敗，B 欠 A `50 USD`。
  - 雙方都失敗時，保留兩筆原始 obligation，UI 可另外顯示淨額。
- settlement 由 server finalize；client 可做預估與預覽，但不可把 client 推算結果回寫成正式資料。
- settlement finalized 後，該日 task 與 plan 不可再被 client 改寫。

### 4.6 Weekly Reward

- 下週 reward 必須在本週內先寫好，本週只可編輯「下週 reward 草稿」。
- 當週開始後，當週 reward 只可讀，不可修改。
- 本週只要任一日任一人發生 `planningMissed` 或 `required` 未達標，該週 reward 直接 `missed`。
- 只有兩人整週全綠，且雙方都跨過各自本地週界線後，該週 reward 才可 `earned`。

### 4.7 Payment 與 Acknowledgement

- 每筆 penalty 會生成或更新 `PaymentRecord` read model。
- `PaymentRecord.status` 固定為 `pending`、`acknowledged`、`disputed`。
- debtor 可執行 `markPaymentPaid`，creditor 可確認 `acknowledged` 或標記 `disputed`。
- 不做第三方支付串接；付款狀態只代表雙方在系統內的確認結果。

## 5. 畫面與導覽

| 畫面 | 目的 | 必要內容 |
| --- | --- | --- |
| Auth | 登入與 session 建立 | Sign in with Apple、登入失敗處理、未登入 fallback |
| Pairing | 建立或加入 couple | invite code/link、已配對鎖定狀態、couple 建立/加入結果 |
| Today Dashboard | 兩人今日總覽 | 自己今日清單、對方今日清單、完成率、partner 是否已提交明日計畫、下次 planning/settlement 倒數、reward 狀態、未確認欠款提示 |
| Tomorrow Planning | 填寫隔日計畫 | `required`/`optional` 分區、草稿、partner submitted、未送出離頁攔截、空 required 確認 UX |
| Task Editor | 新增或編輯單一 task | `title`、`notes`、`bucket`、`priority`、排序上下移或拖曳結果 |
| Settlement Gate | 強制處理每日結果 | full-screen gate、今日達標/未達標、欠款、未完成 required、acknowledgement、付款入口 |
| Settlement History | 查看歷史結果 | 日期、雙方 outcome、原始 obligation 與淨額 |
| Rewards | 顯示本週 reward 與下週草稿 | 本週 reward 狀態、日矩陣、下週 reward draft |
| Settings | 設定 couple 與個人偏好 | reminder times、grace、week start、penalty、通知權限、Time Sensitive 狀態、時區同步資訊 |
| Payment Acknowledgement | 單筆付款狀態 | 誰欠誰、來源日期、金額、`pending/acknowledged/disputed`、已付款與已確認時間 |

### 5.1 Full-screen Gate

- 若有未處理 settlement，App 前景啟動時必須優先顯示 settlement gate。
- gate 內允許的主要動作只有 `確認已看過`、`查看詳情`、`標記已支付`。
- 不允許以一般 close/dismiss 略過未確認 settlement。

### 5.2 Deep Links

| Link | 來源 | 導頁條件 |
| --- | --- | --- |
| `coupletodo://planning/{dateKey}` | 推播、Widget、Live Activity | 已登入且是 couple member，否則先導到 Auth |
| `coupletodo://settlement/{dateKey}` | settlement push、foreground gate | 已登入且對應 settlement 存在 |
| `coupletodo://rewards/{weekKey}` | reward push、dashboard、widget | 已登入 |
| `coupletodo://payments/{recordId}` | payment push、settlement、history | 已登入且是 record 相關方 |

## 6. 系統架構

### 6.1 CoupleTodoCore

- 只放 domain models、value objects、services、use cases、repository protocols。
- 不 import Firebase、SwiftUI、WidgetKit、ActivityKit。
- `LoadDashboardUseCase`、`SubmitNextDayPlanUseCase`、task mutation、settlement、reward finalize 都在此層。

### 6.2 App Layer

- 負責 SwiftUI navigation、feature state、Firebase SDK wiring、push permission、deep link router。
- 負責將 snapshot 寫入 App Group，供 Widget 與 Live Activity 讀取。
- 前景時負責依 pending settlement 或 planning 狀態決定 gate。

### 6.3 Backend Layer

- 負責 callable functions、scheduled jobs、Firestore writes、security rules、FCM/APNs push orchestration。
- settlement 與 reward finalize 以 backend 為唯一正式來源。
- backend 必須在 at-least-once 執行模型下保持冪等。

### 6.4 Source of Truth 原則

- `settlements`、`rewardWeeks.finalized fields`、`events`、`payments` 以 server 為真相。
- `plans` 與 `tasks` 允許 client optimistic update，但 server final 會覆蓋。
- Widget 與 Live Activity 只讀 `SharedSnapshot` 或 server-driven state，不直接查 Firestore 作為主要來源。

## 7. Domain 型別

### 7.1 核心型別

| Type | 必要欄位 | 語意 |
| --- | --- | --- |
| `UserProfile` | `id`, `displayName`, `photoURL`, `coupleId`, `currentTimezone`, `currentUtcOffsetMinutes`, `lastLocalDateKey`, `lastLocalWeekKey`, `notificationPreferences`, `createdAt`, `updatedAt` | 使用者個人資料與最近一次本地時間資訊 |
| `Couple` | `id`, `memberIds`, `status`, `weekStartsOn`, `penaltyPolicy`, `reminderConfig`, `inviteCode`, `createdAt`, `updatedAt` | couple 級規則與成員關係 |
| `ReminderConfig` | `planningReminderTime`, `planningCutoffTime`, `planningEscalationEveryMinutes`, `dailySettlementTime`, `dailySettlementGraceMinutes` | couple 共用時間規則 |
| `PenaltyPolicy` | `mode`, `amount`, `currency`, `enabled`, `planningMissPenaltyEnabled` | 每日罰則與是否啟用漏填計畫罰則 |
| `DailyPlan` | `id`, `userId`, `coupleId`, `dateKey`, `localTimezone`, `submittedAt`, `planningMissed`, `localUtcOffsetMinutes`, `lastEditedAt`, `requiredCount`, `optionalCount`, `version` | 單一使用者單日計畫 |
| `TodoTask` | `id`, `ownerUserId`, `dateKey`, `localTimezone`, `title`, `notes`, `bucket`, `priority`, `status`, `sortOrder`, `completedAtClient`, `completedAtServer`, `carriedFromTaskId`, `deleted`, `syncState`, `createdAt`, `updatedAt` | 單一 task 與同步狀態 |
| `SettlementResult` | `requiredTotal`, `requiredCompleted`, `missedRequiredCount`, `outcome`, `owesAmount` | 單一使用者單日結果摘要 |
| `DailySettlement` | `id`, `coupleId`, `subjectUserId`, `counterpartyUserId`, `dateKey`, `localTimezone`, `localWeekKey`, `state`, `computedAt`, `graceAppliedUntil`, `subjectResult`, `counterpartySnapshot`, `pendingAcknowledgementUserIds`, `rewardImpact` | server finalize 的每日結果 |
| `RewardWeek` | `id`, `coupleId`, `weekKey`, `effectiveWeekStartDate`, `draftedInWeekKey`, `rewardText`, `status`, `eligibility`, `memberLocalWeekKeys`, `finalizeWhenBothMembersWeekClosed`, `earnedAt`, `missedAt`, `updatedAt` | 週獎勵草稿與最終狀態 |
| `DeviceInstallation` | `id`, `userId`, `platform`, `fcmToken`, `apnsToken`, `timezone`, `utcOffsetMinutes`, `lastLocalDateKey`, `supportsLiveActivities`, `supportsTimeSensitive`, `appVersion`, `buildNumber`, `updatedAt` | 推播目標與裝置能力 |
| `EventLogEntry` | `id`, `coupleId`, `type`, `actorUserId`, `subjectId`, `payload`, `createdAt` | 稽核與除錯事件 |
| `PaymentRecord` | `id`, `coupleId`, `debtorUserId`, `creditorUserId`, `sourceSettlementId`, `sourceDateKey`, `amount`, `currency`, `status`, `markedPaidAt`, `acknowledgedAt`, `disputedAt`, `markedByUserId`, `acknowledgedByUserId`, `updatedAt` | 欠款 read model 與雙方確認狀態 |

### 7.2 Client Read Models

| Type | 最小欄位 | 語意 |
| --- | --- | --- |
| `SharedSnapshot` | `generatedAt`, `today`, `planning`, `settlement`, `reward`, `payments`, `nextReminder` | App Group 最小共享快照，不直接鏡像完整 Firestore |
| `PlanningReminderActivityContentState` | `selfSubmitted`, `partnerSubmitted`, `cutoffTime`, `remainingMinutes` | 規劃視窗 Live Activity 狀態 |
| `DailySettlementActivityContentState` | `selfOutcome`, `partnerOutcome`, `selfOwesAmount`, `partnerOwesAmount`, `needsAck` | 結算視窗 Live Activity 狀態 |

## 8. Repository Contracts

| Repository | 讀寫責任 | Client 可寫欄位 | Server-only 欄位 |
| --- | --- | --- | --- |
| `UserRepository` | 讀取/更新使用者個人資料與最近時區 | `displayName`, `photoURL`, `currentTimezone`, `notificationPreferences` | 伺服器衍生或驗證後回填欄位 |
| `CoupleRepository` | 建立/讀取/更新 couple 設定、invite code | `weekStartsOn`, `reminderConfig`, `penaltyPolicy` | `status`, 成員加入結果最終一致性 |
| `DeviceInstallationRepository` | 註冊 token、能力、時區 | `fcmToken`, `apnsToken`, `timezone`, `supportsLiveActivities`, `supportsTimeSensitive`, `appVersion` | 任何 server 追蹤欄位 |
| `PlanRepository` | 讀取/儲存 `DailyPlan` | 草稿與提交內容 | `planningMissed`, 伺服器逾時標記 |
| `TaskRepository` | task CRUD、排序、查詢 | `title`, `notes`, `bucket`, `priority`, `status`, `sortOrder`, `completedAtClient` | `completedAtServer`, settlement lock 後不可改寫 |
| `SettlementRepository` | 讀取 settlement、acknowledge | 只能寫自己的 acknowledgement | `state`, `computedAt`, `subjectResult`, `rewardImpact` |
| `RewardWeekRepository` | 讀取 reward、儲存下週草稿 | `rewardText` 只限下週 draft | `status`, `earnedAt`, `missedAt`, `eligibility` finalize |
| `EventRepository` | 追加與讀取事件 | client 不直接寫 raw doc；透過 use case 產生 | `createdAt`, server/system events |
| `PaymentRepository` | 讀取 payment record、mark paid、acknowledge/dispute | `markedPaidAt`, `acknowledgement/dispute` 僅限相關方 | record 建立、來源 settlement、金額 |

## 9. Firestore Schema

| Path | Key 規則 | 擁有者 |
| --- | --- | --- |
| `users/{userId}` | `userId = auth.uid` | 使用者本人可讀寫自己的 profile |
| `deviceInstallations/{installationId}` | 安裝實例 UUID | 安裝所屬使用者可更新自己的裝置資訊 |
| `couples/{coupleId}` | couple UUID | members 可讀；設定欄位可由 members 更新 |
| `couples/{coupleId}/plans/{userId_dateKey}` | `{userId}_{dateKey}` | plan owner 可寫；partner 可讀 |
| `couples/{coupleId}/plans/{userId_dateKey}/tasks/{taskId}` | task UUID | task owner 可寫；partner 可讀 |
| `couples/{coupleId}/settlements/{userId_dateKey}` | `{userId}_{dateKey}` | server 寫；members 讀；ack field 受限更新 |
| `couples/{coupleId}/rewardWeeks/{weekKey}` | ISO week key | draft text 由 member 寫；finalize 欄位 server 寫 |
| `couples/{coupleId}/payments/{recordId}` | payment UUID 或 settlement 衍生 key | server 建立；雙方對自己允許的 ack 欄位有限更新 |
| `couples/{coupleId}/events/{eventId}` | event UUID | server/system/use case append；members 讀 |

### 9.1 欄位 ownership

- `plans/tasks` 只能本人寫，partner 只能讀。
- `settlements`、`rewardWeeks.finalize fields`、`events`、`payments.amount/source` 只能 server 寫。
- `pendingAcknowledgementUserIds` 只能透過 acknowledgement flow 變更。
- `payments.markedPaidAt` 僅 debtor 可寫。
- `payments.acknowledgedAt` 與 `payments.disputedAt` 僅 creditor 可寫。

## 10. Backend Public Interfaces

### 10.1 Callable Functions

| Function | Request | Response | 常見錯誤 | 備註 |
| --- | --- | --- | --- | --- |
| `createCouple` | `displayName?`, `weekStartsOn?`, `reminderConfig?`, `penaltyPolicy?` | `coupleId`, `inviteCode`, `memberIds`, `status` | `unauthenticated`, `already_paired`, `invalid_policy` | 建立 user profile 與 couple；可重試但不可重複配對 |
| `joinCouple` | `inviteCode` | `coupleId`, `memberIds`, `status` | `unauthenticated`, `invite_not_found`, `couple_full`, `already_paired` | 冪等；已加入同一 couple 再呼叫應回成功 |
| `submitPlan` | `coupleId`, `targetDateKey`, `timezone`, `tasks[]`, `noRequiredTasksConfirmed` | `planId`, `submittedAt`, `requiredCount`, `optionalCount` | `invalid_window`, `empty_tasks`, `forbidden`, `date_mismatch` | server 需再次驗證 cutoff 與 task ownership |
| `acknowledgeSettlement` | `coupleId`, `settlementId` | `settlementId`, `pendingAcknowledgementUserIds` | `unauthenticated`, `settlement_not_found`, `forbidden` | 對同一 user 冪等 |
| `saveNextWeekReward` | `coupleId`, `rewardText` | `rewardWeekId`, `weekKey`, `status` | `unauthenticated`, `forbidden`, `reward_locked`, `invalid_text` | 只能寫下週 draft |
| `markPaymentPaid` | `coupleId`, `paymentRecordId` | `paymentRecordId`, `status`, `markedPaidAt` | `unauthenticated`, `record_not_found`, `forbidden`, `invalid_state` | debtor 對同一 record 冪等 |

### 10.2 Scheduled Jobs

| Job | 觸發條件 | 副作用 | 冪等策略 |
| --- | --- | --- | --- |
| `planningReminderJob` | 每 5 分鐘掃描進入 planning reminder window 的裝置 | 發 `planning_reminder` 或 `planning_escalation` push | 以 `userId + dateKey + reminderBucket` 去重 |
| `planningMissJob` | 每 5 分鐘掃描已超過 cutoff 且未提交 plan 的使用者 | 寫入 `planningMissed = true`、產生事件、更新 reward eligibility | 只在 `planningMissed == false` 時轉成 `true` |
| `dailySettlementJob` | 每 5 分鐘掃描超過 settlement cutoff 的使用者日期 | finalize settlement、建立或更新 payment record、發 settlement push | 以 `userId_dateKey` 為唯一 key；已 finalized 則跳過 |
| `weeklyRewardFinalizeJob` | 每 24 小時掃描兩位成員都跨過本地週界線的 rewardWeek | 將 reward 轉為 `earned` 或 `missed`、發 reward push | 只處理 `active` 狀態 |
| `snapshotCompactionJob` | 每 24 小時整理 read model | 壓縮舊 events、重建 payment net summary、清理過期 snapshot | 只重建唯讀資料，不改寫 finalized 結果 |

## 11. iOS 系統整合

### 11.1 Notification Categories

| Category | 來源 | 用途 |
| --- | --- | --- |
| `planning_reminder` | remote，必要時 local fallback | 21:30 起提醒填明日計畫 |
| `planning_escalation` | remote | cutoff 前每 15 分鐘加強提醒 |
| `settlement_ready` | remote | settlement finalized 後提醒進 gate |
| `reward_earned` | remote | 週獎勵解鎖通知 |
| `payment_pending` | remote | 尚有待確認 payment record |

### 11.2 Shared Snapshot

`SharedSnapshot` 最小資料集合固定包含:

- 自己今日 required/optional 統計。
- 對方今日摘要。
- planning target date 與雙方 submitted 狀態。
- 待處理 settlement 狀態。
- reward 狀態。
- payment pending 摘要。
- 下一個提醒倒數。

### 11.3 Widget 邊界

- Widget 用於長時段狀態可見性，不直接查 Firestore。
- Widget 只讀 App Group snapshot。
- 至少提供 small、medium、lock screen/accessory 三種型態。
- 互動只做快速導頁與少量 App Intents 操作，不把複雜表單塞進 widget。

### 11.4 Live Activity 邊界

- `PlanningReminderActivity` 只在晚間 planning 視窗存在。
- `DailySettlementActivity` 只在 settlement 視窗存在。
- Live Activity 不用來當全天儀表板，不承擔完整 CRUD。

### 11.5 Background Refresh 與降級策略

- Background Refresh 只用來補抓 snapshot、刷新本地倒數與清理過期 UI。
- 若 remote push 失敗，App 可排本地 fallback reminder，但最終逾時與 settlement 仍由 server 定案。
- 若 Time Sensitive 未授權，Settings 必須顯示降級說明與修復入口。
- 若 Widget/Live Activity 無法用，Dashboard 與 foreground gate 仍須完整工作。

## 12. Sync、Audit、Security

### 12.1 離線與同步策略

- `plans` 與 `tasks` 支援 optimistic update。
- `TodoTask.syncState` 固定為 `local_pending`、`synced`、`server_final`。
- client 完成 task 時先寫 `completedAtClient` 供本地 UI 立即回饋。
- server 接收後寫 `completedAtServer`；正式 settlement 以 server 可接受的完成狀態為準。
- 若 `completedAtClient` 與 server 收到時間差異過大，server 以自身時間為準並記錄事件。
- settlement finalized 後，該日任務進入不可改寫狀態。

### 12.2 Event Audit

必備事件固定為:

- `task_created`
- `task_updated`
- `task_deleted`
- `task_completed`
- `task_uncompleted`
- `plan_submitted`
- `planning_missed`
- `settlement_finalized`
- `settlement_acknowledged`
- `weekly_reward_drafted`
- `weekly_reward_earned`
- `weekly_reward_missed`
- `payment_marked_paid`

### 12.3 Security Rules 原則

- 只有 auth user 自己能寫 `users/{userId}` 與自己的 `deviceInstallations`。
- couple members 可讀彼此 `plans/tasks/settlements/rewardWeeks/payments/events`。
- `settlements`、`events` 的核心內容只能 server 寫。
- `rewardWeeks` 只有 reward draft text 可由 member 在允許時窗更新。
- locked day、finalized settlement、finalized reward 一律禁止 client 改寫。

## 13. 測試與完成定義

### 13.1 Unit Tests

必測:

- task 排序與 priority/bucket 規則
- planning cutoff 與 reminder window
- `planningMissed`
- settlement grace
- `flat_per_day` penalty
- reward eligibility
- payment record 建立與狀態轉移
- 跨時區 `dateKey/weekKey`
- 時區切換
- `completedAtClient` / `completedAtServer` 取捨

### 13.2 Integration Tests

必測:

- `createCouple`
- `joinCouple`
- `submitPlan`
- task CRUD
- `dailySettlementJob`
- `weeklyRewardFinalizeJob`
- payment acknowledgement
- device installation sync
- Firestore security rules
- at-least-once job idempotency

### 13.3 UI Tests

必測:

- 首次登入與配對
- 今日雙欄總覽
- 建立隔日計畫
- 未提交前離頁攔截
- settlement full-screen gate
- 標記已支付
- reward draft 編輯
- notification deep link routing

### 13.4 真機驗收

必測:

- APNs/FCM 鏈路
- Time Sensitive 權限
- Live Activity 啟停
- Widget 刷新
- App Group snapshot 同步
- notification tap routing
- App 回前景自動 gate
- 不同時區雙機測試

### 13.5 失敗場景

必須單列驗證:

- 單邊離線
- 雙方同時編輯
- 23:59 前後秒級邊界
- 時區突然變更
- 使用者清除通知
- server job 重跑
- 付款確認爭議

### 13.6 Definition of Done

只有同時達成以下條件，才算 v1 完成:

- iOS 五個主流程能在真實 Firebase 上跑通，不再只依賴 mock data。
- Auth、Pairing、Dashboard、Planning、Settlement、Rewards、Settings、Payments 都有實際資料來源。
- 通知鏈路可在兩台真機上驗證。
- 一週 reward 與每日 settlement 可由排程自動產生。
- Widget 與 Live Activity 讀取 App Group snapshot 正常。
- 文件內所有介面、欄位、deep links、notification categories 都能在實作中對應。

## 14. v1 明確不做

- 第三方支付與自動扣款。
- 多人群組或家庭模式。
- Android、watchOS、macOS 專屬版本。
- 用 client 計算結果直接覆蓋 server settlement/reward。
