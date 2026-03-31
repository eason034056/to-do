import XCTest
@testable import CoupleTodo
import CoupleTodoCore

final class PlanningPresenterTests: XCTestCase {

    // MARK: - headerEmphasis

    func testHeaderEmphasisIsCalmWhenNoRequiredConfirmed() {
        let emphasis = PlanningPresenter.headerEmphasis(noRequiredConfirmed: true)
        XCTAssertEqual(emphasis, .calm)
    }

    func testHeaderEmphasisIsActiveWhenRequiredNotConfirmed() {
        let emphasis = PlanningPresenter.headerEmphasis(noRequiredConfirmed: false)
        XCTAssertEqual(emphasis, .active)
    }

    // MARK: - submitButtonEmphasis

    func testSubmitButtonEmphasisIsCalmWhenPastDeadline() {
        let emphasis = PlanningPresenter.submitButtonEmphasis(isPastDeadline: true)
        XCTAssertEqual(emphasis, .calm)
    }

    func testSubmitButtonEmphasisIsSuccessWhenBeforeDeadline() {
        let emphasis = PlanningPresenter.submitButtonEmphasis(isPastDeadline: false)
        XCTAssertEqual(emphasis, .success)
    }

    // MARK: - progressText

    func testProgressTextWithBothCounts() {
        let text = PlanningPresenter.progressText(requiredCount: 3, optionalCount: 2)
        XCTAssertEqual(text, "3 required, 2 optional")
    }

    func testProgressTextWithZeroRequired() {
        let text = PlanningPresenter.progressText(requiredCount: 0, optionalCount: 1)
        XCTAssertEqual(text, "0 required, 1 optional")
    }

    func testProgressTextWithZeroOptional() {
        let text = PlanningPresenter.progressText(requiredCount: 5, optionalCount: 0)
        XCTAssertEqual(text, "5 required, 0 optional")
    }

    // MARK: - progressDescription (DashboardPresenter extension)

    func testProgressDescriptionAllDone() {
        let text = DashboardPresenter.progressDescription(completed: 3, total: 3)
        XCTAssertEqual(text, "All done!")
    }

    func testProgressDescriptionSomeRemaining() {
        let text = DashboardPresenter.progressDescription(completed: 1, total: 4)
        XCTAssertEqual(text, "3 left")
    }

    func testProgressDescriptionSingularRemaining() {
        let text = DashboardPresenter.progressDescription(completed: 2, total: 3)
        XCTAssertEqual(text, "1 left")
    }

    func testProgressDescriptionNoneCompleted() {
        let text = DashboardPresenter.progressDescription(completed: 0, total: 5)
        XCTAssertEqual(text, "5 left")
    }
}
