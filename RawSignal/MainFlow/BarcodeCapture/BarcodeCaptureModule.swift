import AVFoundation
import SwiftUI
import UIKit
import Vision

enum BarcodeCaptureModels {
    enum ResolveCode {
        struct Request { var rawInput: String }
        struct Response { var failureCaption: String? }
        struct ViewModel { var statusCaption: String }
    }
}

@MainActor
protocol BarcodeCaptureBusinessLogic {
    func resolveCode(request: BarcodeCaptureModels.ResolveCode.Request)
}

@MainActor
protocol BarcodeCapturePresentationLogic: AnyObject {
    func presentResolution(response: BarcodeCaptureModels.ResolveCode.Response)
}

@MainActor
protocol BarcodeCaptureDisplayLogic: AnyObject {
    func displayResolution(viewModel: BarcodeCaptureModels.ResolveCode.ViewModel)
}

@MainActor
final class BarcodeCaptureInteractor: BarcodeCaptureBusinessLogic {
    var presenter: BarcodeCapturePresentationLogic?
    var catalog: CatalogMerchandiseFetching
    var pipeline: SignalSessionPipeline

    init(catalog: CatalogMerchandiseFetching, pipeline: SignalSessionPipeline) {
        self.catalog = catalog
        self.pipeline = pipeline
    }

    func resolveCode(request: BarcodeCaptureModels.ResolveCode.Request) {
        guard let ean = EuropeanArticleNumberNormalizer.normalizeRawOrURL(request.rawInput) else {
            presenter?.presentResolution(response: .init(failureCaption: "BAD EAN"))
            return
        }
        Task {
            do {
                let merchandise = try await catalog.fetchMerchandise(europeanArticleNumber: ean)
                pipeline.pendingMerchandise = merchandise
                pipeline.pendingServingGrams = merchandise.defaultServingGrams
                presenter?.presentResolution(response: .init(failureCaption: nil))
            } catch {
                presenter?.presentResolution(response: .init(failureCaption: "CODE MISS"))
            }
        }
    }
}

final class BarcodeCapturePresenter: BarcodeCapturePresentationLogic {
    weak var display: BarcodeCaptureDisplayLogic?

    func presentResolution(response: BarcodeCaptureModels.ResolveCode.Response) {
        display?.displayResolution(viewModel: .init(statusCaption: response.failureCaption ?? "LOCKED"))
    }
}

@MainActor
final class BarcodeCaptureObservableStore: ObservableObject, BarcodeCaptureDisplayLogic {
    @Published var manualDigits = ""
    @Published var statusCaption = "AIM THE RETICLE"
    var interactor: BarcodeCaptureBusinessLogic?
    var router: SignalFlowRouting?
    private var didLock = false

    func displayResolution(viewModel: BarcodeCaptureModels.ResolveCode.ViewModel) {
        statusCaption = viewModel.statusCaption
        if viewModel.statusCaption == "LOCKED", !didLock {
            didLock = true
            router?.route(to: .productDetail)
        }
    }
}

final class PulseBarcodePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

struct PulseBarcodeScannerRepresentable: UIViewRepresentable {
    var onRawCode: @Sendable (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onRawCode: onRawCode) }

    func makeUIView(context: Context) -> PulseBarcodePreviewView {
        let view = PulseBarcodePreviewView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: PulseBarcodePreviewView, context: Context) {
        context.coordinator.onRawCode = onRawCode
    }

    static func dismantleUIView(_ uiView: PulseBarcodePreviewView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
        var onRawCode: (String) -> Void
        private let session = AVCaptureSession()
        private let output = AVCaptureVideoDataOutput()
        private let visionQueue = DispatchQueue(label: "com.rawsignal.grid.vision")
        private var lastEmit: TimeInterval = 0

        init(onRawCode: @escaping @Sendable (String) -> Void) {
            self.onRawCode = onRawCode
        }

        func attach(to view: PulseBarcodePreviewView) {
            view.previewLayer.session = session
            view.previewLayer.videoGravity = .resizeAspectFill
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            output.setSampleBufferDelegate(self, queue: visionQueue)
            output.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
            visionQueue.async { [session] in
                session.startRunning()
            }
        }

        func teardown() {
            visionQueue.async { [session] in
                session.stopRunning()
            }
        }

        func captureOutput(
            _ output: AVCaptureOutput,
            didOutput sampleBuffer: CMSampleBuffer,
            from connection: AVCaptureConnection
        ) {
            let now = Date().timeIntervalSince1970
            guard now - lastEmit > 0.9,
                  let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let request = VNDetectBarcodesRequest { [weak self] request, _ in
                guard let payload = (request.results as? [VNBarcodeObservation])?
                    .compactMap(\.payloadStringValue)
                    .first,
                    let coordinator = self else { return }
                coordinator.lastEmit = now
                let callback = coordinator.onRawCode
                DispatchQueue.main.async {
                    callback(payload)
                }
            }
            request.symbologies = [.ean8, .ean13, .upce, .code128, .qr]
            try? VNImageRequestHandler(cvPixelBuffer: pixel, options: [:]).perform([request])
        }
    }
}

struct BarcodeCaptureView: View {
    @ObservedObject var store: BarcodeCaptureObservableStore
    @Environment(\.brutalistTheme) private var theme
    @Environment(\.layoutDensity) private var density
    let preferences: PreferenceConfigurationSnapshot

    var body: some View {
        BrutalistScreenScaffold(title: "SCAN LOCK", backTitle: "BACK", onBack: {
            store.router?.route(to: .dailyIntake)
        }) {
            ZStack {
                PulseBarcodeScannerRepresentable { raw in
                    Task { @MainActor in
                        store.interactor?.resolveCode(request: .init(rawInput: raw))
                    }
                }
                Image("ChromeScanReticle")
                    .resizable()
                    .scaledToFit()
                    .padding(36)
                    .allowsHitTesting(false)
            }
            .frame(height: 280)
            .overlay(Rectangle().stroke(theme.ink, lineWidth: 2))
            Text(store.statusCaption)
                .font(.plexMono(density.captionSize, weight: .medium))
                .foregroundStyle(theme.accent)
            BrutalistField(placeholder: "MANUAL EAN", text: $store.manualDigits)
                .keyboardType(.numberPad)
            BrutalistPanelButton(title: "LOCK DIGITS", emphasized: true) {
                store.interactor?.resolveCode(request: .init(rawInput: store.manualDigits))
            }
            Spacer()
        }
        .applyingVaultAppearance(preferences)
    }
}

final class BarcodeCaptureScene: SignalFlowScene {
    override func fabricateOverlayController() -> UIViewController {
        let factory = SignalDependencyFactory.shared
        let store = BarcodeCaptureObservableStore()
        let interactor = BarcodeCaptureInteractor(catalog: factory.catalog, pipeline: factory.pipeline)
        let presenter = BarcodeCapturePresenter()
        presenter.display = store
        interactor.presenter = presenter
        store.interactor = interactor
        store.router = SignalFlowRouter(canvas: canvas)
        let view = BarcodeCaptureView(store: store, preferences: factory.vault.loadEnvelope().preferences)
        return UIHostingController(rootView: view)
    }
}
