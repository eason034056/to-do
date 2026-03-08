# 伴侶雙人 To-Do iOS App 開發文檔

更新日期: 2026-03-08

本文檔直接定義一個可以落地實作的 v1 方案，目標是讓你可以依照本文檔開始建立 iOS App 與後端，不需要先再做一輪產品猜測。本文檔採用的主方案是:

- iOS: Swift + SwiftUI
- 後端: Firebase Auth + Firestore + Cloud Functions + Cloud Scheduler + FCM/APNs
- iOS 系統整合: UserNotifications + WidgetKit + ActivityKit + App Intents

如果你堅持後端也要用 Swift，可以把 Cloud Functions 替換成 Vapor + PostgreSQL + APNs provider，但不建議作為 v1，因為開發與維運成本更高。

## 1. 產品目標

這個 App 的核心不是一般待辦清單，而是「雙人承諾追蹤系統」。它要解決四件事:

1. 每天晚上兩個人都要先列出隔天的事項。
2. 兩個人都能即時看到彼此當天要做什麼。
3. 每天結算是否完成「一定要完成」的事項，並觸發懲罰。
4. 連續一整週都達標時，解鎖一個上週先寫好的獎勵。

因此，App 的設計重點不是單純 CRUD，而是:

- 強提醒
- 可核對
- 可結算
- 有儀式感
- 規則不可模糊

## 2. 先講清楚的 iOS 系統限制

你的需求裡有兩個點，必須先技術上講清楚，否則後面開發方向會錯:

### 2.1 App 不能在 iPhone 主畫面上強制打開自己的全螢幕頁面

一般 App 不能在使用者停留在 Home Screen 時，自動把自家 UI 蓋到最上面。也不能像 Android overlay 那樣常駐攔截。

可行替代方案:

- Time Sensitive 通知
- Home Screen Widget
- Live Activity
- App Icon Badge
- 使用者點通知後深連結到特定頁
- 使用者下次打開 App 時，用 fullScreenCover 強制先處理未完成的提醒或結算

### 2.2 通知不能做到「沒有填完就永遠不能手動消除」

iOS 不允許一般 App 控制系統通知是否能被使用者清除。你可以做到的是:

- 未提交前持續重送提醒通知
- Live Activity 持續顯示未完成狀態
- Widget 持續顯示紅色未完成狀態
- App 內頁面在未處理前持續強制顯示

也就是說，v1 可以做到「未完成前，所有可見入口都一直提醒你」，但不能做到「系統通知本身完全不能被滑掉」。

### 2.3 背景排程不能當作精準鬧鐘

iOS 的 Background Tasks 不是精準定時器，不能保證 21:30 或 23:59 一定準時喚醒 App 執行邏輯。真正需要準時的提醒與結算，不能只靠本機背景任務，必須交給伺服器排程加推播。

### 2.4 Live Activity 很適合「強存在感」，但不是全天候萬能面板

Live Activity 很醒目，但有系統限制:

- 活動最長約 8 小時
- 結束後最多還會留在鎖定畫面約 4 小時
- 單一 Live Activity 的資料總量限制很小

因此本產品應把 Live Activity 用在「晚間規劃提醒視窗」和「每日結算視窗」，不要拿它當 24 小時常駐主畫面。

### 2.5 Critical Alerts 不適合作為 v1 方案

Critical Alerts 需要 Apple 特別 entitlement。這種權限通常只給醫療、公共安全、居家安全等極高緊急性場景。這個產品不應把它當作可預期能力。

v1 正確做法:

- 先用 Time Sensitive 通知
- 搭配 Widget、Live Activity、Badge、App 內攔截頁

## 3. 推薦產品規則

這一節是整個系統最重要的部分。規則如果不先定死，後面資料模型和結算邏輯會一直返工。

### 3.1 核心角色

- `User`: 單一使用者
- `Couple`: 一對伴侶，固定只有 2 個成員

一個 `Couple` 同時擁有:

- 共用規則設定
- 每日提醒設定
- 每日結算設定
- 懲罰規則
- 每週獎勵規則

### 3.2 每日任務分類

每個任務有兩個維度，不要混成同一個欄位:

1. 任務性質 `bucket`
- `required`: 一定要完成
- `optional`: 可以不在當天完成

2. 優先級 `priority`
- `p0`: 最重要，今日核心
- `p1`: 高
- `p2`: 中
- `p3`: 低

排序規則建議:

1. `required` 在前
2. 同 bucket 內依 `priority` 由高到低
3. 同 priority 內依使用者拖曳排序 `sortOrder`

### 3.3 每日時間軸

以下改為「每個使用者以自己裝置當地時間」作為唯一日界線。也就是說:

- A 在紐約，就用紐約當地時間提醒、截止、結算
- B 在東京，就用東京當地時間提醒、截止、結算
- 伺服器不以 couple 共用時區做結算
- 伺服器會根據裝置最近一次上報的時區資訊，計算該使用者目前的 `localDateKey`

這代表在同一個真實世界時間點，兩個人可能正在不同的「今天」。

