import SwiftUI

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MenuBarContentView: View {
    @ObservedObject var camera: CameraController
    @ObservedObject var focus: FocusViewModel
    @ObservedObject var launchAtLogin: LaunchAtLogin
    let onHeightChange: (CGFloat) -> Void

    @State private var showOptions = false

    private let previewWidth: CGFloat = 400
    private var previewHeight: CGFloat { previewWidth * 9 / 16 }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                CameraPreviewView(session: camera.session)
                    .frame(width: previewWidth, height: previewHeight)
                    .background(Color.black)

                if let error = camera.errorMessage {
                    Text(error)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .padding(6)
                        .background(.black.opacity(0.7))
                        .foregroundStyle(.white)
                        .cornerRadius(6)
                        .padding(6)
                }

                Button {
                    showOptions.toggle()
                } label: {
                    Image(systemName: showOptions ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.title3)
                        .foregroundStyle(.white, .black.opacity(0.4))
                }
                .buttonStyle(.plain)
                .padding(6)
            }

            if showOptions {
                VStack(alignment: .leading, spacing: 10) {
                    if focus.isAvailable {
                        Toggle("Auto Focus", isOn: Binding(
                            get: { focus.autoFocusEnabled },
                            set: { focus.setAutoFocus($0) }
                        ))
                        Slider(
                            value: Binding(
                                get: { focus.focusValue },
                                set: { focus.setFocus($0) }
                            ),
                            in: focus.focusRange,
                            step: focus.focusStep
                        )
                        .disabled(focus.autoFocusEnabled)
                    } else if let message = focus.statusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Toggle("Launch at Login", isOn: Binding(
                        get: { launchAtLogin.isEnabled },
                        set: { launchAtLogin.setEnabled($0) }
                    ))
                    if let message = launchAtLogin.errorMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button("Quit UVC Mirror") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                .padding(10)
                .frame(width: previewWidth, alignment: .leading)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(ContentHeightKey.self) { height in
            onHeightChange(height)
        }
    }
}
