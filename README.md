# claude-notch

Show [Claude Code](https://claude.com/claude-code)'s prompts and waiting states
on your MacBook's **notch** — Dynamic-Island style. When Claude needs your
approval, asks a question, or finishes a turn, a black card drops out of the
notch so you notice instantly instead of leaving Claude waiting.

> macOS only, and best on a notched MacBook (the card merges into the physical
> notch). On non-notched displays it still shows as a pill near the top.

<p align="center">
  <img src="docs/demo.gif" width="540" alt="claude-notch dropping a card from the notch">
</p>

<p align="center">
  <img src="docs/card-permission.png" width="260" alt="permission card">
  <img src="docs/card-done.png" width="260" alt="done card">
</p>

> The demo assets are generated headlessly with `claude-notch render-demo docs/`
> (pure CoreGraphics — no screen recording).

---

## How it works

```
Claude Code  ──fires hooks──▶  claude-notch hook  ──unix socket──▶  claude-notch serve
 (your TUI)                     (plugin, per-event)                  (always-on overlay)
                                                                            │
                                                                     draws the card
                                                                      on the notch
```

* A tiny native Swift binary plays two roles: a background **overlay**
  (`serve`) that renders the notch card, and a per-event **forwarder**
  (`hook`) that the Claude Code plugin runs.
* They talk over a per-user Unix domain socket — no network, no daemon ports.
* Zero third-party dependencies; just AppKit + SwiftUI + POSIX sockets.

## What it shows

| Event in Claude Code            | Card            | Accent |
| ------------------------------- | --------------- | ------ |
| Needs permission to use a tool  | `Claude Code`   | amber  |
| Waiting for your input (idle)   | `Claude Code`   | blue   |
| Finished its turn               | `Claude finished` | green |
| Each tool step *(opt-in)*       | tool name       | grey   |

If you run Claude with full auto-approval and it never prompts you, the notch
stays quiet — it mirrors whatever Claude actually surfaces. **Click any card**
to bring the terminal running Claude Code back to the front.

## Install

```bash
git clone https://github.com/REPLACE_ME/claude-notch.git
cd claude-notch
./install.sh
```

`install.sh` builds the binary, installs a LaunchAgent (so the overlay runs now
and at every login), and fires a test card. Then, inside Claude Code:

```
/plugin marketplace add /absolute/path/to/claude-notch
/plugin install claude-notch@claude-notch
```

Restart Claude Code and you're done.

### Requirements

* macOS 13+
* Xcode command line tools (`xcode-select --install`) — for building only
* Claude Code

## Configuration

* **Language.** `install.sh` asks you to pick English or 中文 and writes it to
  `~/Library/Application Support/ClaudeNotch/config.json`:

  ```json
  { "lang": "zh" }
  ```

  Card labels are localized; Claude Code's own English notifications are
  best-effort translated. **Default is 中文.** Override per-run with
  `CLAUDE_NOTCH_LANG=en` (or `zh`).

* **Phone push (optional).** Get a notification on your phone too, via the free
  open-source [ntfy.sh](https://ntfy.sh). `install.sh` asks for a topic, or add
  it to `config.json`:

  ```json
  {
    "lang": "zh",
    "ntfy": {
      "server": "https://ntfy.sh",
      "topic": "your-secret-topic-name",
      "kinds": ["permission", "waiting", "done", "error"]
    }
  }
  ```

  Install the **ntfy** app (iOS/Android) and subscribe to the same topic. Use a
  long, hard-to-guess topic name — anyone who knows it can read your pushes.
  Only `kinds` listed are pushed (default skips the noisy per-tool steps).
  Override per-run with `CLAUDE_NOTCH_NTFY_TOPIC`.

* **Show every tool step**, not just prompts: set `CLAUDE_NOTCH_STEPS=1` in the
  environment before launching Claude Code.

  ```bash
  export CLAUDE_NOTCH_STEPS=1
  ```

* **Pick which events fire** by editing `plugin/hooks/hooks.json` (any of
  `Notification`, `Stop`, `PreToolUse`, …). See the Claude Code
  [hooks reference](https://code.claude.com/docs/en/hooks).

## Try it without Claude Code

```bash
plugin/bin/claude-notch ping
plugin/bin/claude-notch send "Permission needed" "Claude wants to run rm -rf build/" permission
plugin/bin/claude-notch send "Claude finished" "Back to you →" done
```

## Uninstall

```bash
./uninstall.sh
# then, in Claude Code:
/plugin uninstall claude-notch@claude-notch
```

## Project layout

```
claude-notch/
├── app/                       Swift package (the native binary)
│   └── Sources/claude-notch/
│       ├── main.swift         arg dispatch: serve | hook | send | ping
│       ├── NotchController.swift  the Dynamic-Island window + shape + view
│       ├── Socket.swift       Unix-domain-socket server & client
│       ├── HookForwarder.swift maps Claude Code hook JSON → a card
│       ├── NtfyClient.swift     optional phone push via ntfy.sh
│       ├── Localization.swift   en / zh card text
│       ├── AppDelegate.swift
│       └── Message.swift
├── plugin/                    the Claude Code plugin
│   ├── .claude-plugin/plugin.json
│   ├── hooks/hooks.json
│   └── bin/claude-notch       (built by install.sh; git-ignored)
├── .claude-plugin/marketplace.json
├── install.sh / uninstall.sh
```

## Roadmap

* [ ] Prebuilt signed release so users don't need to compile
* [ ] Optional DynamicNotchKit backend for richer expand/collapse animation
* [ ] Per-event customization (colors, sounds, durations) via a config file
* [ ] Homebrew tap

## License

MIT — see [LICENSE](LICENSE).
