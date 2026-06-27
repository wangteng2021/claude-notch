import AppKit

// Entry point. The same binary plays three roles, chosen by the first argument:
//
//   claude-notch serve            run the always-on notch overlay + socket server
//   claude-notch hook             read a Claude Code hook JSON from stdin and forward it
//   claude-notch send T B [kind]  send an ad-hoc message (handy for testing)
//   claude-notch ping             show a "it works" card
//
// `serve` is meant to run as a background LaunchAgent. The `hook` mode is what
// the Claude Code plugin invokes; it connects to the running server over a Unix
// domain socket, fires one message, and exits in a few milliseconds.

let arguments = Array(CommandLine.arguments.dropFirst())

func printUsage() {
    let text = """
    claude-notch — show Claude Code prompts on the MacBook notch

    USAGE:
      claude-notch serve              Run the notch overlay (background agent)
      claude-notch hook               Forward a Claude Code hook event (reads stdin)
      claude-notch send <title> <body> [kind]
      claude-notch ping               Show a test card

    kinds: permission | waiting | done | step | info | error

    """
    FileHandle.standardError.write(Data(text.utf8))
}

switch arguments.first {
case "serve":
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // no Dock icon, no menu bar item
        app.run()
    }

case "hook":
    HookForwarder.run()

case "send":
    let rest = Array(arguments.dropFirst())
    guard rest.count >= 2 else {
        printUsage()
        exit(2)
    }
    let kind = rest.count >= 3 ? rest[2] : "info"
    let ok = SocketClient.send(
        NotchMessage(title: rest[0], body: rest[1], kind: kind, timeout: 6,
                     termProgram: ProcessInfo.processInfo.environment["TERM_PROGRAM"])
    )
    exit(ok ? 0 : 1)

case "ping":
    let ok = SocketClient.send(
        NotchMessage(title: "Claude Notch", body: "It works ✨", kind: "info", timeout: 4,
                     termProgram: ProcessInfo.processInfo.environment["TERM_PROGRAM"])
    )
    exit(ok ? 0 : 1)

default:
    printUsage()
    exit(2)
}
