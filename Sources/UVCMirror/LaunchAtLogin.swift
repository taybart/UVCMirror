import Combine
import ServiceManagement

/// Registers the app bundle itself as a login item via SMAppService (macOS 13+).
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not update login item: \(error.localizedDescription)"
        }
        refresh()
    }
}
