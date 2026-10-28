import AppKit

// Plain AppKit entry point. A SwiftUI `App` needs at least one scene, and its placeholder
// Settings scene would pop up as a blank window — the status item + panel in AppDelegate
// drive the whole UI, so no scenes are needed.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
