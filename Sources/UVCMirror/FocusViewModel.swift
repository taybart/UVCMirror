import AppKit
import AVFoundation
import SwiftUI
import CUVCControl

/// Drives the camera's focus controls and makes them "stick".
///
/// UVC cameras only hold control values in volatile memory, so they reset to their own
/// defaults whenever they lose power (unplug, reboot, sometimes sleep). We save the user's
/// last choices in UserDefaults and push them back to the camera on launch, on reconnect,
/// and after the Mac wakes.
final class FocusViewModel: ObservableObject {
    private var device: UVCFocusDevice?
    private let defaults = UserDefaults.standard
    private var observers: [NSObjectProtocol] = []
    private var pendingReapply: DispatchWorkItem?

    @Published var isAvailable = false
    @Published var autoFocusEnabled = true
    @Published var focusValue: Double = 0
    @Published var focusRange: ClosedRange<Double> = 0...250
    @Published var focusStep: Double = 1
    @Published var statusMessage: String?

    init() {
        device = UVCFocusDevice.firstAvailable()
        applySavedSettings()
        refresh()
        observeReconnects()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func refresh() {
        guard let device else {
            isAvailable = false
            statusMessage = "No UVC-capable camera found."
            return
        }
        statusMessage = nil
        isAvailable = device.supportsAutoFocus || device.supportsFocusAbsolute
        if device.supportsAutoFocus {
            autoFocusEnabled = device.autoFocusEnabled()
        }
        if device.supportsFocusAbsolute {
            let lo = Double(device.focusAbsoluteMinimum())
            let hi = Double(device.focusAbsoluteMaximum())
            focusRange = lo...Swift.max(hi, lo + 1)
            focusStep = Double(Swift.max(device.focusAbsoluteStepSize(), 1))
            focusValue = Double(device.focusAbsoluteValue())
        }
        if !isAvailable {
            statusMessage = "\(device.deviceName) does not expose focus controls."
        }
    }

    func setAutoFocus(_ enabled: Bool) {
        guard let device else { return }
        autoFocusEnabled = enabled
        _ = device.setAutoFocusEnabled(enabled)
        defaults.set(enabled, forKey: key("autoFocus", for: device))
    }

    func setFocus(_ value: Double) {
        guard let device else { return }
        focusValue = value
        _ = device.setFocusAbsoluteValue(Int(value))
        defaults.set(Int(value), forKey: key("focusAbsolute", for: device))
    }

    // MARK: - Persistence

    /// Settings are keyed by camera name so switching cameras doesn't apply one
    /// camera's focus distance to another.
    private func key(_ setting: String, for device: UVCFocusDevice) -> String {
        "focus.\(device.deviceName).\(setting)"
    }

    /// Pushes saved values to the camera. Does nothing for settings the user never
    /// changed, so a fresh install leaves the camera's own defaults alone.
    private func applySavedSettings() {
        guard let device else { return }

        let autoKey = key("autoFocus", for: device)
        let savedAuto = defaults.object(forKey: autoKey) as? Bool
        if let savedAuto, device.supportsAutoFocus {
            _ = device.setAutoFocusEnabled(savedAuto)
        }

        // Manual focus only matters (and is only accepted by most cameras) with autofocus off.
        let focusKey = key("focusAbsolute", for: device)
        if savedAuto == false, device.supportsFocusAbsolute,
           let savedFocus = defaults.object(forKey: focusKey) as? Int {
            _ = device.setFocusAbsoluteValue(savedFocus)
        }
    }

    // MARK: - Reconnect / wake handling

    private func observeReconnects() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasConnectedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleReapply()
        })
        observers.append(center.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Could be our camera or an unrelated one (e.g. a virtual camera);
            // re-scan rather than assume.
            self?.scheduleReapply()
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.scheduleReapply()
        })
    }

    /// A freshly connected camera can take a moment before it answers UVC requests,
    /// so wait briefly and retry a few times before giving up.
    private func scheduleReapply(attempt: Int = 0) {
        pendingReapply?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.device = UVCFocusDevice.firstAvailable()
            if self.device == nil, attempt < 4 {
                self.scheduleReapply(attempt: attempt + 1)
                return
            }
            self.applySavedSettings()
            self.refresh()
        }
        pendingReapply = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }
}
