import SwiftUI

struct WatchRemoteControlView: View {
    @State private var isLoading = false
    @State private var recentCommands: [WatchRemoteCommand] = []
    @State private var executingCommand: String?
    @State private var error: String?
    @State private var successMessage: String?

    private let quickActions: [(command: String, title: String, icon: String, tint: Color)] = [
        ("run_health_check", "Health Check", "heart.text.square", WatchLabTheme.green),
        ("clear_cache", "Limpar Cache", "trash", WatchLabTheme.blue),
        ("cleanup_logs", "Limpar Logs", "doc.text", WatchLabTheme.orange),
        ("backup_config", "Backup", "square.and.arrow.up", WatchLabTheme.violet),
    ]

    var body: some View {
        WatchLabScreen(title: "Controle", icon: "terminal", tint: WatchLabTheme.orange) {
            // Quick Actions
            WatchLabPanel(tint: WatchLabTheme.orange) {
                Text("Ações Rápidas")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WatchLabTheme.ink)

                ForEach(quickActions, id: \.command) { action in
                    Button {
                        Task { await executeCommand(action.command) }
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(action.tint.opacity(0.14))
                                .frame(width: 26, height: 26)
                                .overlay {
                                    if executingCommand == action.command {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    } else {
                                        Image(systemName: action.icon)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(action.tint)
                                    }
                                }

                            Text(action.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(WatchLabTheme.ink)

                            Spacer()

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(action.tint.opacity(0.6))
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(action.tint.opacity(0.14), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(executingCommand != nil)
                }
            }

            // Status messages
            if let successMessage {
                WatchLabPanel(tint: WatchLabTheme.green) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(WatchLabTheme.green)
                            .font(.caption)
                        Text(successMessage)
                            .font(.caption2)
                            .foregroundStyle(WatchLabTheme.ink)
                    }
                }
            }

            if let error {
                WatchLabPanel(tint: WatchLabTheme.red) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(WatchLabTheme.red)
                            .font(.caption)
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(WatchLabTheme.ink)
                    }
                }
            }

            // Recent commands
            if !recentCommands.isEmpty {
                WatchLabPanel(tint: WatchLabTheme.blue) {
                    Text("Recentes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WatchLabTheme.ink)

                    ForEach(recentCommands.prefix(4)) { cmd in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(commandStatusColor(cmd.status))
                                .frame(width: 6, height: 6)

                            Text(cmd.command.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(WatchLabTheme.ink)
                                .lineLimit(1)

                            Spacer()

                            Text(cmd.status)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(commandStatusColor(cmd.status))
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .task { await loadCommands() }
        .refreshable { await loadCommands() }
    }

    private func executeCommand(_ command: String) async {
        executingCommand = command
        successMessage = nil
        error = nil

        do {
            let result = try await WatchAPIService.shared.executeRemoteCommand(
                command: command, target: "")
            executingCommand = nil
            successMessage = "Comando enviado"
            recentCommands.insert(result, at: 0)

            // Clear success message after 3 seconds
            try? await Task.sleep(for: .seconds(3))
            successMessage = nil
        } catch {
            executingCommand = nil
            self.error = error.localizedDescription
        }
    }

    private func loadCommands() async {
        do {
            recentCommands = try await WatchAPIService.shared.fetchRemoteCommands()
        } catch {
            // Silent fail for command history
        }
    }

    private func commandStatusColor(_ status: String) -> Color {
        switch status {
        case "completed": return WatchLabTheme.green
        case "failed": return WatchLabTheme.red
        case "running": return WatchLabTheme.orange
        case "pending": return WatchLabTheme.cyan
        default: return WatchLabTheme.secondary
        }
    }
}

#Preview {
    WatchRemoteControlView()
}
