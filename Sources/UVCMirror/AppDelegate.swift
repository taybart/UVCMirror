import AppKit
import SwiftUI

/// Owns the status item and the floating panel it toggles. MenuBarExtra(.window) was
/// dropped here because it does not reliably resize once shown (a known, unresolved
/// SwiftUI bug) — this gives us explicit control over both sizing and show/hide.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var outsideClickMonitor: Any?

    private let camera = CameraController()
    private let focus = FocusViewModel()
    private let launchAtLogin = LaunchAtLogin()

    private let contentWidth: CGFloat = 400

    func applicationDidFinishLaunching(_ notification: Notification) {
        let icon = NSImage(systemSymbolName: "camera.fill", accessibilityDescription: "UVC Mirror")
        icon?.isTemplate = true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = icon
        statusItem.button?.action = #selector(togglePanel)
        statusItem.button?.target = self

        let contentView = MenuBarContentView(camera: camera, focus: focus, launchAtLogin: launchAtLogin) { [weak self] height in
            self?.resizePanel(toContentHeight: height)
        }
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: contentWidth, height: 230)

        panel = NSPanel(
            contentRect: hosting.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.contentView = hosting
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonFrameOnScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: buttonFrameOnScreen.midX - panelSize.width / 2,
            y: buttonFrameOnScreen.minY - panelSize.height - 4
        )
        panel.setFrameOrigin(origin)
        panel.makeKeyAndOrderFront(nil)

        camera.start()
        launchAtLogin.refresh()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func hidePanel() {
        panel.orderOut(nil)
        camera.stop()

        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func resizePanel(toContentHeight height: CGFloat) {
        guard let panel, height > 0 else { return }
        var frame = panel.frame
        let topY = frame.origin.y + frame.height
        frame.size = NSSize(width: contentWidth, height: height)
        frame.origin.y = topY - height
        panel.setFrame(frame, display: true, animate: panel.isVisible)
    }
}