產品顯示規則也必須跟著改:

- 首頁顯示 `你的今天` 與 `對方當地今天`
- 若兩人 date 不同，UI 必須明確顯示兩邊各自的日期與時區縮寫
- 所有週獎勵判定都以各自 local week 計算，並在兩人都跨過該週之後才 finalize

建議預設:

- `planningReminderTime`: 21:30
- `planningEscalationEveryMinutes`: 15
- `planningCutoffTime`: 23:00
- `dailySettlementTime`: 23:59
- `dailySettlementGraceMinutes`: 5
- `weekStartsOn`: Monday

### 3.4 每晚規劃規則

每天晚上，兩個人都要為「隔天」建立一份計畫。

計畫至少包含:

- 明天一定要完成的事項
- 明天可以做，但不一定要完成的事項

建議規則:

- 在使用者自己的 `planningReminderTime` 開始提醒建立明日計畫
- 若使用者自己的 `planningCutoffTime` 前未提交，系統標記 `planningMissed = true`
- `planningMissed = true` 預設不直接罰 50 美金，但會:
  - 顯示高優先級警告
  - 讓當週獎勵失去資格
  - 可在設定裡開啟「漏填明日計畫也要罰」

這個設計比「漏填計畫就自動當作明天沒任務」合理，否則有人會利用規則漏洞逃避承諾。

### 3.5 每日結算規則

每天在每個使用者自己的 `dailySettlementTime + grace` 之後跑結算。

對每個人:

- 只檢查該使用者「自己當地日期」當日的 `required` 任務
- 只要有任何 `required` 未完成，該日判定失敗

懲罰規則 v1 建議採固定日罰而不是逐項罰:

- `penaltyMode = flat_per_day`
- `penaltyAmount = 50`
- `currency = USD`

也就是:

- 若 A 今日有任何必做未完成，A 欠 B 50 美金
- 若 B 今日有任何必做未完成，B 欠 A 50 美金
- 若兩人都失敗，則兩邊都各欠對方 50，美觀上可在結算畫面顯示為互相抵消，也可以顯示雙方各自失敗
- 若兩人因時區不同而在不同 UTC 時刻完成各自結算，App 應顯示最近一次雙方結算結果與各自 local date label

建議 UI 顯示:

- `今日達標`
- `今日未達標`
- `你今日應支付 $50`
- `對方今日應支付 $50`

### 3.6 每週獎勵規則

每週獎勵的文案必須在前一週填好，於下一週生效。

範例:

- 第 10 週要拿到的獎勵，必須在第 9 週內填好

獎勵解鎖條件:

- 本週兩人每天都沒有任何 `required` 未完成
- 本週兩人每天都沒有 `planningMissed`

如果任一天任一人失敗:

- 本週獎勵狀態變成 `missed`

如果整週全綠:

- 週日結束後，獎勵狀態變成 `earned`

### 3.7 允許補改的規則

這裡一定要定死，不然會吵架:

- 當日 `required` 任務是否允許在結算後補打勾: 不允許
- 當日 `required` 任務是否允許在結算前編輯刪除: 允許，但所有修改都記錄事件
- 已提交的明日計畫是否可再編輯: 允許到隔日 00:00 前

建議:

- 開啟 edit history
- settlement 鎖定後，歷史資料不可被客戶端改寫

## 4. 功能清單

## 4.1 帳號與配對

- Sign in with Apple
- 可加上 Email Sign-In 作為備援
- 建立 couple
- 產生邀請碼 / 邀請連結
- 另一方加入後形成固定雙人關係
- 可設定各自提醒時間、罰則金額、週起始日

v1 不建議支援:

- 多伴侶
- 群組
- 家庭共享

## 4.2 今日雙人總覽

首頁要同時看到兩個人今天的清單與狀態:

- 自己今日 `required` 列表
- 自己今日 `optional` 列表
- 對方當地今日 `required` 列表
- 對方當地今日 `optional` 列表
- 今日完成率
- 對方是否已提交明日計畫
- 今日距離結算剩餘時間

版面建議:

- 上方: 今日日期、倒數、雙人摘要
- 中間: 左右雙欄或上下分區顯示雙人清單
- 下方: 快速新增任務、切換到明日規劃、週獎勵狀態

若雙方位於不同時區:

- 自己欄位顯示 `Today - Mar 8 (CDT)` 這類本地日期標籤
- 對方欄位顯示 `Partner Today - Mar 9 (JST)` 這類對方本地日期標籤
- 不要強行把兩人的 task 合併到同一個 dateKey

## 4.3 任務 CRUD

任務欄位:

- 標題 `title`
- 補充說明 `notes`
- bucket `required/optional`
- priority `p0/p1/p2/p3`
- 狀態 `pending/completed/missed/carried_over`
- 排序 `sortOrder`
- 建立時間
- 完成時間
- 建立者

操作:

- 新增
- 編輯
- 刪除
- 完成 / 取消完成
- 拖曳排序
- optional 任務一鍵帶到隔天

