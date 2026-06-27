import Foundation

// Optional phone push via ntfy.sh (open-source, free, iOS + Android). When a
// topic is configured, hook events are POSTed to {server}/ as JSON so the user
// gets a notification on their phone in addition to the Mac notch card.
//
// Config (config.json):
//   { "ntfy": { "server": "https://ntfy.sh", "topic": "my-secret-topic",
//               "kinds": ["permission","waiting","done","error"] } }
// or env: CLAUDE_NOTCH_NTFY_TOPIC, CLAUDE_NOTCH_NTFY_SERVER

struct NtfyConfig {
    var server: String
    var topic: String
    var kinds: Set<String>

    static func load() -> NtfyConfig? {
        let env = ProcessInfo.processInfo.environment
        var server = "https://ntfy.sh"
        var topic: String?
        // By default only push the "you're being waited on / done" events —
        // not every noisy tool step.
        var kinds: Set<String> = ["permission", "waiting", "done", "error"]

        if let data = FileManager.default.contents(atPath: ConfigPath.path),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ntfy = object["ntfy"] as? [String: Any] {
            if let value = ntfy["server"] as? String, !value.isEmpty { server = value }
            if let value = ntfy["topic"] as? String, !value.isEmpty { topic = value }
            if let value = ntfy["kinds"] as? [String], !value.isEmpty { kinds = Set(value) }
        }
        if let value = env["CLAUDE_NOTCH_NTFY_SERVER"], !value.isEmpty { server = value }
        if let value = env["CLAUDE_NOTCH_NTFY_TOPIC"], !value.isEmpty { topic = value }

        guard let topic, !topic.isEmpty else { return nil }
        return NtfyConfig(server: server, topic: topic, kinds: kinds)
    }
}

enum NtfyClient {
    /// Push a message to the configured ntfy topic. No-op if unconfigured or the
    /// kind is filtered out. Blocks up to ~4s (the hook process is short-lived).
    static func push(_ message: NotchMessage, ignoreKindFilter: Bool = false) {
        guard let config = NtfyConfig.load() else { return }
        if !ignoreKindFilter && !config.kinds.contains(message.kind) { return }
        guard let url = URL(string: config.server) else { return }

        let (priority, tags) = meta(for: message.kind)
        let payload: [String: Any] = [
            "topic": config.topic,
            "title": message.title,
            "message": message.body.isEmpty ? message.title : message.body,
            "priority": priority,
            "tags": tags,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, _, _ in semaphore.signal() }.resume()
        _ = semaphore.wait(timeout: .now() + 4)
    }

    /// ntfy priority (1–5) and emoji tags per card kind.
    private static func meta(for kind: String) -> (Int, [String]) {
        switch kind {
        case "permission": return (5, ["warning"])
        case "waiting":    return (4, ["hourglass_flowing_sand"])
        case "done":       return (3, ["white_check_mark"])
        case "error":      return (5, ["rotating_light"])
        default:           return (3, ["sparkles"])
        }
    }
}
