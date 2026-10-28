import SwiftUI
import CUVCControl

final class FocusViewModel: ObservableObject {
    private let device: UVCFocusDevice?

    @Published var isAvailable = false
    @Published var autoFocusEnabled = true
    @Published var focusValue: Double = 0
    @Published var focusRange: ClosedRange<Double> = 0...250
    @Published var focusStep: Double = 1
    @Published var statusMessage: String?

    init() {
        device = UVCFocusDevice.firstAvailable()
        refresh()
    }

    func refresh() {
        guard let device else {
            statusMessage = "No UVC-capable camera found."
            return
        }
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
    }

    func setFocus(_ value: Double) {
        guard let device else { return }
        focusValue = value
        _ = device.setFocusAbsoluteValue(Int(value))
    }
}
