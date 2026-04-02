import SwiftUI

struct ContainerLogsView: View {
    @EnvironmentObject var appState: AppState
    @State private var containers: [DockerContainer] = []
    @State private var selectedContainer: DockerContainer?
    @State private var logs: [LogEntry] = []
    @State private var isLoadingContainers = false
    @State private var isLoadingLogs = false
    @State private var error: String?
    @State private var showingLogViewer = false
    @State private var selectedLogLevel: LogLevel = .all
    @State private var searchQuery = ""
    @State private var autoRefresh = false
    @State private var refreshTimer: Timer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Container List
                if isLoadingContainers {
                    ProgressView("Carregando containers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = error {
                    ErrorCard(message: error)
                        .onTapGesture {
                            loadContainers()
                        }
                } else {
                    containersList
                }
            }
            .navigationTitle("Logs Docker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(autoRefresh ? "Parar Auto-Refresh" : "Auto-Refresh") {
                            toggleAutoRefresh()
                        }

                        Button("Limpar Todos os Logs") {
                            clearAllLogs()
                        }

                        Button("Atualizar") {
                            loadContainers()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                loadContainers()
            }
            .onAppear {
                loadContainers()
            }
            .onDisappear {
                stopAutoRefresh()
            }
            .sheet(isPresented: $showingLogViewer) {
                if let container = selectedContainer {
                    ContainerLogViewer(
                        container: container,
                        logs: logs,
                        logLevel: selectedLogLevel,
                        searchQuery: $searchQuery,
                        onRefresh: {
                            loadLogs(for: container)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var containersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(containers, id: \.names) { container in
                    ContainerLogCard(
                        container: container,
                        onViewLogs: {
                            selectedContainer = container
                            loadLogs(for: container)
                            showingLogViewer = true
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func loadContainers() {
        isLoadingContainers = true
        error = nil

        Task {
            do {
                let dockerStatus = try await APIService.shared.fetchDockerStatus()
                await MainActor.run {
                    self.containers = dockerStatus.containers
                    self.isLoadingContainers = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoadingContainers = false
                }
            }
        }
    }

    private func loadLogs(for container: DockerContainer) {
        isLoadingLogs = true

        Task {
            do {
                let rawLogs = try await APIService.shared.fetchDockerLogsRaw(
                    container: container.names,
                    tail: 100,
                    since: 3600
                )

                let logEntries = parseLogs(rawLogs)

                await MainActor.run {
                    self.logs = logEntries
                    self.isLoadingLogs = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Erro ao carregar logs: \(error.localizedDescription)"
                    self.isLoadingLogs = false
                }
            }
        }
    }

    private func parseLogs(_ rawLogs: String) -> [LogEntry] {
        let lines = rawLogs.components(separatedBy: .newlines)
        return lines.compactMap { line in
            guard !line.isEmpty else { return nil }

            // Parse Docker log format
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let logLevel = determineLogLevel(trimmed)

            // Try to extract timestamp (Docker format often includes timestamp)
            let timestamp = extractTimestamp(from: trimmed) ?? Date()
            let message = extractMessage(from: trimmed)

            return LogEntry(
                id: UUID().uuidString,
                timestamp: timestamp,
                level: logLevel,
                message: message,
                raw: trimmed
            )
        }
    }

    private func determineLogLevel(_ line: String) -> LogLevel {
        let uppercaseLine = line.uppercased()

        if uppercaseLine.contains("ERROR") || uppercaseLine.contains("FATAL") {
            return .error
        } else if uppercaseLine.contains("WARN") {
            return .warning
        } else if uppercaseLine.contains("INFO") {
            return .info
        } else if uppercaseLine.contains("DEBUG") {
            return .debug
        } else {
            return .info
        }
    }

    private func extractTimestamp(from line: String) -> Date? {
        // Try to extract timestamp from common formats
        let patterns = [
            #"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}"#,
            #"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}"#,
            #"\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}"#,
        ]

        for pattern in patterns {
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: line.utf16.count)

            if let match = regex?.firstMatch(in: line, options: [], range: range) {
                let timestampString = (line as NSString).substring(with: match.range)
                return parseTimestamp(timestampString)
            }
        }

        return nil
    }

    private func parseTimestamp(_ string: String) -> Date? {
        // Try ISO8601 first
        let iso8601Formatter = ISO8601DateFormatter()
        if let date = iso8601Formatter.date(from: string) {
            return date
        }

        // Try standard date formatter
        if let date = DateFormatter.standard.date(from: string) {
            return date
        }

        // Try day/month/year formatter
        if let date = DateFormatter.dayMonthYear.date(from: string) {
            return date
        }

        return nil
    }

    private func extractMessage(from line: String) -> String {
        // Remove timestamp and log level prefixes
        let patterns = [
            #"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\s+"#,
            #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s+"#,
            #"^\d{2}/\d{2}/\d{4} \d{2}:\d{2}:\d{2}\s+"#,
            #"^(ERROR|WARN|INFO|DEBUG)\s+"#,
        ]

        var result = line

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(location: 0, length: result.utf16.count)
                result = regex.stringByReplacingMatches(
                    in: result, options: [], range: range, withTemplate: "")
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    private func toggleAutoRefresh() {
        autoRefresh.toggle()

        if autoRefresh {
            startAutoRefresh()
        } else {
            stopAutoRefresh()
        }
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            loadContainers()
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func clearAllLogs() {
        // Implementation for clearing all logs
    }
}

// MARK: - Container Log Card

struct ContainerLogCard: View {
    let container: DockerContainer
    let onViewLogs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(container.names)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(container.image)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                ContainerStatusBadge(status: container.status)
            }

            // Container Info
            HStack(spacing: 16) {
                if let uptime = calculateUptime(container) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(uptime)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                if let ports = container.ports, !ports.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .font(.caption)
                        Text("\(ports.count) ports")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Ver Logs") {
                    onViewLogs()
                }
                .font(.caption)
                .adaptiveGlassProminentButton()
                .controlSize(.small)
            }
        }
        .padding()
        .materialCard(cornerRadius: 12)
    }

    private func calculateUptime(_ container: DockerContainer) -> String? {
        // Simple uptime calculation - in real app would use actual timestamps
        switch container.status.lowercased() {
        case let status where status.contains("up"):
            return "Running"
        case let status where status.contains("exited"):
            return "Stopped"
        default:
            return container.status
        }
    }
}

// MARK: - Container Status Badge

struct ContainerStatusBadge: View {
    let status: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .cornerRadius(8)
    }

    private var statusColor: Color {
        if status.lowercased().contains("up") {
            return .green
        } else if status.lowercased().contains("exited") {
            return .red
        } else {
            return .orange
        }
    }

    private var statusText: String {
        if status.lowercased().contains("up") {
            return "Running"
        } else if status.lowercased().contains("exited") {
            return "Stopped"
        } else {
            return status
        }
    }
}

// MARK: - Container Log Viewer

struct ContainerLogViewer: View {
    let container: DockerContainer
    let logs: [LogEntry]
    let logLevel: LogLevel
    @Binding var searchQuery: String
    let onRefresh: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedLogLevel: LogLevel
    @State private var filteredLogs: [LogEntry]

    init(
        container: DockerContainer, logs: [LogEntry], logLevel: LogLevel,
        searchQuery: Binding<String>, onRefresh: @escaping () -> Void
    ) {
        self.container = container
        self.logs = logs
        self.logLevel = logLevel
        self._selectedLogLevel = State(initialValue: logLevel)
        self._searchQuery = searchQuery
        self.onRefresh = onRefresh
        self._filteredLogs = State(
            initialValue: logs.filter { logLevel == .all || $0.level == logLevel })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Bar
                filterBar

                // Log Entries
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { log in
                            LogEntryRow(log: log)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle(container.names)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Atualizar") {
                        onRefresh()
                    }
                }
            }
        }
        .onChange(of: selectedLogLevel) { _, newLevel in
            applyFilters()
        }
        .onChange(of: searchQuery) { _, _ in
            applyFilters()
        }
    }