## 4.4 明日規劃頁

這一頁是晚間儀式的核心:

- 頁面預設建立「明天」計畫
- 區分 `明天一定要完成` 與 `明天可做可不做`
- 顯示對方是否已提交
- 提交後給一個強烈完成狀態

提交條件建議:

- 至少 1 個任務才能提交
- 至少要有 1 個 `required` 任務，或使用者需要明確確認「我明天沒有必做事項」

這樣能避免用空白清單規避承諾。

## 4.5 每日結算頁

這一頁要做得非常醒目，視覺上應該像「每日判決」而不是普通列表。

內容:

- 今日日期
- 兩人各自完成 / 未完成數
- 每個人的未完成 `required` 清單
- 應支付金額或其他懲罰
- 今日是否影響本週獎勵
- 確認已看過結算

v1 建議:

- 使用全畫面紅 / 綠分區
- 支援深連結直達
- 若 App 在前景，直接以 full-screen modal 彈出
- 若 App 被使用者打開且仍未 ack，先擋住首頁，必須先看結算

## 4.6 每週獎勵頁

內容:

- 當週目標獎勵
- 這個獎勵是哪一週寫下的
- 本週每日雙人達標矩陣
- 目前是否仍有資格解鎖
- 下週獎勵草稿編輯器

規則:

- 只能編輯「下週獎勵」
- 當週開始後，當週獎勵不可更改
- 如果上週沒填，下週沒有獎勵可解鎖

## 4.7 提醒系統

提醒分兩類:

1. 晚間明日規劃提醒
2. 每日結算結果提醒

提醒介面分四層:

- 推播通知
- Live Activity
- Widget
- App 內強制頁

## 4.8 Widget

建議至少做 3 種:

1. Small Widget
- 顯示自己與對方今日必做完成數

2. Medium Widget
- 顯示雙方 top 3 必做事項與達成狀態

3. Lock Screen / Accessory Widget
- 顯示今日剩餘未完成必做數

互動:

- 使用 App Intents 提供快速完成勾選
- 點擊 Widget 進 App 對應頁面

## 4.9 Live Activity

只用在兩個場景:

1. 晚間規劃視窗
- 顯示: 是否已提交明日計畫
- 行動: 開啟規劃頁

2. 每日結算視窗
- 顯示: 今日達標 / 未達標、應支付金額
- 行動: 開啟結算頁

不建議:

- 一整天都開著追蹤今日待辦

因為 Live Activity 時間限制與系統回收策略不適合這種用法。

## 5. 推薦技術棧

## 5.1 iOS 端

- Swift 6
- SwiftUI
- Observation
- Structured Concurrency
- App Intents
- WidgetKit
- ActivityKit
- UserNotifications
- Firebase iOS SDK
- SwiftData 作為本機快取層

### 為什麼要 SwiftData

雖然 Firestore 有離線能力，但本產品還要支援:

- Widget 讀取快照
- App 啟動時立即顯示最近狀態
- 本地 fallback 畫面
- 事件歷史與本地 optimistic UI

因此建議:

- 雲端真實來源: Firestore
- 本地讀取快取: SwiftData
- Widget / Live Activity 共用資料: App Group snapshot

## 5.2 後端

- Firebase Auth
- Firestore
- Cloud Functions for Firebase
- Cloud Scheduler
- Firebase Cloud Messaging
- Apple Push Notification service

後端還需要維護:

- 使用者目前裝置時區 snapshot
- 使用者 local date / local week 對應
- 依使用者本地時間排程提醒與結算

### 為什麼不建議 v1 用 CloudKit

這個產品的真正難點是「準時結算」與「跨裝置雙方一致邏輯」，不是資料同步本身。

CloudKit 擅長 Apple 生態內同步，但本產品還需要:

- 伺服器排程
- 固定時間自動結算
- 依使用者當前裝置時區批次發送提醒
- 後端可信任計算結果
- 後台推播編排

這些用 Firebase 會比 CloudKit 更直接。

## 5.3 專案 targets

至少拆成:

1. `CoupleTodoApp`
2. `CoupleTodoWidgetExtension`
3. `CoupleTodoNotificationServiceExtension`

可選:

4. `CoupleTodoIntentsExtension` 或直接用 App Intents in app / widget target

## 6. 架構設計

建議採用:

- UI: SwiftUI
- State: Feature-scoped observable view models
- Domain: Use cases / services
- Data: Repository pattern

不要在 v1 一開始就引入過重架構。推薦分層:

- `Presentation`
- `Domain`
- `Data`
- `Platform`

### 6.1 模組切分

建議資料夾:

