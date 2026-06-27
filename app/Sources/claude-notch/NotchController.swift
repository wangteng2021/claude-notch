import AppKit
import SwiftUI

// MARK: - Model the SwiftUI view observes

@MainActor
final class NotchModel: ObservableObject {
    @Published var message: NotchMessage?
    @Published var expanded = false   // drives the grow-from-notch animation
    @Published var notchHeight: CGFloat = 32
}

// MARK: - The Dynamic-Island-style shape
//
// A black card that hangs directly under the physical notch. Its two top
// corners are *concave* ("ears") so they tuck up beside the notch and the black
// of the card merges seamlessly with the black of the notch. Bottom corners are
// normal convex rounding. Drawn in SwiftUI's top-left origin (y grows downward).

struct NotchShape: Shape {
    var topCornerRadius: CGFloat = 11
    var bottomCornerRadius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let rt = min(topCornerRadius, w / 2)
        let rb = min(bottomCornerRadius, w / 2)

        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        // concave top-left ear
        p.addQuadCurve(to: CGPoint(x: rt, y: rt), control: CGPoint(x: rt, y: 0))
        // top edge (sits rt below the notch line)
        p.addLine(to: CGPoint(x: w - rt, y: rt))
        // concave top-right ear
        p.addQuadCurve(to: CGPoint(x: w, y: 0), control: CGPoint(x: w - rt, y: 0))
        // right side
        p.addLine(to: CGPoint(x: w, y: h - rb))
        // convex bottom-right
        p.addQuadCurve(to: CGPoint(x: w - rb, y: h), control: CGPoint(x: w, y: h))
        // bottom edge
        p.addLine(to: CGPoint(x: rb, y: h))
        // convex bottom-left
        p.addQuadCurve(to: CGPoint(x: 0, y: h - rb), control: CGPoint(x: 0, y: h))
        p.closeSubpath()
        return p
    }
}

// MARK: - The card content

struct NotchView: View {
    @ObservedObject var model: NotchModel
    var onTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded, let m = model.message {
                NotchShape()
                    .fill(Color.black)
                    .overlay(
                        NotchShape()
                            .stroke(accent(m.kind).opacity(0.55), lineWidth: 1)
                    )
                    .overlay(alignment: .top) {
                        HStack(spacing: 11) {
                            Image(systemName: symbol(m.kind))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(accent(m.kind))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.title)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                if !m.body.isEmpty {
                                    Text(m.body)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.72))
                                        .lineLimit(2)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        // push content below the notch line
                        .padding(.top, model.notchHeight + 4)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
                    .transition(.scale(scale: 0.6, anchor: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: model.expanded)
    }

    private func symbol(_ kind: String) -> String {
        switch kind {
        case "permission": return "hand.raised.fill"
        case "waiting":    return "ellipsis.bubble.fill"
        case "done":       return "checkmark.circle.fill"
        case "step":       return "gearshape.fill"
        case "error":      return "exclamationmark.triangle.fill"
        default:           return "sparkles"
        }
    }

    private func accent(_ kind: String) -> Color {
        switch kind {
        case "permission": return Color(red: 1.0, green: 0.72, blue: 0.20)   // amber — needs you
        case "waiting":    return Color(red: 0.40, green: 0.70, blue: 1.0)    // blue
        case "done":       return Color(red: 0.35, green: 0.85, blue: 0.45)   // green
        case "step":       return Color(white: 0.7)
        case "error":      return Color(red: 1.0, green: 0.40, blue: 0.40)    // red
        default:           return Color(red: 0.80, green: 0.65, blue: 1.0)    // lilac
        }
    }
}

// MARK: - Window + lifecycle

@MainActor
final class NotchController {
    private let model = NotchModel()
    private var panel: NSPanel!
    private var dismissWork: DispatchWorkItem?

    // Card geometry below the notch line.
    private let cardWidth: CGFloat = 340
    private let cardBodyHeight: CGFloat = 58   // space below the notch for text

    init() {
        buildPanel()
    }

    private func notchedScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }

    private func buildPanel() {
        let root = NotchView(model: model) { [weak self] in self?.focusTerminal() }
        let hosting = NSHostingView(rootView: root)
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: cardWidth + 40, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = false
        panel.contentView = hosting
        panel.alphaValue = 0
        self.panel = panel
        reposition()
        panel.orderFrontRegardless()
    }

    private func reposition() {
        guard let panel, let screen = notchedScreen() else { return }
        let notch = max(screen.safeAreaInsets.top, 22)
        model.notchHeight = notch

        let w = cardWidth
        let h = notch + cardBodyHeight
        let x = screen.frame.midX - w / 2
        // Top of the card flush with the notch line (top of the menu bar).
        let y = screen.frame.maxY - h
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    func show(_ message: NotchMessage) {
        dismissWork?.cancel()
        reposition()
        model.message = message
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 1
        }
        model.expanded = true

        let work = DispatchWorkItem { [weak self] in self?.hide() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + message.timeout, execute: work)
    }

    private func hide() {
        model.expanded = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            panel.animator().alphaValue = 0
        }
    }

    private func focusTerminal() {
        defer { hide() }
        guard let term = model.message?.termProgram else { return }
        let name: String
        switch term {
        case "Apple_Terminal": name = "Terminal"
        case "iTerm.app":      name = "iTerm2"
        case "vscode":         name = "Code"
        case "Warp":           name = "Warp"
        case "WezTerm":        name = "WezTerm"
        case "ghostty":        name = "Ghostty"
        case "Hyper":          name = "Hyper"
        case "tabby":          name = "Tabby"
        default:               name = term.replacingOccurrences(of: ".app", with: "")
        }
        if let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName == name || $0.localizedName == term
        }) {
            app.activate(options: [.activateAllWindows])
        }
    }
}
