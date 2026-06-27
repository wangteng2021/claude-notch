import Foundation

enum Lang: String {
    case en
    case zh
}

// All user-facing card text. Resolution order:
//   1. CLAUDE_NOTCH_LANG env var  (en | zh)
//   2. ~/Library/Application Support/ClaudeNotch/config.json  {"lang": "zh"}
//   3. the system preferred language
struct Strings {
    let lang: Lang

    static func current() -> Strings {
        let env = ProcessInfo.processInfo.environment
        if let raw = env["CLAUDE_NOTCH_LANG"], let lang = parse(raw) {
            return Strings(lang: lang)
        }
        if let data = FileManager.default.contents(atPath: ConfigPath.path),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let raw = object["lang"] as? String, let lang = parse(raw) {
            return Strings(lang: lang)
        }
        // Default to Chinese when nothing is configured.
        return Strings(lang: .zh)
    }

    private static func parse(_ raw: String) -> Lang? {
        let value = raw.lowercased()
        if value.hasPrefix("zh") || value.contains("chinese") || value.contains("中文") { return .zh }
        if value.hasPrefix("en") || value.contains("english") { return .en }
        return nil
    }

    // MARK: Static labels for events we generate ourselves

    var permissionTitle: String { lang == .zh ? "需要你的授权" : "Permission needed" }
    var waitingTitle: String    { lang == .zh ? "等待你的输入" : "Waiting for you" }
    var finishedTitle: String   { lang == .zh ? "Claude 完成了" : "Claude finished" }
    var finishedBody: String    { lang == .zh ? "轮到你了 →" : "Back to you →" }
    var testBody: String        { lang == .zh ? "运行成功 ✨" : "It works ✨" }

    func runningTool(_ tool: String) -> String {
        lang == .zh ? "正在执行 \(tool)" : "Running \(tool)"
    }

    var genericPermission: String { lang == .zh ? "Claude 需要你的授权" : "Claude needs your permission" }
    var genericWaiting: String    { lang == .zh ? "Claude 在等待你的输入" : "Claude is waiting for you" }

    // MARK: Best-effort localization of Claude Code's own (English) notification text

    func notification(_ message: String, isPermission: Bool) -> String {
        guard lang == .zh else {
            return message.isEmpty ? (isPermission ? genericPermission : genericWaiting) : message
        }
        if message.isEmpty {
            return isPermission ? genericPermission : genericWaiting
        }
        // "Claude needs your permission to use <Tool>"
        if let range = message.range(of: "permission to use ", options: .caseInsensitive) {
            let tool = message[range.upperBound...]
                .trimmingCharacters(in: CharacterSet(charactersIn: " .。"))
            return tool.isEmpty ? genericPermission : "Claude 需要授权使用 \(tool)"
        }
        let lower = message.lowercased()
        if lower.contains("waiting for your input") || lower.contains("waiting for input") {
            return genericWaiting
        }
        if lower.contains("approval") || lower.contains("approve") {
            return "Claude 在等待你的确认"
        }
        if lower.contains("permission") {
            return genericPermission
        }
        if lower.contains("idle") {
            return genericWaiting
        }
        // Unknown English message — show it verbatim rather than hide information.
        return message
    }
}