```text
App/
  CoupleTodoApp.swift
  AppCoordinator.swift
  RootView.swift

Core/
  DesignSystem/
  Extensions/
  Utilities/
  Routing/

Domain/
  Models/
  Enums/
  UseCases/
  Repositories/
  Policies/

Data/
  DTOs/
  Repositories/
  Firestore/
  SwiftData/
  Mappers/

Features/
  Auth/
  CoupleSetup/
  Dashboard/
  TodayBoard/
  TomorrowPlanning/
  TaskEditor/
  Settlement/
  Rewards/
  Settings/

Platform/
  Notifications/
  LiveActivities/
  Widgets/
  DeepLinks/
  AppGroup/

WidgetExtension/
  Widgets/
  Intents/
  SharedViews/

NotificationServiceExtension/
```

### 6.2 畫面導覽

主要路由:

- `/auth`
- `/pairing`
- `/dashboard/today`
- `/planning/{dateKey}`
- `/settlement/{dateKey}`
- `/rewards/current`
- `/settings`

深連結格式建議:

- `coupletodo://planning/2026-03-09`
- `coupletodo://settlement/2026-03-08`
- `coupletodo://rewards/2026-W10`

## 7. 資料模型

## 7.1 Swift Domain Models

```swift
enum TodoBucket: String, Codable, Sendable {
    case required
    case optional
}

enum TodoPriority: Int, Codable, Sendable, Comparable {
    case p0 = 0
    case p1 = 1
    case p2 = 2
    case p3 = 3

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum TodoStatus: String, Codable, Sendable {
    case pending
    case completed
    case missed
    case carriedOver
}

enum SettlementOutcome: String, Codable, Sendable {
    case pass
    case fail
}

struct TodoTask: Identifiable, Codable, Sendable {
    let id: String
    let ownerUserId: String
    let dateKey: String
    var title: String
    var notes: String?
    var bucket: TodoBucket
    var priority: TodoPriority
    var status: TodoStatus
    var sortOrder: Double
    var createdAt: Date
    var updatedAt: Date
    var completedAtClient: Date?
    var completedAtServer: Date?
    var carriedFromTaskId: String?
}

struct DailyPlan: Identifiable, Codable, Sendable {
    let id: String
    let userId: String
    let coupleId: String
    let dateKey: String
    var submittedAt: Date?
    var lastEditedAt: Date
    var planningMissed: Bool
    var requiredCount: Int
    var optionalCount: Int
}

struct DailySettlement: Identifiable, Codable, Sendable {
    let id: String
    let coupleId: String
    let dateKey: String
    let computedAt: Date
    let results: [String: UserSettlementResult]
}

struct UserSettlementResult: Codable, Sendable {
    let requiredTotal: Int
    let requiredCompleted: Int
    let missedRequiredCount: Int
    let outcome: SettlementOutcome
    let owesAmount: Decimal
}
```

## 7.2 Firestore 文件結構

```text
users/{userId}
deviceInstallations/{installationId}
couples/{coupleId}
couples/{coupleId}/invites/{inviteId}
couples/{coupleId}/plans/{planId}
couples/{coupleId}/plans/{planId}/tasks/{taskId}
couples/{coupleId}/settlements/{settlementId}
couples/{coupleId}/rewardWeeks/{weekKey}
couples/{coupleId}/events/{eventId}
```

### 7.2.1 users/{userId}

