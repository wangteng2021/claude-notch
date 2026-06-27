import SwiftUI

// Shared card styling, used by both the live overlay (NotchView) and the
// offscreen demo renderer.

func cardSymbol(_ kind: String) -> String {
    switch kind {
    case "permission": return "hand.raised.fill"
    case "waiting":    return "ellipsis.bubble.fill"
    case "done":       return "checkmark.circle.fill"
    case "step":       return "gearshape.fill"
    case "error":      return "exclamationmark.triangle.fill"
    default:           return "sparkles"
    }
}

func cardAccent(_ kind: String) -> Color {
    switch kind {
    case "permission": return Color(red: 1.0, green: 0.72, blue: 0.20)
    case "waiting":    return Color(red: 0.40, green: 0.70, blue: 1.0)
    case "done":       return Color(red: 0.35, green: 0.85, blue: 0.45)
    case "step":       return Color(white: 0.7)
    case "error":      return Color(red: 1.0, green: 0.40, blue: 0.40)
    default:           return Color(red: 0.80, green: 0.65, blue: 1.0)
    }
}

func cardAccentNSColor(_ kind: String) -> NSColor {
    switch kind {
    case "permission": return NSColor(srgbRed: 1.0, green: 0.72, blue: 0.20, alpha: 1)
    case "waiting":    return NSColor(srgbRed: 0.40, green: 0.70, blue: 1.0, alpha: 1)
    case "done":       return NSColor(srgbRed: 0.35, green: 0.85, blue: 0.45, alpha: 1)
    case "step":       return NSColor(white: 0.7, alpha: 1)
    case "error":      return NSColor(srgbRed: 1.0, green: 0.40, blue: 0.40, alpha: 1)
    default:           return NSColor(srgbRed: 0.80, green: 0.65, blue: 1.0, alpha: 1)
    }
}
