import Foundation

// The wire format exchanged between the `hook`/`send` clients and the `serve`
// process. One JSON object per connection, terminated by a newline.
struct NotchMessage: Codable {
    var title: String
    var body: String
    /// permission | waiting | done | step | info | error — drives icon & accent color.
    var kind: String
    /// Seconds to stay on screen before auto-dismiss.
    var timeout: Double
    /// $TERM_PROGRAM of the terminal Claude Code runs in, so a click can refocus it.
    var termProgram: String?
}

enum SocketPath {
    /// Fixed, per-user socket location. Short enough to fit sockaddr_un (104 bytes).
    static var path: String {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClaudeNotch", isDirectory: true)
        return dir.appendingPathComponent("notch.sock").path
    }

    static func ensureDirectory() {
        let dir = (path as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }
}

enum ConfigPath {
    /// User settings (currently just the card language). Written by install.sh.
    static var path: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/ClaudeNotch/config.json").path
    }
}
