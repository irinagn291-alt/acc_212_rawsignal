import SpriteKit
import UIKit

enum SignalGridTransitionFactory {
    static func fabricateNextTransition() -> SKTransition {
        let variants: [SKTransition] = [
            crimsonStrobeFade(),
            pushSweep(),
            flipReveal(),
            crossPulse()
        ]
        let transition = variants[Int(Date().timeIntervalSince1970 * 7) % variants.count]
        transition.pausesIncomingScene = false
        transition.pausesOutgoingScene = false
        return transition
    }

    static func crimsonStrobeFade() -> SKTransition {
        SKTransition.fade(with: UIColor(red: 0.82, green: 0.09, blue: 0.15, alpha: 1), duration: 0.38)
    }

    static func pushSweep() -> SKTransition {
        SKTransition.push(with: .left, duration: 0.36)
    }

    static func flipReveal() -> SKTransition {
        SKTransition.flipHorizontal(withDuration: 0.34)
    }

    static func crossPulse() -> SKTransition {
        SKTransition.crossFade(withDuration: 0.32)
    }
}