    @ViewBuilder
    private var filterBar: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Buscar logs...", text: $searchQuery)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)

            // Log Level Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Button {
                            selectedLogLevel = level
                        } label: {
                            Text(level.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(
                                            selectedLogLevel == level
                                                ? level.color : Color(.systemGray6))
                                )
                                .foregroundStyle(selectedLogLevel == level ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private func applyFilters() {
        filteredLogs = logs.filter { log in
            let levelMatch = selectedLogLevel == .all || log.level == selectedLogLevel
            let searchMatch =
                searchQuery.isEmpty || log.message.localizedCaseInsensitiveContains(searchQuery)
                || log.raw.localizedCaseInsensitiveContains(searchQuery)

            return levelMatch && searchMatch
        }
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    let log: LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(formatTime(log.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            // Log Level Badge
            LogLevelBadge(level: log.level)

            // Message
            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(log.level.backgroundColor.opacity(0.05))
        .cornerRadius(4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Log Level Badge

struct LogLevelBadge: View {
    let level: LogLevel

    var body: some View {
        Text(level.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color.opacity(0.2))
            .foregroundStyle(level.color)
            .cornerRadius(4)
            .frame(width: 50)
    }
}

// MARK: - Models

struct LogEntry: Identifiable {
    let id: String
    let timestamp: Date
    let level: LogLevel
    let message: String
    let raw: String
}

enum LogLevel: String, CaseIterable {
    case all = "all"
    case error = "error"
    case warning = "warning"
    case info = "info"
    case debug = "debug"

    var displayName: String {
        switch self {
        case .all: return "Todos"
        case .error: return "Erro"
        case .warning: return "Aviso"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }

    var color: Color {
        switch self {
        case .all: return .gray
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .purple
        }
    }

    var backgroundColor: Color {
        switch self {
        case .all: return .gray
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        case .debug: return .purple
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let standard: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    static let dayMonthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()
}

#Preview {
    ContainerLogsView()
        .environmentObject(AppState())
}
