import SwiftUI

enum CoupleAnimations {
    static let checkboxBounce = Animation.spring(duration: 0.4, bounce: 0.3)
    static let cardAppear = Animation.spring(duration: 0.5, bounce: 0.2)
    static let progressFill = Animation.easeOut(duration: 0.8)
    static let slideIn = Animation.spring(duration: 0.35, bounce: 0.15)
    static let pulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    static let confettiBurst = Animation.spring(duration: 0.6, bounce: 0.4)
    static let shake = Animation.spring(duration: 0.3, bounce: 0.5)
    static let taskAppear = Animation.spring(duration: 0.4, bounce: 0.25)
    static let taskRemove = Animation.easeOut(duration: 0.3)
    static let quickAddBounce = Animation.spring(duration: 0.3, bounce: 0.4)
    static let heroAppear = Animation.spring(duration: 0.6, bounce: 0.15)

    static func staggeredAppear(index: Int) -> Animation {
        cardAppear.delay(Double(index) * 0.05)
    }

    static func reducedMotionFade(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : cardAppear
    }

    static func taskInsertAnimation(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : taskAppear
    }

    static func taskRemoveAnimation(_ reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : taskRemove
    }
}
