import AVFoundation
import Combine

final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var errorMessage: String?

    private var isConfigured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureIfNeededAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureIfNeededAndRun()
                    } else {
                        self?.errorMessage = "Camera access denied."
                    }
                }
            }
        default:
            errorMessage = "Camera access denied. Enable it in System Settings \u{2192} Privacy & Security \u{2192} Camera."
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.stopRunning()
        }
    }

    private func configureIfNeededAndRun() {
        if !isConfigured {
            configure()
        }
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            errorMessage = "No camera found."
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .high
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            } else {
                errorMessage = "Could not add camera input."
            }
        } catch {
            errorMessage = "Failed to open camera: \(error.localizedDescription)"
        }
        session.commitConfiguration()

        isConfigured = true
    }
}
