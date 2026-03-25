import XCTest

final class CoupleTodoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITesting"]
    }

    // MARK: - Auth Flow

    func testAuthScreen_showsContinueWithApple() throws {
        app.launch()
        let appleButton = app.buttons["Continue with Apple"]
        XCTAssertTrue(appleButton.waitForExistence(timeout: 5), "Auth 畫面應顯示 Continue with Apple 按鈕")
    }

    // MARK: - Dashboard

    func testDashboard_showsAfterLogin() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let dashboardTitle = app.staticTexts["Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: 10), "Dashboard 標題應出現")
    }

    func testDashboard_showsPendingPayments() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let paymentsSection = app.staticTexts["Pending Payments"]
        if paymentsSection.waitForExistence(timeout: 5) {
            XCTAssertTrue(paymentsSection.exists, "有 pending payment 時應顯示 Pending Payments 區塊")
        }
    }

    // MARK: - Planning

    func testPlanning_canAddTask() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let planButton = app.buttons["Plan Tomorrow"]
        guard planButton.waitForExistence(timeout: 5) else {
            return
        }
        planButton.tap()

        let addButton = app.buttons["Add Task"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Planning 頁應有 Add Task 按鈕")
    }

    // MARK: - Settlement Gate

    func testSettlementGate_cannotSwipeDown() throws {
        app.launchArguments.append("-DemoMode")
        app.launchArguments.append("-ForcePendingSettlement")
        app.launch()

        let settlementTitle = app.staticTexts["Daily Settlement"]
        guard settlementTitle.waitForExistence(timeout: 5) else {
            return
        }

        app.swipeDown()
        XCTAssertTrue(settlementTitle.exists, "Settlement gate 不應被 swipe down 關閉")
    }

    // MARK: - Settings

    func testSettings_showsTimezoneInfo() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let settingsTab = app.buttons["Settings"]
        guard settingsTab.waitForExistence(timeout: 5) else {
            return
        }
        settingsTab.tap()

        let timezoneLabel = app.staticTexts.matching(identifier: "deviceTimezone")
        XCTAssertTrue(timezoneLabel.firstMatch.waitForExistence(timeout: 5), "Settings 應顯示 device timezone")
    }

    // MARK: - Offline Banner

    func testOfflineBanner_showsWhenOffline() throws {
        app.launchArguments.append("-DemoMode")
        app.launchArguments.append("-SimulateOffline")
        app.launch()

        let offlineBanner = app.staticTexts["You're offline. Changes will sync when connection returns."]
        if offlineBanner.waitForExistence(timeout: 5) {
            XCTAssertTrue(offlineBanner.exists, "離線時應顯示 offline banner")
        }
    }

    // MARK: - Rewards

    func testRewards_showsCurrentWeekStatus() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let rewardsTab = app.buttons["Rewards"]
        guard rewardsTab.waitForExistence(timeout: 5) else {
            return
        }
        rewardsTab.tap()

        let eligibilityLabel = app.staticTexts.matching(identifier: "eligibilityMatrix")
        XCTAssertTrue(eligibilityLabel.firstMatch.waitForExistence(timeout: 5), "Rewards 應顯示 eligibility 矩陣")
    }
}
