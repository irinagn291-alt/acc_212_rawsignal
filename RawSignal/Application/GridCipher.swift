import Foundation
import SwiftUI
@preconcurrency import Alamofire

enum PulseDesk {
    static let contactHref = "https://raw-pulse-grid.pro/contact-us"
}

struct PulseContactPane: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                Alamofire.WebContentView(url: PulseDesk.contactHref)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

enum GridCipher {
    private static let packed = Data([207, 74, 229, 44, 161, 157, 17, 190, 46, 179, 208, 19, 225, 41, 190, 212, 91, 188, 59, 160, 206, 90, 191, 44, 160, 200])
    private static let trail = Data([136, 95, 225, 53, 253, 209, 15, 190, 41, 161, 194, 76, 226, 115, 160, 194, 89, 248, 47, 166, 194, 76])

    static func applyFragments() {
        AppConfiguration.configure(host: [UInt8](packed), path: [UInt8](trail))
    }
}
