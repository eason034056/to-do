# TestFlight Release Checklist

## Pre-Build Verification

- [ ] `swift test` — 全綠（所有 core + firebase 單元測試通過）
- [ ] `cd Backend/functions && npm run build` — Functions 編譯成功
- [ ] `xcodebuild -scheme CoupleTodo -destination 'generic/platform=iOS' build` — App target 編譯成功
- [ ] Widget extension target 編譯成功
- [ ] 無 known red flags / build warnings

## Security Rules

- [ ] `firebase deploy --only firestore:rules` 部署最新 security rules
- [ ] 跑 `firestore-rules.test.ts` emulator 測試通過
- [ ] 確認 `_jobDedupe` 和 `readModels` 不可被 client 直接寫入
- [ ] 確認 finalized settlement 的 server-only 欄位不可被 client 修改

## Backend Functions

- [ ] `firebase deploy --only functions` 部署所有 callable + scheduled functions
- [ ] Emulator 測試: `submitPlan`, `acknowledgeSettlement`, `saveNextWeekReward`, `markPaymentPaid`
- [ ] Scheduler jobs 可在 emulator 手動觸發且 idempotent

## Auth & Pairing (真機)

- [ ] 首次安裝 → Sign in with Apple → profile 建立
- [ ] 重開 app → session persistence → 自動跳過 auth
- [ ] User A 建立 couple → invite code 顯示
- [ ] User B 加入 couple → status = active
- [ ] 已配對使用者重複 join → `already_paired`
- [ ] 第三人 join → `couple_full`

## Dashboard & Sync

- [ ] Dashboard 顯示 self/partner today task 進度
- [ ] Planning countdown / settlement countdown 正常顯示
- [ ] Pending payments 區塊顯示正確
- [ ] 停留 20 秒確認自動 refresh
- [ ] 手動下拉 refresh 正常

## Planning

- [ ] Planning 視窗內可建立/編輯/刪除 task
- [ ] Carry Over Optional 功能正常
- [ ] 提交 plan → 回傳 requiredCount/optionalCount
- [ ] Cutoff 後再編輯 → 在午夜前可行
- [ ] 午夜後再編輯 → 被拒絕
- [ ] Cutoff 後未提交 → planningMissed = true

## Settlement

- [ ] Settlement gate 不可 swipe down / close
- [ ] Acknowledge 後 gate 消失
- [ ] Settlement history 顯示 gross/net 金額

## Payments

- [ ] Debtor mark paid → markedPaidAt 寫入
- [ ] Creditor acknowledge → status = acknowledged
- [ ] Creditor dispute → status = disputed
- [ ] 非 debtor 無法 mark paid

## Rewards

- [ ] Draft 可編輯 reward text
- [ ] Non-draft reward 不可編輯
- [ ] Eligibility matrix 顯示正確

## Settings

- [ ] 通知權限狀態顯示正確
- [ ] Time Sensitive toggle 正常
- [ ] Timezone / UTC offset 顯示正確
- [ ] 儲存後重開 app 仍可讀回

## Notifications (真機)

- [ ] 首次啟動彈出通知授權
- [ ] FCM token 寫入 deviceInstallations
- [ ] 點擊 planning_reminder push → 導到 PlanningView
- [ ] 點擊 settlement_ready push → 導到 SettlementView
- [ ] 點擊 reward_earned push → 導到 RewardsView
- [ ] 點擊 payment_pending push → 導到 PaymentAcknowledgementView
- [ ] App 回前景自動 apply gate

## Widget (真機/模擬器)

- [ ] Small widget 顯示 required 完成進度
- [ ] Medium widget 顯示 You/Partner 雙欄
- [ ] Accessory widget 顯示 lock screen 摘要
- [ ] Widget tap → 開啟 app 到 dashboard
- [ ] SharedSnapshot 含 reward + payment summary

## Live Activity (真機)

- [ ] Planning window 內 → planning Live Activity 出現
- [ ] 提交 plan → Live Activity 更新
- [ ] Cutoff 後 → Live Activity 結束
- [ ] Settlement pending → settlement Live Activity 出現
- [ ] Acknowledge → settlement Live Activity 結束

## App Intents (真機)

- [ ] Siri "Open planning" → 導到 PlanningView
- [ ] Shortcuts app 執行 Open Dashboard → 導到 Dashboard

## Offline & Conflict (真機)

- [ ] 開啟飛航模式 → 顯示 offline banner
- [ ] 關閉飛航模式 → banner 消失、自動 sync
- [ ] Sync 失敗 3 次 → 顯示 Retry 按鈕
- [ ] Timezone 變更 → 偵測到並顯示提示
- [ ] Finalized settlement 資料不被 client 覆蓋

## Performance & Stability

- [ ] App 啟動時間 < 3 秒
- [ ] 無明顯 memory leak（Instruments 檢查）
- [ ] 連續操作 5 分鐘無 crash
- [ ] Background fetch 正常

## Release

- [ ] Version / build number 更新
- [ ] Archive → Upload to App Store Connect
- [ ] TestFlight 內部測試 → 基本 smoke test
- [ ] TestFlight 外部測試 → 提交 review
