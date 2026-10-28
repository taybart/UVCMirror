import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewNSView {
        let view = PreviewNSView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspect
        return view
    }

    func updateNSView(_ nsView: PreviewNSView, context: Context) {}
}

final class PreviewNSView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setUp()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        wantsLayer = true
        layer = previewLayer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyMirroring),
            name: AVCaptureSession.didStartRunningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        applyMirroring()
    }

    @objc private func applyMirroring() {
        DispatchQueue.main.async { [weak self] in
            guard let connection = self?.previewLayer.connection else { return }
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
