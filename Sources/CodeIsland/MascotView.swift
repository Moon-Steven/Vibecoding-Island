import SwiftUI
import CodeIslandCore

// MARK: - Mascot Animation Speed Environment

private struct MascotSpeedKey: EnvironmentKey {
    static let defaultValue: Double = 1.0
}

extension EnvironmentValues {
    var mascotSpeed: Double {
        get { self[MascotSpeedKey.self] }
        set { self[MascotSpeedKey.self] = newValue }
    }
}

/// Routes a CLI source identifier to the correct pixel mascot view.
struct MascotView: View {
    let source: String
    let status: AgentStatus
    var size: CGFloat = 27
    var currentTool: String? = nil
    @AppStorage(SettingsKey.mascotSpeed) private var speedPct = SettingsDefaults.mascotSpeed
    @State private var frozenWord: String = ""
    @State private var lastToolKey: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Group {
                switch source {
                case "codex":
                    DexView(status: status, size: size)
                case "gemini":
                    GeminiView(status: status, size: size)
                case "cursor":
                    CursorView(status: status, size: size)
                case "copilot":
                    CopilotView(status: status, size: size)
                case "qoder":
                    QoderView(status: status, size: size)
                case "droid":
                    DroidView(status: status, size: size)
                case "codebuddy":
                    BuddyView(status: status, size: size)
                case "opencode":
                    OpenCodeView(status: status, size: size)
                default:
                    ClawdView(status: status, size: size, currentTool: currentTool)
                }
            }

            // Floating keyword — right of icon
            if source == "claude" {
                Text(frozenWord)
                    .font(.system(size: max(6, size * 0.32), weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .allowsHitTesting(false)
                    .onAppear { pickWord() }
                    .onChange(of: currentTool ?? "") { _, _ in pickWord() }
            }
        }
        .environment(\.mascotSpeed, Double(speedPct) / 100.0)
    }

    private func pickWord() {
        let key = currentTool ?? "_nil_"
        guard key != lastToolKey else { return }
        lastToolKey = key
        let cat = ToolCategoryHelper.categorize(currentTool)
        frozenWord = cat.words.randomElement() ?? "..."
    }
}

/// Shared tool category helper for use outside ClawdView
enum ToolCategoryHelper {
    struct Category {
        let color: Color
        let words: [String]
    }

    static func categorize(_ tool: String?) -> Category {
        guard let t = tool?.lowercased() else {
            return Category(color: Color(red: 0.75, green: 0.75, blue: 0.85),
                          words: ["hmm", "idea", "plan", "think", "wait", "..."])
        }
        if t == "bash" || t.contains("bash") || t.contains("shell") {
            return Category(color: Color(red: 0.3, green: 1.0, blue: 0.5),
                          words: ["exec", "run", "brew", "pipe", "sudo", "bash"])
        }
        if t == "read" || t == "grep" || t == "glob" || t == "ls"
            || t.contains("read") || t.contains("grep") || t.contains("glob") {
            return Category(color: Color(red: 0.4, green: 0.75, blue: 1.0),
                          words: ["scan", "grep", "find", "peek", "read", "seek"])
        }
        if t == "edit" || t == "write" || t.contains("edit") || t.contains("write") {
            return Category(color: Color(red: 1.0, green: 0.65, blue: 0.2),
                          words: ["edit", "code", "fix", "craft", "type", "save"])
        }
        if t.contains("web") || t.contains("fetch") {
            return Category(color: Color(red: 0.7, green: 0.45, blue: 1.0),
                          words: ["fetch", "ping", "curl", "load", "sync", "pull"])
        }
        return Category(color: Color(red: 0.75, green: 0.75, blue: 0.85),
                       words: ["hmm", "idea", "plan", "think", "wait", "..."])
    }
}