```json
{
  "displayName": "W",
  "photoURL": null,
  "coupleId": "cpl_123",
  "currentTimezone": "America/Chicago",
  "currentUtcOffsetMinutes": -360,
  "lastLocalDateKey": "2026-03-08",
  "lastLocalWeekKey": "2026-W10",
  "lastTimezoneSyncedAt": "serverTimestamp",
  "notificationPrefs": {
    "planningReminderEnabled": true,
    "settlementReminderEnabled": true,
    "timeSensitiveAllowed": true
  },
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### 7.2.2 deviceInstallations/{installationId}

用來存 APNs/FCM token 與裝置能力:

```json
{
  "userId": "usr_1",
  "platform": "ios",
  "fcmToken": "...",
  "apnsToken": "...",
  "timezone": "America/Chicago",
  "utcOffsetMinutes": -360,
  "lastLocalDateKey": "2026-03-08",
  "supportsLiveActivities": true,
  "supportsTimeSensitive": true,
  "appVersion": "1.0.0",
  "buildNumber": "1",
  "updatedAt": "serverTimestamp"
}
```

### 7.2.3 couples/{coupleId}

```json
{
  "memberIds": ["usr_1", "usr_2"],
  "status": "active",
  "weekStartsOn": "monday",
  "penaltyPolicy": {
    "mode": "flat_per_day",
    "amount": 50,
    "currency": "USD",
    "enabled": true,
    "planningMissPenaltyEnabled": false
  },
  "reminderConfig": {
    "planningReminderTime": "21:30",
    "planningCutoffTime": "23:00",
    "planningEscalationEveryMinutes": 15,
    "dailySettlementTime": "23:59",
    "dailySettlementGraceMinutes": 5
  },
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp"
}
```

### 7.2.4 couples/{coupleId}/plans/{planId}

`planId` 建議格式:

- `{userId}_{dateKey}`

範例:

- `usr_1_2026-03-09`

文件內容:

```json
{
  "userId": "usr_1",
  "coupleId": "cpl_123",
  "dateKey": "2026-03-09",
  "localTimezone": "America/Chicago",
  "localUtcOffsetMinutes": -360,
  "submittedAt": "serverTimestamp",
  "lastEditedAt": "serverTimestamp",
  "planningMissed": false,
  "requiredCount": 3,
  "optionalCount": 2,
  "version": 5
}
```

### 7.2.5 couples/{coupleId}/plans/{planId}/tasks/{taskId}

```json
{
  "ownerUserId": "usr_1",
  "dateKey": "2026-03-09",
  "localTimezone": "America/Chicago",
  "title": "完成產品規格第一版",
  "notes": "至少寫完架構和資料模型",
  "bucket": "required",
  "priority": "p0",
  "status": "pending",
  "sortOrder": 1000,
  "createdAt": "serverTimestamp",
  "updatedAt": "serverTimestamp",
  "completedAtClient": null,
  "completedAtServer": null,
  "carriedFromTaskId": null,
  "deleted": false
}
```

### 7.2.6 couples/{coupleId}/settlements/{settlementId}

`settlementId` 建議格式:

- `{userId}_{dateKey}`

```json
{
  "settlementId": "usr_1_2026-03-08",
  "subjectUserId": "usr_1",
  "counterpartyUserId": "usr_2",
  "dateKey": "2026-03-08",
  "localTimezone": "America/Chicago",
  "localWeekKey": "2026-W10",
  "state": "finalized",
  "computedAt": "serverTimestamp",
  "graceAppliedUntil": "2026-03-09T00:05:00-06:00",
  "subjectResult": {
    "requiredTotal": 4,
    "requiredCompleted": 3,
    "missedRequiredCount": 1,
    "outcome": "fail",
    "owesAmount": 50
  },
  "counterpartySnapshot": {
    "latestKnownDateKey": "2026-03-08",
    "latestKnownOutcome": "pass"
  },
  "pendingAcknowledgementUserIds": ["usr_1", "usr_2"],
  "rewardImpact": {
    "weekKey": "2026-W10",
    "stillEligible": false
  }
}
```

### 7.2.7 couples/{coupleId}/rewardWeeks/{weekKey}

```json
{
  "weekKey": "2026-W10",
  "effectiveWeekStartDate": "2026-03-02",
  "draftedInWeekKey": "2026-W09",
  "rewardText": "週末去吃一次想吃很久的餐廳",
  "status": "active",
  "eligibility": {
    "usr_1": true,
    "usr_2": true
  },
  "memberLocalWeekKeys": {
    "usr_1": "2026-W10",
    "usr_2": "2026-W10"
  },
  "finalizeWhenBothMembersWeekClosed": true,
  "earnedAt": null,
  "missedAt": null,
  "updatedAt": "serverTimestamp"
}
```

### 7.2.8 couples/{coupleId}/events/{eventId}

這個 collection 很重要，用來做審計與追蹤。

```json
{
  "type": "task_completed",
  "actorUserId": "usr_1",
  "subjectId": "task_123",
  "payload": {
    "dateKey": "2026-03-08",
    "title": "健身"
  },
  "createdAt": "serverTimestamp"
}
```

建議至少紀錄:

- task_created
- task_updated
- task_deleted
- task_completed
- task_uncompleted
- plan_submitted
- planning_missed
- settlement_finalized
- weekly_reward_drafted
- weekly_reward_earned
- weekly_reward_missed

## 8. 關鍵業務邏輯

## 8.1 明日計畫提交邏輯

`submitTomorrowPlan(userId, dateKey)`

條件:

- 只能提交該使用者自己本地時區中的未來一天計畫
- 只能提交自己的計畫
- 至少一個任務，或明確選擇 `noRequiredTasksConfirmed = true`

副作用:

- 寫入 plan summary
- 更新 counts
- 清除未提交提醒狀態
- 更新 widget snapshot
- 若有晚間規劃 Live Activity，更新為已提交

## 8.2 任務完成邏輯

`toggleTaskCompletion(taskId, completed)`

規則:

- 只能操作自己的任務
- settlement finalized 後不可再改
- 若設為 completed:
  - 同時寫 `completedAtClient`
  - 由 server function 補 `completedAtServer`

為了減少離線造成的爭議，結算時建議採這個規則:

- 主要以 `completedAtServer` 判定
- 若離線補傳且 `completedAtClient` 早於「該使用者本地 cutoff」，允許在 `maxClockSkewMinutes = 3` 內被接受

這是產品決策，不是純技術問題。若你們兩人更在意公平可驗證，就完全只認 `completedAtServer`。若更在意使用體驗，就容許少量 client time grace。

## 8.3 每日結算演算法

輸入:

- `coupleId`
- `userId`
- `dateKey`
- 該使用者本地日期下的 plan 與 tasks

對 `subjectUser`:

1. 找出 `bucket == required`
2. 計算 `requiredTotal`
3. 計算在該使用者本地 cutoff 前完成的 `requiredCompleted`
4. `missedRequiredCount = total - completed`
5. `outcome = pass` if `missedRequiredCount == 0` else `fail`
6. `owesAmount = penaltyAmount` if fail else `0`

再計算週獎勵影響:

- 若任一 member 在自己的 local week 內 fail，該週資格失效
- 若任一 member 在自己的 local week 內 `planningMissed == true`，該週資格失效

## 8.4 週獎勵演算法

在每次單人 local-day 結算後更新當週 eligibility。

週結束時:

- 若兩位成員各自 local week 都結束且 eligibility 全為 true，reward status -> `earned`
- 若其中一人 local week 已失敗，reward status -> `missed`

## 9. 後端 Functions 設計

建議用 TypeScript。

## 9.1 Callable Functions

1. `createCouple`
- 建立 couple
- 寫入 creator member
- 回傳 invite code

2. `joinCouple`
- 驗證 invite code
- 將 user 加入 couple

3. `submitPlan`
- 驗證資料
- 更新 plan summary
- 可選: server side recalc counts

4. `acknowledgeSettlement`
- 將 user 從 `pendingAcknowledgementUserIds` 移除

5. `saveNextWeekReward`
- 僅允許編輯下週 reward

## 9.2 Scheduled Jobs

1. `planningReminderJob`
- 每 5 分鐘跑一次
- 掃描目前時間等於各 user 本地 `planningReminderTime` 或 escalation time 的組
- 對未提交者發送 Time Sensitive push
- 啟動或更新晚間規劃 Live Activity

2. `planningMissJob`
- 每 5 分鐘跑一次
- 對超過使用者本地 `planningCutoffTime` 仍未提交者標記 `planningMissed`
- 更新 widget snapshot / push escalation

3. `dailySettlementJob`
- 每 5 分鐘跑一次
- 對達到使用者本地 `settlementTime + grace` 的 user-day 進行日結算
- 寫入 settlement doc
- 發送結算通知
- 啟動或更新 settlement Live Activity

4. `weeklyRewardFinalizeJob`
- 每週跑一次
- 將上週 reward 標記 earned / missed
- 建立未來一週 reward placeholder

5. `snapshotCompactionJob`
- 清理舊 snapshot / 舊 events / 已過期活動 metadata

## 9.3 Push Payload 設計

### 規劃提醒

```json
{
  "type": "planning_reminder",
  "dateKey": "2026-03-09",
  "deeplink": "coupletodo://planning/2026-03-09"
}
```

APNs 屬性:

- `apns-push-type: alert`
- `apns-priority: 10`
- `interruption-level: time-sensitive`

### 每日結算

```json
{
  "type": "daily_settlement",
  "dateKey": "2026-03-08",
  "deeplink": "coupletodo://settlement/2026-03-08"
}
```

## 10. iOS 通知策略

## 10.1 權限申請時機

不要一啟動就跳通知授權。建議在以下時機詢問:

- 使用者完成配對後
- 或第一次設定晚間提醒時間時

授權需求:

- `.alert`
- `.sound`
- `.badge`

若要支援更強提醒，再檢查:

- time sensitive 設定是否可用

## 10.2 通知類型

### A. Local Notifications

用途:

- 本機備援提醒
- App 已知的固定提醒時間

### B. Remote Notifications

用途:

- 伺服器計算後發送的真正結算結果
- 對 partner 狀態同步的提醒
- 多裝置一致提醒

### C. Notification Service Extension

用途:

- 修改通知內容
- 加上更醒目的文案
- 根據 payload 附加縮圖或摘要

## 10.3 通知分類

```text
PLANNING_REMINDER
PLANNING_MISSED
DAILY_SETTLEMENT
WEEKLY_REWARD_EARNED
```

每個 category 可帶 actions:

- `OPEN_PLANNING`
- `OPEN_SETTLEMENT`
- `MARK_ACKNOWLEDGED`

注意:

- 通知 action 適合快速開啟頁面
- 不建議直接從通知做過多資料變更，避免權限與一致性複雜度上升

## 11. Widget 與 App Group 設計

Widget 不應直接依賴線上查詢當作主資料來源。建議:

1. App 監聽 Firestore/SwiftData 變更
2. 產生一份精簡 snapshot JSON
3. 寫入 App Group 容器
4. Widget 讀 App Group snapshot

### 11.1 App Group Snapshot 結構

檔案:

- `group.com.yourcompany.coupletodo/shared_snapshot.json`

內容範例:

```json
{
  "generatedAt": "2026-03-08T21:35:00-06:00",
  "today": {
    "selfDateKey": "2026-03-08",
    "partnerDateKey": "2026-03-09",
    "self": {
      "timezone": "CDT",
      "requiredRemaining": 2,
      "requiredCompleted": 3,
      "topTasks": ["健身", "寫文檔"]
    },
    "partner": {
      "timezone": "JST",
      "requiredRemaining": 1,
      "requiredCompleted": 4,
      "topTasks": ["回 email", "看醫生"]
    }
  },
  "planning": {
    "targetDateKey": "2026-03-09",
    "selfSubmitted": false,
    "partnerSubmitted": true
  },
  "settlement": {
    "selfDateKey": "2026-03-08",
    "partnerLatestDateKey": "2026-03-08",
    "isPendingAck": true,
    "selfOutcome": "fail",
    "partnerOutcome": "pass",
    "selfOwesAmount": 50
  }
}
```

### 11.2 Widget 重新整理策略

- App 前景更新時主動 `reloadTimelines`
- 結算推播進來時更新 snapshot
- 不依賴 widget 自行頻繁抓網路

## 12. Live Activity 設計

## 12.1 Activity Attributes

建議做兩種 activity:

1. `PlanningReminderActivity`
2. `DailySettlementActivity`

### PlanningReminderActivity

靜態資料:

- `targetDateKey`

動態資料:

- `selfSubmitted`
- `partnerSubmitted`
- `cutoffTime`
- `remainingMinutes`

### DailySettlementActivity

靜態資料:

- `dateKey`

動態資料:

- `selfOutcome`
- `partnerOutcome`
- `selfOwesAmount`
- `partnerOwesAmount`
- `needsAck`

## 12.2 啟動與結束時機

### 晚間規劃 Live Activity

- 啟動: `planningReminderTime`
- 結束:
  - 使用者已提交且 partner 也提交，可立即結束
  - 或到 `planningCutoffTime`

### 每日結算 Live Activity

- 啟動: settlement finalized 後
- 結束:
  - 使用者已 ack
  - 或 2 至 4 小時後自動結束

## 12.3 互動

可提供:

- `Open Planning`
- `Open Settlement`

也可考慮簡單 action:

- `Acknowledge`

但不建議把複雜表單塞進 Live Activity。

## 13. App 內 UI/UX 規範

## 13.1 視覺語言

建議主題不要太可愛或太像一般任務 App。這個產品需要「承諾壓力感」與「結算儀式感」。

配色建議:

- 主色: 深石墨 / 墨黑
- 警告: 橘紅
- 結算失敗: 高飽和紅
- 結算成功: 深綠
- 週獎勵: 金色 / 暖白

## 13.2 首頁資訊密度

首頁應該一眼看到:

- 今天還剩幾個必做
- 對方還剩幾個必做
- 今晚是否已規劃明天
- 本週獎勵是否還存活

不要把首頁做成只有自己的列表。這個產品的價值就是「雙人可見」。

## 13.3 強制攔截頁

當使用者打開 App 時，以下情況直接先顯示 full-screen modal:

1. 今日結算尚未 ack
2. 今晚規劃尚未提交且已進入提醒時窗

順序:

- settlement 優先於 planning

因為 settlement 是已發生結果，優先級更高。

## 14. 安全規則

## 14.1 Firestore Security Rules 目標

- 只有本人能改自己的 plans/tasks
- 伴侶雙方都可讀同一個 couple 的資料
- settlement 與 reward finalize 文件只能由 server 寫
- past locked day 不允許 client 修改

### 14.2 規則方向

`users/{userId}`

- 可讀寫自己

`couples/{coupleId}`

- 僅 `memberIds` 內用戶可讀
- 僅 server 可改核心 policy

`plans/{planId}`

- 該 plan owner 可寫
- 另一方只可讀

`tasks/{taskId}`

- owner 可寫
- 若該日已 settlement finalized，拒絕寫入

`settlements/{settlementId}`

- couple members 可讀
- client 不可寫

`rewardWeeks/{weekKey}`

- couple members 可讀
- 只有下週 reward draft 可由 client 更新文案

## 15. 離線與一致性策略

這個產品不能完全用「本地先改、之後再說」的心態做，因為它有金錢懲罰。

建議:

- 本地可 optimistic update UI
- 但雲端必須是唯一結算來源
- 所有最終結算畫面都以 server 結果為準
- 使用者本地日期與時區由裝置持續上報，但結算仍以 server 收到的 timezone snapshot 為準

狀態層級:

1. `local_pending`
2. `synced`
3. `server_final`

## 16. 測試策略

## 16.1 Unit Tests

至少測:

- priority 排序
- required/optional 分桶
- settlement engine
- reward eligibility engine
- planning missed engine
- timezone/dateKey 轉換
- 跨時區雙人首頁顯示
- 使用者跨時區移動後的 dateKey 切換
- weekKey 計算
- cutoff 與 grace 邏輯

## 16.2 Integration Tests

用 Firebase Emulator 測:

- createCouple / joinCouple
- submitPlan
- settlement scheduled job
- reward finalization
- security rules

## 16.3 UI Tests

測:

- 任務新增與完成
- 明日計畫提交流程
- 深連結打開 settlement
- App 前景下自動出現 full-screen settlement
- Widget/Live Activity 對應路由

## 16.4 真機測試

下列功能必須真機:

- APNs / FCM
- Time Sensitive 通知
- Live Activities
- Widget interaction
- Background behavior

Simulator 不足以驗證這些體驗。

## 17. 開發順序建議

## Phase 0: 基礎建設

- 建 Xcode project
- 設 bundle IDs
- 串 Firebase
- 做 auth
- 建 Firestore schema
- 設 App Group
- 設 Widget extension
- 設 Notification capabilities

## Phase 1: 核心資料流

- couple 建立與加入
- 今日/明日 plan 建立
- tasks CRUD
- 今日雙人總覽
- Firestore listeners
- SwiftData cache

## Phase 2: 規則引擎

- planning cutoff
- settlement engine
- penalty policy
- reward week engine
- event logging

## Phase 3: 強提醒體驗

- local + remote notifications
- notification categories
- deep links
- full-screen gate
- widget snapshot
- small / medium widget
- Live Activity

## Phase 4: 產品完成度

- settings
- reminder customization
- edge cases
- analytics
- error handling
- TestFlight

## 18. 建議的 MVP 範圍

如果你想先做可上手版本，不要一開始把所有功能同時做滿。

MVP 必要:

- Sign in with Apple
- 雙人配對
- 今日/明日計畫
- `required` / `optional`
- priority
- task CRUD
- 每日結算
- 週獎勵
- 推播通知
- 首頁雙人總覽
- App 內 full-screen settlement

MVP 可延後:

- Live Activity
- Widget interactivity
- Notification Service Extension 的高級客製
- 多種懲罰模式
- 統計報表
- 圖表化週歷史

## 19. 風險清單

## 19.1 產品風險

- 若規則太寬鬆，會失去督促效果
- 若規則太嚴苛，使用者可能直接關通知
- 若允許空白必做清單，會被濫用

## 19.2 技術風險

- iOS 通知權限被拒絕
- Time Sensitive 被使用者關閉
- Live Activity 被系統限制或使用者關閉
- 離線完成時間的公平性爭議
- Widget 與 App 資料不同步

## 19.3 風險應對

- App 首次 onboarding 明確教育通知重要性
- 設定頁持續檢查通知狀態並提示修正
- 結算以 server 為準
- 所有重要狀態有 event log 可回溯

## 20. 你實際開工時第一批要建立的檔案

```text
CoupleTodoApp.swift
AppCoordinator.swift
Domain/Models/TodoTask.swift
Domain/Models/DailyPlan.swift
Domain/Models/DailySettlement.swift
Domain/Policies/SettlementEngine.swift
Domain/Policies/RewardEligibilityEngine.swift
Data/Repositories/PlanRepository.swift
Data/Repositories/TaskRepository.swift
Data/Repositories/SettlementRepository.swift
Features/TodayBoard/TodayBoardView.swift
Features/TomorrowPlanning/TomorrowPlanningView.swift
Features/Settlement/SettlementView.swift
Platform/Notifications/NotificationManager.swift
Platform/DeepLinks/DeepLinkRouter.swift
Platform/AppGroup/SharedSnapshotWriter.swift
WidgetExtension/CoupleTodoWidget.swift
WidgetExtension/PlanningReminderLiveActivity.swift
```

## 21. 第一版實作決策總結

如果你要一個最務實、能真的做出來的版本，建議直接採這組決策:

- 前端用 SwiftUI
- 後端用 Firebase
- 雙人共享狀態以 Firestore 為真實來源
- 晚間提醒與日結算用 server scheduled jobs + push
- 每個人的提醒與結算都以自己的裝置當地時間為準
- iOS 強提醒靠 Time Sensitive + Widget + Live Activity + in-app full-screen gate
- 不試圖做 iOS 做不到的「主畫面強制不可消除彈窗」
- 週獎勵與日懲罰都交給 server 計算

## 22. Apple 官方能力與限制參考

以下是本文檔技術決策直接依據的官方文件方向，實作前建議再逐篇對照:

- UserNotifications: [Asking permission to use notifications](https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications)
- UserNotifications: [Scheduling a notification locally from your app](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- UserNotifications: [UNNotificationInterruptionLevel.timeSensitive](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel/timesensitive)
- UserNotifications: [criticalAlert](https://developer.apple.com/documentation/usernotifications/unauthorizationoptions/criticalalert)
- ActivityKit: [ActivityKit](https://developer.apple.com/documentation/activitykit/)
- ActivityKit: [Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
- WidgetKit: [Developing a WidgetKit strategy](https://developer.apple.com/documentation/widgetkit/developing-a-widgetkit-strategy/)
- WidgetKit: [Adding interactivity to widgets and Live Activities](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)
- BackgroundTasks: [Using background tasks to update your app](https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app)
- BackgroundTasks: [Choosing Background Strategies for Your App](https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app)

## 23. 下一步

如果你照這份文檔開工，下一步最合理的是:

1. 先建立 Xcode 專案與 targets
2. 建立 Domain Models 與 Firestore schema 常數
3. 先做配對、今日/明日清單、task CRUD
4. 再做 settlement engine
5. 最後接通知、widget、live activity

不要先做 Widget 或 Live Activity。先把資料模型與結算規則做穩，後面的系統整合才不會一直重寫。
