import AVFoundation
import Combine

/// Owns the capture session and keeps it pointed at a live camera.
///
/// Cameras come and go (docking/undocking, unplugging a USB hub, sleep). When the
/// device behind our input disappears, the session is left holding a dead input and
/// the preview goes black, so we rebuild the input whenever devices change or the
/// session reports a runtime error.
final class CameraController: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published var errorMessage: String?

    /// All session configuration and start/stop happens here, serially.
    private let sessionQueue = DispatchQueue(label: "UVCMirror.camera.session")
    private var observers: [NSObjectProtocol] = []

    /// Whether the UI currently wants frames (panel visible). Only touched on sessionQueue.
    private var wantsRunning = false
    /// uniqueID of the device currently wired into the session. Only touched on sessionQueue.
    private var currentDeviceID: String?

    override init() {
        super.init()
        observeDeviceChanges()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.run()
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
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func run() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsRunning = true
            self.reconfigureIfNeeded()
            if !self.session.isRunning, !self.session.inputs.isEmpty {
                self.session.startRunning()
            }
        }
    }

    // MARK: - Device selection

    /// Prefer an external (USB/UVC) camera; fall back to whatever the system default is.
    private func preferredDevice() -> AVCaptureDevice? {
        let externalType: AVCaptureDevice.DeviceType
        if #available(macOS 14.0, *) {
            externalType = .external
        } else {
            externalType = .externalUnknown
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [externalType],
            mediaType: .video,
            position: .unspecified
        )
        let connected = discovery.devices.filter { $0.isConnected && !$0.isSuspended }
        return connected.first ?? AVCaptureDevice.default(for: .video)
    }

    /// Rebuilds the session's input if the device it's using is gone or a better one
    /// is available. Must be called on sessionQueue.
    private func reconfigureIfNeeded() {
        let device = preferredDevice()

        let currentInputAlive = session.inputs
            .compactMap { ($0 as? AVCaptureDeviceInput)?.device }
            .contains { $0.isConnected && $0.uniqueID == currentDeviceID }

        if currentInputAlive, device?.uniqueID == currentDeviceID {
            return
        }

        let wasRunning = session.isRunning
        if wasRunning { session.stopRunning() }

        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        currentDeviceID = nil

        var error: String?
        if let device {
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                    currentDeviceID = device.uniqueID
                } else {
                    error = "Could not add camera input."
                }
            } catch let e {
                error = "Failed to open camera: \(e.localizedDescription)"
            }
        } else {
            error = "No camera found."
        }
        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = error
        }

        if wantsRunning, !session.inputs.isEmpty {
            session.startRunning()
        }
    }

    // MARK: - Hot-plug handling

    private func observeDeviceChanges() {
        let center = NotificationCenter.default
        let handler: (Notification) -> Void = { [weak self] _ in
            self?.scheduleReconfigure()
        }
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: nil, using: handler))
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: nil, using: handler))
        observers.append(center.addObserver(
            forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: nil, using: handler))
    }

    /// A newly attached camera can take a moment to become usable, so give it a beat
    /// before rebuilding (and re-check once more shortly after).
    private func scheduleReconfigure() {
        for delay in [0.5, 2.0] {
            sessionQueue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.reconfigureIfNeeded()
            }
        }
    }
}
