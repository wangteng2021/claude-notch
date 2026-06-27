import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: NotchController!
    private var server: NotchServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = NotchController()
        self.controller = controller
        server = NotchServer { message in
            // NotchServer already hops to the main queue before calling us.
            MainActor.assumeIsolated {
                controller.show(message)
            }
        }
        server.start()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
