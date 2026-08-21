import SpriteKit
import SwiftUI
import UIKit

@MainActor
final class SignalCanvasHostController: UIViewController {
    private let skView = SKView()
    private var overlayController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        skView.frame = view.bounds
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        view.addSubview(skView)
        SignalDependencyFactory.shared.prepareVaultIfNeeded()
        let completed = SignalDependencyFactory.shared.vault.loadEnvelope().onboardingCompleted
        presentInitial(completed ? .dailyIntake : .onboarding)
    }

    override var prefersStatusBarHidden: Bool { false }
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    func traverse(to destination: SignalFlowDestination) {
        let incoming = SignalFlowSceneFabricator.makeScene(
            destination: destination,
            size: skView.bounds.size,
            canvas: self
        )
        if let overlay = overlayController?.view {
            (skView.scene as? SignalFlowScene)?.installDepartureSnapshot(snapshot(overlay))
        }
        detachOverlay()
        skView.presentScene(incoming, transition: SignalGridTransitionFactory.fabricateNextTransition())
    }

    func attachOverlay(_ controller: UIViewController) {
        detachOverlay()
        addChild(controller)
        controller.view.frame = view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.backgroundColor = .clear
        view.addSubview(controller.view)
        controller.didMove(toParent: self)
        overlayController = controller
    }

    private func presentInitial(_ destination: SignalFlowDestination) {
        let scene = SignalFlowSceneFabricator.makeScene(
            destination: destination,
            size: view.bounds.size,
            canvas: self
        )
        skView.presentScene(scene)
    }

    private func detachOverlay() {
        overlayController?.willMove(toParent: nil)
        overlayController?.view.removeFromSuperview()
        overlayController?.removeFromParent()
        overlayController = nil
    }

    private func snapshot(_ target: UIView) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: target.bounds)
        return renderer.image { _ in
            target.drawHierarchy(in: target.bounds, afterScreenUpdates: true)
        }
    }
}

class SignalFlowScene: SKScene {
    weak var canvas: SignalCanvasHostController?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        if children.isEmpty {
            installMeshBackdrop()
        }
        canvas?.attachOverlay(fabricateOverlayController())
    }

    func fabricateOverlayController() -> UIViewController {
        UIViewController()
    }

    func installDepartureSnapshot(_ image: UIImage) {
        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.size = size
        sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sprite.zPosition = 400
        addChild(sprite)
    }

    private func installMeshBackdrop() {
        if let image = UIImage(named: "TextureConcreteBleed") {
            let sprite = SKSpriteNode(texture: SKTexture(image: image))
            sprite.size = size
            sprite.position = CGPoint(x: size.width / 2, y: size.height / 2)
            sprite.alpha = 0.28
            sprite.zPosition = -2
            addChild(sprite)
        }
        let grid = SKSpriteNode(color: .clear, size: size)
        grid.position = CGPoint(x: size.width / 2, y: size.height / 2)
        if let mesh = UIImage(named: "TextureWireMesh") {
            grid.texture = SKTexture(image: mesh)
            grid.size = size
            grid.alpha = 0.18
        }
        grid.zPosition = -1
        addChild(grid)
    }
}

enum SignalFlowSceneFabricator {
    @MainActor
    static func makeScene(
        destination: SignalFlowDestination,
        size: CGSize,
        canvas: SignalCanvasHostController
    ) -> SignalFlowScene {
        let scene: SignalFlowScene
        switch destination {
        case .onboarding:
            scene = OnboardingSequenceScene(size: size)
        case .dailyIntake:
            scene = DailyIntakeDisplayScene(size: size)
        case .catalogSearch:
            scene = CatalogSearchScene(size: size)
        case .barcodeCapture:
            scene = BarcodeCaptureScene(size: size)
        case .productDetail:
            scene = ProductMerchandiseDetailScene(size: size)
        case .slotAssignment:
            scene = SlotAssignmentScene(size: size)
        case .consumedLog:
            scene = ConsumedLogScene(size: size)
        case .wishLedger:
            scene = WishLedgerScene(size: size)
        case .signalPlan:
            scene = SignalHorizonPlanScene(size: size)
        case .preferenceConfiguration:
            scene = PreferenceConfigurationScene(size: size)
        case .goalRevision:
            scene = GoalRevisionScene(size: size)
        }
        scene.scaleMode = .resizeFill
        scene.canvas = canvas
        return scene
    }
}

@MainActor
protocol SignalFlowRouting {
    func route(to destination: SignalFlowDestination)
}

@MainActor
final class SignalFlowRouter: SignalFlowRouting {
    weak var canvas: SignalCanvasHostController?

    init(canvas: SignalCanvasHostController?) {
        self.canvas = canvas
    }

    func route(to destination: SignalFlowDestination) {
        canvas?.traverse(to: destination)
    }
}
