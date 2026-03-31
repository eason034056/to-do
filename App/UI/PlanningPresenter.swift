import Foundation

enum PlanningPresenter {

    static func headerEmphasis(noRequiredConfirmed: Bool) -> CoupleTheme.Emphasis {
        noRequiredConfirmed ? .calm : .active
    }

    static func submitButtonEmphasis(isPastDeadline: Bool) -> CoupleTheme.Emphasis {
        isPastDeadline ? .calm : .success
    }

    static func progressText(requiredCount: Int, optionalCount: Int) -> String {
        "\(requiredCount) required, \(optionalCount) optional"
    }
}
