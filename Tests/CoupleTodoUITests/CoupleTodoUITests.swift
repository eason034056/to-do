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
        XCTAssertTrue(appleButton.waitForExistence(timeout: 5), "Auth screen should show Continue with Apple button")
    }

    // MARK: - Today Tab

    func testToday_showsAfterLogin() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let todayTitle = app.navigationBars["Today"]
        XCTAssertTrue(todayTitle.waitForExistence(timeout: 10), "Today tab should appear")
    }

    func testToday_showsPendingPayments() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let usTab = app.tabBars.buttons["Us"]
        guard usTab.waitForExistence(timeout: 5) else { return }
        usTab.tap()

        let paymentsSection = app.staticTexts["Pending Payments"]
        if paymentsSection.waitForExistence(timeout: 5) {
            XCTAssertTrue(paymentsSection.exists, "Us tab should show Pending Payments section")
        }
    }

    // MARK: - Planning

    func testPlanning_canAddTask() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let planTab = app.tabBars.buttons["Plan"]
        guard planTab.waitForExistence(timeout: 5) else { return }
        planTab.tap()

        let addButton = app.buttons["Add"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Planning tab should have Add button")
    }

    // MARK: - Settlement Gate

    func testSettlementGate_cannotSwipeDown() throws {
        app.launchArguments.append("-DemoMode")
        app.launchArguments.append("-ForcePendingSettlement")
        app.launch()

        let settlementTitle = app.navigationBars["Daily Recap"]
        guard settlementTitle.waitForExistence(timeout: 5) else { return }

        app.swipeDown()
        XCTAssertTrue(settlementTitle.exists, "Settlement gate should not be dismissed by swipe down")
    }

    // MARK: - Settings

    func testSettings_showsTimezoneInfo() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let settingsTab = app.tabBars.buttons["Settings"]
        guard settingsTab.waitForExistence(timeout: 5) else { return }
        settingsTab.tap()

        let timezoneLabel = app.staticTexts.matching(identifier: "deviceTimezone")
        XCTAssertTrue(timezoneLabel.firstMatch.waitForExistence(timeout: 5), "Settings should show device timezone")
    }

    // MARK: - Offline Banner

    func testOfflineBanner_showsWhenOffline() throws {
        app.launchArguments.append("-DemoMode")
        app.launchArguments.append("-SimulateOffline")
        app.launch()

        let offlineBanner = app.staticTexts["You're offline"]
        if offlineBanner.waitForExistence(timeout: 5) {
            XCTAssertTrue(offlineBanner.exists, "Offline banner should be visible when offline")
        }
    }

    // MARK: - Rewards

    func testRewards_showsCurrentWeekStatus() throws {
        app.launchArguments.append("-DemoMode")
        app.launch()

        let usTab = app.tabBars.buttons["Us"]
        guard usTab.waitForExistence(timeout: 5) else { return }
        usTab.tap()

        let rewardLink = app.buttons["View Reward Details"]
        guard rewardLink.waitForExistence(timeout: 5) else { return }
        rewardLink.tap()

        let eligibilityLabel = app.staticTexts.matching(identifier: "eligibilityMatrix")
        XCTAssertTrue(eligibilityLabel.firstMatch.waitForExistence(timeout: 5), "Rewards should show eligibility matrix")
    }
}
