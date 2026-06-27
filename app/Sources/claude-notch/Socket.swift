import Darwin
import Foundation

// Minimal Unix-domain-socket IPC. The `serve` process binds and listens; the
// `hook`/`send` clients connect, write one newline-terminated JSON object, and
// disconnect. No third-party dependencies — just POSIX sockets.

private func fillSunPath(_ addr: inout sockaddr_un, _ path: String) -> Bool {
    let capacity = MemoryLayout.size(ofValue: addr.sun_path)
    return path.withCString { cstr -> Bool in
        let length = strlen(cstr)
        guard length < capacity else { return false }
        withUnsafeMutablePointer(to: &addr.sun_path) { tuplePtr in
            tuplePtr.withMemoryRebound(to: CChar.self, capacity: capacity) { dst in
                memcpy(dst, cstr, length + 1)
            }
        }
        return true
    }
}

enum SocketClient {
    /// Connect to the running `serve` process and deliver one message. Returns
    /// false (silently) if nothing is listening — the LaunchAgent is expected to
    /// keep `serve` alive, so a miss here just means "not running yet".
    static func send(_ message: NotchMessage) -> Bool {
        guard let json = try? JSONEncoder().encode(message) else { return false }

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        guard fillSunPath(&addr, SocketPath.path) else { return false }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let connected = withUnsafePointer(to: &addr) { raw in
            raw.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(fd, $0, size) }
        }
        guard connected == 0 else { return false }

        var payload = json
        payload.append(0x0A) // newline terminator
        let written = payload.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        return written == payload.count
    }
}

final class NotchServer {
    private let handler: (NotchMessage) -> Void

    init(handler: @escaping (NotchMessage) -> Void) {
        self.handler = handler
    }

    func start() {
        SocketPath.ensureDirectory()
        let path = SocketPath.path
        unlink(path) // clear any stale socket from a previous run

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        guard fillSunPath(&addr, path) else { close(fd); return }

        let size = socklen_t(MemoryLayout<sockaddr_un>.size)
        let bound = withUnsafePointer(to: &addr) { raw in
            raw.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, size) }
        }
        guard bound == 0, listen(fd, 8) == 0 else { close(fd); return }

        let handler = self.handler
        Thread.detachNewThread {
            while true {
                let client = accept(fd, nil, nil)
                if client < 0 { continue }
                defer { close(client) }

                var buffer = [UInt8]()
                var chunk = [UInt8](repeating: 0, count: 4096)
                readLoop: while true {
                    let n = read(client, &chunk, chunk.count)
                    if n <= 0 { break }
                    for i in 0..<n {
                        if chunk[i] == 0x0A { break readLoop }
                        buffer.append(chunk[i])
                    }
                }
                guard let message = try? JSONDecoder().decode(NotchMessage.self, from: Data(buffer))
                else { continue }
                DispatchQueue.main.async { handler(message) }
            }
        }
    }
}
