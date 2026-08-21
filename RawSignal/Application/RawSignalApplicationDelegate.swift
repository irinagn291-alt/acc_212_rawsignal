import UIKit

@main
final class RawSignalApplicationDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        BrutalistTypefaceRegistrar.confirmRegistration()
        GridCipher.applyFragments()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.backgroundColor = .black
        window.rootViewController = SignalLaunchPad { SignalCanvasHostController() }
        window.makeKeyAndVisible()
        self.window = window
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad
            ? .all
            : [.portrait, .landscapeLeft, .landscapeRight]
    }
}
