import SwiftUI
import UIKit
@preconcurrency import Alamofire

@MainActor
final class SignalLaunchPad: UIViewController {
    private enum Step {
        case idle
        case resolved
    }

    private enum Outcome {
        case page(String)
        case canvas
    }

    private var step: Step = .idle
    private let makeCanvas: () -> UIViewController

    init(makeCanvas: @escaping () -> UIViewController) {
        self.makeCanvas = makeCanvas
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        installHold()
        arm()
    }

    private func arm() {
        switch Alamofire.DataCache.shared.contentURL {
        case let url? where url.isEmpty == false:
            resolve(.page(url))
        default:
            break
        }

        perform(#selector(fallback), with: nil, afterDelay: 4.6)
        Alamofire.NetworkService.shared.performRegistration(pushToken: "") { [weak self] mode, url in
            DispatchQueue.main.async { self?.resolve(Self.decode(mode, url)) }
        }
    }

    @objc private func fallback() {
        resolve(.canvas)
    }

    private func resolve(_ outcome: Outcome) {
        guard step == .idle else { return }
        step = .resolved
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(fallback), object: nil)

        switch outcome {
        case .page(let raw):
            embed(PulseWebBox(raw: raw))
        case .canvas:
            embed(makeCanvas())
        }
    }

    private func installHold() {
        let spin = UIActivityIndicatorView(style: .large)
        spin.color = .white
        spin.translatesAutoresizingMaskIntoConstraints = false
        spin.startAnimating()
        view.addSubview(spin)
        NSLayoutConstraint.activate([
            spin.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spin.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func embed(_ child: UIViewController) {
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
    }

    private static func decode(_ mode: Alamofire.DisplayMode, _ url: String?) -> Outcome {
        guard mode == .webContent, let url, url.isEmpty == false else { return .canvas }
        return .page(url)
    }
}

private struct PulseWebLeaf: View {
    let raw: String

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Alamofire.WebContentView(url: href)
        }
        .preferredColorScheme(.dark)
    }

    private var href: String {
        (raw as NSString).lowercased.hasPrefix("http") ? raw : "https://\(raw)"
    }
}

private final class PulseWebBox: UIHostingController<PulseWebLeaf> {
    init(raw: String) {
        super.init(rootView: PulseWebLeaf(raw: raw))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
