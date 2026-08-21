import Foundation

// ARCHITECTURE — RawSignal
// Clean Swift (VIP): View emits a request, Interactor owns rules, Presenter maps to a ViewModel,
// Router only changes destination. SwiftUI never computes portions, EAN, or vault writes.
// SpriteKit is the navigation canvas. Each user flow is an SKScene that hosts one SwiftUI VIP overlay.
// Custom SKTransitions (crimson fade, push, flip, crossfade) replace UINavigationController.
// Persistence is a custom RSG1 binary envelope (magic + version + binary plist + CRC32), not JSON and not Core Data.

enum RawSignalArchitectureMarker {}
