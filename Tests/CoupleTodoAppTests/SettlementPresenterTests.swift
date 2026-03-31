import XCTest
@testable import CoupleTodo
import CoupleTodoCore

final class SettlementPresenterTests: XCTestCase {

    // MARK: - heroEmphasis

    func testHeroEmphasisIsUrgentWhenAcknowledgementPending() {
        let settlement = makeSettlement(
            outcome: .fail,
            pendingAcknowledgementUserIds: ["usr_self"]
        )

        let emphasis = SettlementPresenter.heroEmphasis(
            for: settlement,
            userId: "usr_self"
        )

        XCTAssertEqual(emphasis, .urgent)
    }

    func testHeroEmphasisIsSuccessWhenPassedAndNoAckNeeded() {
        let settlement = makeSettlement(
            outcome: .pass,
            pendingAcknowledgementUserIds: []
        )

        let emphasis = SettlementPresenter.heroEmphasis(
            for: settlement,
            userId: "usr_self"
        )

        XCTAssertEqual(emphasis, .success)
    }

    func testHeroEmphasisIsCalmWhenFailedButNoAckNeeded() {
        let settlement = makeSettlement(
            outcome: .fail,
            pendingAcknowledgementUserIds: []
        )

        let emphasis = SettlementPresenter.heroEmphasis(
            for: settlement,
            userId: "usr_self"
        )

        XCTAssertEqual(emphasis, .calm)
    }

    // MARK: - outcomeLabel

    func testOutcomeLabelForPass() {
        XCTAssertEqual(SettlementPresenter.outcomeLabel(for: .pass), "PASSED")
    }

    func testOutcomeLabelForFail() {
        XCTAssertEqual(SettlementPresenter.outcomeLabel(for: .fail), "MISSED")
    }

    // MARK: - summaryText

    func testSummaryTextForPass() {
        let text = SettlementPresenter.summaryText(for: .pass)
        XCTAssertEqual(text, "Great job today!")
    }

    func testSummaryTextForFail() {
        let text = SettlementPresenter.summaryText(for: .fail)
        XCTAssertEqual(text, "Some tasks were missed today.")
    }

    // MARK: - Helpers

    private func makeSettlement(
        outcome: SettlementOutcome,
        pendingAcknowledgementUserIds: [String]
    ) -> DailySettlement {
        DailySettlement(
            id: "stl_1",
            coupleId: "cpl_1",
            subjectUserId: "usr_self",
            counterpartyUserId: "usr_partner",
            dateKey: "2026-03-25",
            localTimezone: "America/Chicago",
            localWeekKey: "2026-W13",
            state: .finalized,
            computedAt: Date(),
            graceAppliedUntil: nil,
            subjectResult: SettlementResult(
                requiredTotal: 3,
                requiredCompleted: outcome == .pass ? 3 : 2,
                missedRequiredCount: outcome == .pass ? 0 : 1,
                outcome: outcome,
                owesAmount: outcome == .pass ? 0 : 8
            ),
            counterpartySnapshot: CounterpartySettlementSnapshot(
                latestKnownDateKey: "2026-03-26",
                latestKnownOutcome: .pass
            ),
            pendingAcknowledgementUserIds: pendingAcknowledgementUserIds,
            rewardImpact: RewardImpact(weekKey: "2026-W13", stillEligible: outcome == .pass)
        )
    }
}
