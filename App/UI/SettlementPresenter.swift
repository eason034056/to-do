import Foundation
import CoupleTodoCore

enum SettlementPresenter {

    static func heroEmphasis(
        for settlement: DailySettlement,
        userId: String
    ) -> CoupleTheme.Emphasis {
        if settlement.pendingAcknowledgementUserIds.contains(userId) {
            return .urgent
        }
        return settlement.subjectResult.outcome == .pass ? .success : .calm
    }

    static func outcomeLabel(for outcome: SettlementOutcome) -> String {
        switch outcome {
        case .pass: "PASSED"
        case .fail: "MISSED"
        }
    }

    static func summaryText(for outcome: SettlementOutcome) -> String {
        switch outcome {
        case .pass: "Great job today!"
        case .fail: "Some tasks were missed today."
        }
    }
}
