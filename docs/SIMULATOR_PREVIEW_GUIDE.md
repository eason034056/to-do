# 在 iOS Simulator 預覽 App

本專案已包含 Xcode 專案，**直接開啟現有資料夾**即可在 Simulator 執行，無需另建新專案。

---

## 快速開始（推薦）

### 步驟一：開啟專案

1. 開啟 **Xcode**
2. **File** → **Open...**（或 `Cmd + O`）
3. 選取 `/Users/wuyusen/Documents/to-do` 資料夾
4. 選擇 **CoupleTodo.xcodeproj** 或直接選資料夾（Xcode 會偵測到專案）
5. 點 **Open**

### 步驟二：在 Simulator 執行

1. 工具列左側選 **CoupleTodo** scheme
2. 執行目標選 **iPhone 16**（或任一 iPhone Simulator）
3. 按 **Run**（▶）或 `Cmd + R`
4. 等待編譯完成，Simulator 會自動啟動並顯示 App

### 步驟三：SwiftUI Preview

1. 開啟 `App/Features/Dashboard/DashboardView.swift`
2. 按 `Option + Cmd + Return` 開啟 Canvas
3. 點 **Resume** 或 **Refresh** 即可預覽

---

## 專案如何產生

專案由 **XcodeGen** 根據 `project.yml` 產生，所有檔案都在同一個資料夾內：

```
to-do/
├── CoupleTodo.xcodeproj    ← Xcode 專案（由 project.yml 產生）
├── project.yml             ← XcodeGen 設定檔
├── Package.swift           ← Swift Package（CoupleTodoCore）
├── App/                    ← App 程式碼
│   ├── AppMain.swift
│   ├── Features/
│   └── Core/
├── Sources/                ← CoupleTodoCore 套件
└── Tests/
```

### 若需重新產生專案

當 `project.yml` 或 `App/` 結構變更時，可重新產生：

```bash
# 安裝 XcodeGen（擇一）
brew install xcodegen
# 或
mint install yonaskolb/XcodeGen

# 在專案目錄執行
cd /Users/wuyusen/Documents/to-do
xcodegen generate
```

---

## 常見問題

### 編譯錯誤：找不到 `TodoTask`、`LocalTimeContext` 等

確認 `App` 底下所有 `.swift` 都有加入專案。若用 XcodeGen 重新產生，通常會自動包含。

### Simulator 無法啟動

- **Xcode** → **Settings** → **Platforms**：確認已下載 iOS Simulator
- **Window** → **Devices and Simulators**：檢查 Simulator 狀態

### 多個 `@main` 衝突

專案內只能有一個 `@main`。本專案使用 `App/AppMain.swift` 作為入口。
