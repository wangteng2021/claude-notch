class ClaudeNotch < Formula
  desc "Show Claude Code prompts on the MacBook notch (Dynamic-Island style)"
  homepage "https://github.com/wangteng2021/claude-notch"
  url "https://github.com/wangteng2021/claude-notch/releases/download/v0.1.0/claude-notch-macos-universal.zip"
  sha256 "5ea0198d06c8e6c40c9d4497613417a4bf45c5e303d2558e86b8599a84c022ca"
  version "0.1.0"
  license "MIT"

  depends_on :macos

  def install
    bin.install "claude-notch"
  end

  service do
    run [opt_bin/"claude-notch", "serve"]
    keep_alive true
    log_path var/"log/claude-notch.log"
    error_log_path var/"log/claude-notch.log"
  end

  def caveats
    <<~EOS
      1. Start the notch overlay:
           brew services start claude-notch

      2. Enable the Claude Code plugin so events are forwarded:
           /plugin marketplace add wangteng2021/claude-notch
           /plugin install claude-notch@claude-notch

      Config (language, ntfy phone push):
        ~/Library/Application Support/ClaudeNotch/config.json
    EOS
  end

  test do
    system bin/"claude-notch", "send", "test", "hello", "info"
  end
end
