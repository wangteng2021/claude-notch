import Foundation

// Invoked as `claude-notch hook` by the Claude Code plugin. Reads the hook's
// JSON payload from stdin, maps it to a NotchMessage, and forwards it to the
// running overlay. Always exits 0 so it never blocks Claude Code.

enum HookForwarder {
    static func run() {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let env = ProcessInfo.processInfo.environment
        let term = env["TERM_PROGRAM"]

        guard
            let object = try? JSONSerialization.jsonObject(with: input) as? [String: Any]
        else { exit(0) }

        let event = object["hook_event_name"] as? String ?? ""
        var message: NotchMessage?

        switch event {
        case "Notification":
            let text = (object["message"] as? String) ?? "Claude needs your attention"
            let type = (object["notification_type"] as? String) ?? ""
            let lowered = (text + " " + type).lowercased()
            let kind = (lowered.contains("permission") || lowered.contains("approve")
                        || lowered.contains("allow")) ? "permission" : "waiting"
            message = NotchMessage(title: "Claude Code", body: text, kind: kind,
                                   timeout: 12, termProgram: term)

        case "Stop":
            message = NotchMessage(title: "Claude finished", body: "Back to you →",
                                   kind: "done", timeout: 6, termProgram: term)

        case "PreToolUse":
            // Opt-in: every tool step is noisy, so only show when explicitly enabled.
            guard env["CLAUDE_NOTCH_STEPS"] == "1" else { exit(0) }
            let tool = (object["tool_name"] as? String) ?? "tool"
            message = NotchMessage(title: tool, body: stepDetail(object),
                                   kind: "step", timeout: 4, termProgram: term)

        default:
            exit(0)
        }

        if let message { _ = SocketClient.send(message) }
        exit(0)
    }

    /// A short, human-readable summary of what a tool is about to do.
    private static func stepDetail(_ object: [String: Any]) -> String {
        guard let input = object["tool_input"] as? [String: Any] else { return "" }
        if let command = input["command"] as? String { return truncate(command) }
        if let path = input["file_path"] as? String {
            return (path as NSString).lastPathComponent
        }
        if let pattern = input["pattern"] as? String { return truncate(pattern) }
        if let url = input["url"] as? String { return truncate(url) }
        return ""
    }

    private static func truncate(_ s: String, _ max: Int = 60) -> String {
        let oneLine = s.replacingOccurrences(of: "\n", with: " ")
        return oneLine.count > max ? String(oneLine.prefix(max)) + "…" : oneLine
    }
}
