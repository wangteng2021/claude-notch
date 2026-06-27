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
    var topCornerRadius: CGFloat = 16
    var bottomCornerRadius: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let rt = min(topCornerRadius, w / 2, h / 2)
        let rb = min(bottomCornerRadius, w / 2, h / 2)

        var p = Path()
        // A plain rounded card hanging below the notch — all corners convex.
        p.move(to: CGPoint(x: rt, y: 0))
        p.addLine(to: CGPoint(x: w - rt, y: 0))                 // top edge
        p.addQuadCurve(to: CGPoint(x: w, y: rt), control: CGPoint(x: w, y: 0))        // TR
        p.addLine(to: CGPoint(x: w, y: h - rb))                 // right side
        p.addQuadCurve(to: CGPoint(x: w - rb, y: h), control: CGPoint(x: w, y: h))    // BR
        p.addLine(to: CGPoint(x: rb, y: h))                     // bottom edge
        p.addQuadCurve(to: CGPoint(x: 0, y: h - rb), control: CGPoint(x: 0, y: h))    // BL
        p.addLine(to: CGPoint(x: 0, y: rt))                     // left side
        p.addQuadCurve(to: CGPoint(x: rt, y: 0), control: CGPoint(x: 0, y: 0))        // TL
        p.closeSubpath()
        return p
    }
}

// MARK: - The card content

struct NotchView: View {
    @ObservedObject var model: NotchModel
    var cardSize: CGSize
    var onTap: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            if model.expanded, let m = model.message {
                NotchShape()
                    .fill(Color.black)
                    .overlay(
                        NotchShape()
                            .stroke(cardAccent(m.kind).opacity(0.55), lineWidth: 1)
                    )
                    .overlay {
                        HStack(spacing: 11) {
                            Image(systemName: cardSymbol(m.kind))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(cardAccent(m.kind))
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
                        .padding(.vertical, 11)
                    }
                    .frame(width: cardSize.width, height: cardSize.height)
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 7)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap() }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.18, anchor: .top)
                            .combined(with: .move(edge: .top))
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.45, dampingFraction: 0.6), value: model.expanded)
    }
}

// MARK: - Window + lifecycle

@MainActor
final class NotchController {
    private let model = NotchModel()
    private var panel: NSPanel!
    private var dismissWork: DispatchWorkItem?

    // Card geometry — the visible card hangs entirely below the notch.
    private let cardWidth: CGFloat = 340
    private let cardHeight: CGFloat = 64
    private let shadowPad: CGFloat = 36   // extra window room below for shadow + bounce

    init() {
        buildPanel()
    }

    private func notchedScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }

    private func buildPanel() {
        let root = NotchView(model: model, cardSize: CGSize(width: cardWidth, height: cardHeight)) {
            [weak self] in self?.focusTerminal()
        }
        let hosting = NSHostingView(rootView: root)
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: cardWidth + 40, height: cardHeight + shadowPad),
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
        let h = cardHeight + shadowPad
        let x = screen.frame.midX - w / 2
        // The card sits at the top of the window; the window's top edge is the
        // notch's bottom line, so the card hangs straight out of the notch.
        let y = screen.frame.maxY - notch - h
        panel.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
    }

    func show(_ message: NotchMessage) {
        dismissWork?.cancel()
        reposition()
        model.message = message
        panel.orderFrontRegardless()

        panel.alphaValue = 1   // let the SwiftUI spring carry the entrance
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
